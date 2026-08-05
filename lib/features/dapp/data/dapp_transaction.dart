import 'dart:typed_data';

import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart' as web3;

import '../../assets/domain/token_info.dart';
import '../../chains/domain/chain_config.dart';

final class DappTransactionPreview {
  const DappTransactionPreview({
    required this.from,
    this.to,
    this.value,
    this.contractAddress,
    this.data,
    this.decodedInfo,
    this.estimatedFee,
    this.simulationWarning,
    required this.highRisk,
  });

  final String from;
  final String? to;
  final String? value;
  final String? contractAddress;
  final String? data;
  final String? decodedInfo;
  final String? estimatedFee;
  final String? simulationWarning;
  final bool highRisk;
}

final class DappTransactionSimulation {
  const DappTransactionSimulation.succeeded({this.gasLimit, this.gasPriceWei})
    : succeeded = true,
      warning = null;

  const DappTransactionSimulation.failed(this.warning)
    : succeeded = false,
      gasLimit = null,
      gasPriceWei = null;

  final bool succeeded;
  final String? warning;
  final int? gasLimit;
  final BigInt? gasPriceWei;
}

final class DappEvmTransaction {
  const DappEvmTransaction({
    required this.from,
    this.to,
    this.valueWei,
    this.nonce,
    this.gasLimit,
    this.gasPriceWei,
    this.maxFeePerGasWei,
    this.maxPriorityFeePerGasWei,
    this.data,
  });

  final String from;
  final String? to;
  final BigInt? valueWei;
  final int? nonce;
  final int? gasLimit;
  final BigInt? gasPriceWei;
  final BigInt? maxFeePerGasWei;
  final BigInt? maxPriorityFeePerGasWei;
  final Uint8List? data;

  DappTransactionPreview preview({
    required ChainConfig chain,
    required TokenInfo? token,
    DappTransactionSimulation? simulation,
  }) {
    final decodedCall = _decodeKnownCall(data, token: token);
    final hasContractData = data != null && data!.isNotEmpty;
    return DappTransactionPreview(
      from: from,
      to: to,
      value: '${_formatUnits(valueWei ?? BigInt.zero, 18)} ${chain.symbol}',
      contractAddress: hasContractData ? to : null,
      data: data == null ? null : web3.bytesToHex(data!, include0x: true),
      decodedInfo: decodedCall?.info,
      estimatedFee: _estimateFeeText(simulation, chain.symbol),
      simulationWarning: simulation?.warning,
      highRisk:
          (hasContractData && decodedCall == null) ||
          (decodedCall?.highRisk ?? false) ||
          (simulation != null && !simulation.succeeded),
    );
  }

  Map<String, Object?> toRpcJson() {
    return {
      'from': from,
      if (to != null) 'to': to,
      if (valueWei != null) 'value': _hexQuantity(valueWei!),
      if (gasLimit != null) 'gas': _hexQuantity(BigInt.from(gasLimit!)),
      if (gasPriceWei != null) 'gasPrice': _hexQuantity(gasPriceWei!),
      if (maxFeePerGasWei != null)
        'maxFeePerGas': _hexQuantity(maxFeePerGasWei!),
      if (maxPriorityFeePerGasWei != null)
        'maxPriorityFeePerGas': _hexQuantity(maxPriorityFeePerGasWei!),
      if (data != null) 'data': web3.bytesToHex(data!, include0x: true),
    };
  }

  web3.Transaction toWeb3Transaction() {
    return web3.Transaction(
      from: wallet.EthereumAddress.fromHex(from),
      to: to == null ? null : wallet.EthereumAddress.fromHex(to!),
      value: valueWei == null ? null : wallet.EtherAmount.inWei(valueWei!),
      nonce: nonce,
      maxGas: gasLimit,
      gasPrice: gasPriceWei == null
          ? null
          : wallet.EtherAmount.inWei(gasPriceWei!),
      maxFeePerGas: maxFeePerGasWei == null
          ? null
          : wallet.EtherAmount.inWei(maxFeePerGasWei!),
      maxPriorityFeePerGas: maxPriorityFeePerGasWei == null
          ? null
          : wallet.EtherAmount.inWei(maxPriorityFeePerGasWei!),
      data: data,
    );
  }

  String? _estimateFeeText(
    DappTransactionSimulation? simulation,
    String symbol,
  ) {
    final limit = gasLimit ?? simulation?.gasLimit;
    if (limit == null) {
      return null;
    }
    final gasPrice = maxFeePerGasWei ?? gasPriceWei ?? simulation?.gasPriceWei;
    if (gasPrice == null) {
      return null;
    }
    final feeWei = BigInt.from(limit) * gasPrice;
    return '${_formatUnits(feeWei, 18)} $symbol';
  }

  static ({String info, bool highRisk})? _decodeKnownCall(
    Uint8List? data, {
    required TokenInfo? token,
  }) {
    if (data == null || data.length < 4) {
      return null;
    }
    final hex = web3.bytesToHex(data);
    if (hex.startsWith('a9059cbb') && hex.length >= 136) {
      if (token == null) {
        return null;
      }
      final recipient = '0x${hex.substring(32, 72)}';
      final amount = BigInt.parse(hex.substring(72, 136), radix: 16);
      return (
        info:
            '${token.symbol} transfer to $recipient amount '
            '${_formatUnits(amount, token.decimals)} ${token.symbol}',
        highRisk: false,
      );
    }
    if (hex.startsWith('095ea7b3') && hex.length >= 136) {
      if (token == null) {
        return (info: 'Unverified contract approval-like call', highRisk: true);
      }
      final spender = '0x${hex.substring(32, 72)}';
      final amount = BigInt.parse(hex.substring(72, 136), radix: 16);
      final unlimited = amount == (BigInt.one << 256) - BigInt.one;
      return (
        info: unlimited
            ? '${token.symbol} unlimited approval for $spender'
            : '${token.symbol} approval for $spender amount '
                  '${_formatUnits(amount, token.decimals)} ${token.symbol}',
        highRisk: true,
      );
    }
    if (hex.startsWith('a22cb465') && hex.length >= 136) {
      final operator = '0x${hex.substring(32, 72)}';
      final approved =
          BigInt.parse(hex.substring(72, 136), radix: 16) != BigInt.zero;
      return (
        info: 'NFT setApprovalForAll operator $operator approved $approved',
        highRisk: approved,
      );
    }
    return null;
  }
}

String _hexQuantity(BigInt value) => '0x${value.toRadixString(16)}';

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
