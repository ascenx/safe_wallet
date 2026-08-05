import 'dart:convert';
import 'dart:typed_data';

import 'package:solana_sdk/solana_sdk.dart' as solana;
import 'package:sui_dart/sui.dart' as sui;
import 'package:web3dart/web3dart.dart' as web3;

import '../../../shared/utils/sui_address.dart';
import '../application/dapp_request_models.dart';
import 'dapp_transaction.dart';

final class SdkDappTransactionPreviewer implements DappTransactionPreviewer {
  const SdkDappTransactionPreviewer();

  @override
  DappTransactionPreview? previewSui({
    required List<int> transactionBytes,
    required String expectedSender,
  }) {
    try {
      final transaction = sui.Transaction.fromBytes(
        Uint8List.fromList(transactionBytes),
      );
      final data = transaction.getData();
      final sender = data.sender;
      if (sender == null ||
          normalizeSuiAddressInput(sender) !=
              normalizeSuiAddressInput(expectedSender)) {
        return null;
      }
      final commandCount = data.commands?.length ?? 0;
      final commandSummaries =
          (data.commands ?? const <Map<dynamic, dynamic>>[])
              .map(_suiCommandSummary)
              .toList(growable: false);
      final previewBytes = transactionBytes.take(256).toList(growable: false);
      final truncated = previewBytes.length != transactionBytes.length;
      final gasBudget = data.gasData.budget;
      return DappTransactionPreview(
        from: sender,
        value: '0 SUI',
        data: '${base64Encode(previewBytes)}${truncated ? '…' : ''}',
        decodedInfo: commandSummaries.isEmpty
            ? 'Sui transaction has no programmable commands'
            : 'Sui commands ($commandCount): ${commandSummaries.join('; ')}',
        estimatedFee: gasBudget == null
            ? null
            : '${_formatUnits(gasBudget, 9)} SUI',
        highRisk: true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  DappTransactionPreview previewSolana({
    required String from,
    required List<int> serializedTransaction,
    int count = 1,
  }) {
    final rawData = web3.bytesToHex(
      Uint8List.fromList(serializedTransaction),
      include0x: true,
    );
    try {
      final transaction = solana.VersionedTransaction.deserialize(
        Uint8List.fromList(serializedTransaction),
      );
      transaction.sanitize();
      final message = transaction.message;
      final staticKeys = message.staticAccountKeys;
      final signerAddresses = staticKeys
          .take(message.header.numRequiredSignatures)
          .map((key) => key.toBase58())
          .toList(growable: false);
      if (!signerAddresses.contains(from)) {
        return DappTransactionPreview(
          from: from,
          value: '0 SOL',
          data: rawData,
          decodedInfo:
              'Solana transaction does not require the selected account',
          highRisk: true,
        );
      }
      final instructions = _solanaCompiledInstructions(message);
      final transfer = count == 1 && instructions.length == 1
          ? _decodeSolanaSystemTransfer(instructions.single, staticKeys)
          : null;
      if (transfer != null && transfer.from == from) {
        return DappTransactionPreview(
          from: from,
          to: transfer.to,
          value: '${_formatUnits(transfer.lamports, 9)} SOL',
          data: rawData,
          decodedInfo:
              'System Program SOL transfer to ${transfer.to} '
              'amount ${_formatUnits(transfer.lamports, 9)} SOL',
          highRisk: false,
        );
      }
      final programIds = instructions
          .map((instruction) {
            final index = instruction.programIdIndex;
            if (index < 0 || index >= staticKeys.length) {
              return 'unresolved-program-$index';
            }
            return staticKeys[index].toBase58();
          })
          .toSet()
          .join(', ');
      final summaryPrefix = count == 1
          ? 'Solana transaction'
          : '$count Solana transactions; first transaction';
      return DappTransactionPreview(
        from: from,
        value: '0 SOL',
        data: rawData,
        decodedInfo:
            '$summaryPrefix has ${instructions.length} instructions; '
            'programs: ${programIds.isEmpty ? 'none' : programIds}; '
            'required signers: ${signerAddresses.join(', ')}',
        highRisk: true,
      );
    } catch (_) {
      return DappTransactionPreview(
        from: from,
        value: '0 SOL',
        data: rawData,
        decodedInfo:
            'Unable to decode Solana transaction '
            '(${serializedTransaction.length} bytes); blind signing required',
        highRisk: true,
      );
    }
  }
}

String _suiCommandSummary(Map<dynamic, dynamic> command) {
  final moveCall = command['MoveCall'];
  if (moveCall is Map) {
    final package = _shortSuiId(moveCall['package']?.toString() ?? 'unknown');
    final module = moveCall['module']?.toString() ?? 'unknown';
    final function = moveCall['function']?.toString() ?? 'unknown';
    return 'MoveCall $package::$module::$function';
  }
  final transferObjects = command['TransferObjects'];
  if (transferObjects is Map) {
    final objects = transferObjects['objects'];
    final count = objects is List ? objects.length : 0;
    return 'TransferObjects ($count objects)';
  }
  final splitCoins = command['SplitCoins'];
  if (splitCoins is Map) {
    final amounts = splitCoins['amounts'];
    final count = amounts is List ? amounts.length : 0;
    return 'SplitCoins ($count outputs)';
  }
  if (command.containsKey('MergeCoins')) {
    return 'MergeCoins';
  }
  if (command.containsKey('Publish')) {
    return 'Publish package';
  }
  if (command.containsKey('Upgrade')) {
    return 'Upgrade package';
  }
  if (command.containsKey('MakeMoveVec')) {
    return 'MakeMoveVec';
  }
  return command.keys.isEmpty
      ? 'Unknown command'
      : command.keys.first.toString();
}

String _shortSuiId(String value) {
  final normalized = normalizeSuiAddressInput(value);
  if (normalized == null) {
    return value;
  }
  final digits = normalized.substring(2).replaceFirst(RegExp(r'^0+'), '');
  return '0x${digits.isEmpty ? '0' : digits}';
}

final class _SolanaCompiledInstruction {
  const _SolanaCompiledInstruction({
    required this.programIdIndex,
    required this.accounts,
    required this.data,
  });

  final int programIdIndex;
  final List<int> accounts;
  final List<int> data;
}

List<_SolanaCompiledInstruction> _solanaCompiledInstructions(
  solana.VersionedMessage message,
) {
  final legacy = message.legacyMessage;
  if (legacy != null) {
    return legacy.compiledInstructions
        .map(
          (instruction) => _SolanaCompiledInstruction(
            programIdIndex: instruction.programIdIndex,
            accounts: instruction.accountKeyIndexes,
            data: instruction.data,
          ),
        )
        .toList(growable: false);
  }
  final v0 = message.v0Message;
  if (v0 != null) {
    return v0.compiledInstructions
        .map(
          (instruction) => _SolanaCompiledInstruction(
            programIdIndex: instruction.programIdIndex,
            accounts: instruction.accounts,
            data: solana.base58Decode(instruction.data),
          ),
        )
        .toList(growable: false);
  }
  final v1 = message.v1Message;
  if (v1 != null) {
    return v1.compiledInstructions
        .map(
          (instruction) => _SolanaCompiledInstruction(
            programIdIndex: instruction.programIdIndex,
            accounts: instruction.accounts,
            data: solana.base58Decode(instruction.data),
          ),
        )
        .toList(growable: false);
  }
  return const [];
}

({String from, String to, BigInt lamports})? _decodeSolanaSystemTransfer(
  _SolanaCompiledInstruction instruction,
  List<solana.PublicKey> staticKeys,
) {
  if (instruction.programIdIndex < 0 ||
      instruction.programIdIndex >= staticKeys.length ||
      staticKeys[instruction.programIdIndex] !=
          solana.SystemProgram.programId ||
      instruction.accounts.length < 2 ||
      instruction.data.length != 12 ||
      _readUint32Le(instruction.data, 0) != 2) {
    return null;
  }
  final fromIndex = instruction.accounts[0];
  final toIndex = instruction.accounts[1];
  if (fromIndex < 0 ||
      fromIndex >= staticKeys.length ||
      toIndex < 0 ||
      toIndex >= staticKeys.length) {
    return null;
  }
  return (
    from: staticKeys[fromIndex].toBase58(),
    to: staticKeys[toIndex].toBase58(),
    lamports: _readUint64Le(instruction.data, 4),
  );
}

int _readUint32Le(List<int> bytes, int offset) {
  return bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}

BigInt _readUint64Le(List<int> bytes, int offset) {
  var value = BigInt.zero;
  for (var index = 7; index >= 0; index -= 1) {
    value = (value << 8) | BigInt.from(bytes[offset + index]);
  }
  return value;
}

String _formatUnits(BigInt value, int decimals) {
  if (value == BigInt.zero) {
    return '0';
  }
  final negative = value.isNegative;
  final digits = value.abs().toString().padLeft(decimals + 1, '0');
  final whole = digits.substring(0, digits.length - decimals);
  final fraction = digits
      .substring(digits.length - decimals)
      .replaceFirst(RegExp(r'0+$'), '');
  final formatted = fraction.isEmpty ? whole : '$whole.$fraction';
  return negative ? '-$formatted' : formatted;
}
