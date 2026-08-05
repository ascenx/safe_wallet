import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart' as web3;

import '../../../shared/network/bounded_http_client.dart';
import '../application/fee_estimate_provider.dart';
import '../domain/transaction_request.dart';
import 'bitcoin_address_script.dart';

final class BitcoinTransactionBroadcastInput {
  const BitcoinTransactionBroadcastInput({
    required this.apiBaseUrl,
    required this.privateKey,
    required this.fromAddress,
    required this.transaction,
    required this.feeEstimate,
  });

  final String apiBaseUrl;
  final String privateKey;
  final String fromAddress;
  final TransactionRequest transaction;
  final FeeEstimate feeEstimate;
}

abstract interface class BitcoinTransactionService {
  Future<String> signAndBroadcast(BitcoinTransactionBroadcastInput input);
}

final class HttpBitcoinTransactionService implements BitcoinTransactionService {
  HttpBitcoinTransactionService({http.Client? client})
    : _client = client ?? BoundedHttpClient();

  final http.Client _client;

  @override
  Future<String> signAndBroadcast(
    BitcoinTransactionBroadcastInput input,
  ) async {
    final privateKeyBytes = await _privateKeyBytes(input.privateKey);
    final privateKey = wallet.PrivateKey(
      web3.bytesToUnsignedInt(privateKeyBytes),
    );
    final publicKey = wallet.bitcoinbech32.createPublicKey(privateKey).value;
    final source = _p2wpkhAddress(input.fromAddress);
    final destination = await bitcoinScriptPubKeyForAddress(
      input.transaction.toAddress,
    );
    final amount = _amountInSatoshis(input.transaction);
    final utxos = await _fetchSpendableUtxos(input.apiBaseUrl, source.address);
    final satsPerVbyte = input.feeEstimate.satsPerVbyte;
    final rawTransaction = satsPerVbyte == null
        ? await _buildWithFixedFee(
            utxos: utxos,
            amount: amount,
            fee: input.feeEstimate.feeInBaseUnits,
            destination: destination,
            source: source,
            privateKey: privateKeyBytes,
            publicKey: publicKey,
          )
        : await _buildWithFeeRate(
            utxos: utxos,
            amount: amount,
            satsPerVbyte: satsPerVbyte,
            destination: destination,
            source: source,
            privateKey: privateKeyBytes,
            publicKey: publicKey,
          );
    return _broadcast(input.apiBaseUrl, rawTransaction);
  }

  Future<Uint8List> _buildWithFixedFee({
    required List<_BitcoinUtxo> utxos,
    required BigInt amount,
    required BigInt fee,
    required Uint8List destination,
    required _P2wpkhAddress source,
    required Uint8List privateKey,
    required Uint8List publicKey,
  }) async {
    final selection = _selectUtxos(utxos: utxos, amount: amount, fee: fee);
    final unsigned = _UnsignedBitcoinTransaction(
      inputs: selection.utxos,
      outputs: _outputsFor(
        destination: destination,
        amount: amount,
        changeAddress: source,
        change: selection.change,
      ),
    );
    return _signP2wpkh(
      unsigned,
      source: source,
      privateKey: privateKey,
      publicKey: publicKey,
    );
  }

  Future<Uint8List> _buildWithFeeRate({
    required List<_BitcoinUtxo> utxos,
    required BigInt amount,
    required double satsPerVbyte,
    required Uint8List destination,
    required _P2wpkhAddress source,
    required Uint8List privateKey,
    required Uint8List publicKey,
  }) async {
    if (!satsPerVbyte.isFinite || satsPerVbyte <= 0) {
      throw StateError('Bitcoin fee rate is invalid');
    }
    final selected = <_BitcoinUtxo>[];
    var total = BigInt.zero;
    for (final utxo in utxos) {
      selected.add(utxo);
      total += utxo.value;
      if (total <= amount) {
        continue;
      }
      final inputs = List<_BitcoinUtxo>.unmodifiable(selected);
      final withChange = await _tryBuildRateTransactionWithChange(
        inputs: inputs,
        total: total,
        amount: amount,
        satsPerVbyte: satsPerVbyte,
        destination: destination,
        source: source,
        privateKey: privateKey,
        publicKey: publicKey,
      );
      if (withChange != null) {
        return withChange;
      }
      final withoutChange = await _tryBuildRateTransactionWithoutChange(
        inputs: inputs,
        total: total,
        amount: amount,
        satsPerVbyte: satsPerVbyte,
        destination: destination,
        source: source,
        privateKey: privateKey,
        publicKey: publicKey,
      );
      if (withoutChange != null) {
        return withoutChange;
      }
    }
    throw StateError('Bitcoin balance is insufficient for transfer');
  }

  Future<Uint8List?> _tryBuildRateTransactionWithChange({
    required List<_BitcoinUtxo> inputs,
    required BigInt total,
    required BigInt amount,
    required double satsPerVbyte,
    required Uint8List destination,
    required _P2wpkhAddress source,
    required Uint8List privateKey,
    required Uint8List publicKey,
  }) async {
    var fee = BigInt.one;
    for (var attempt = 0; attempt < 16; attempt += 1) {
      final change = total - amount - fee;
      if (change < _dustSatoshis) {
        return null;
      }
      final transaction = _UnsignedBitcoinTransaction(
        inputs: inputs,
        outputs: _outputsFor(
          destination: destination,
          amount: amount,
          changeAddress: source,
          change: change,
        ),
      );
      final rawTransaction = await _signP2wpkh(
        transaction,
        source: source,
        privateKey: privateKey,
        publicKey: publicKey,
      );
      final requiredFee = _feeForRate(
        satsPerVbyte,
        _transactionVbytes(rawTransaction, transaction),
      );
      if (fee >= requiredFee) {
        return rawTransaction;
      }
      fee = requiredFee;
    }
    throw StateError('Bitcoin fee calculation did not converge');
  }

  Future<Uint8List?> _tryBuildRateTransactionWithoutChange({
    required List<_BitcoinUtxo> inputs,
    required BigInt total,
    required BigInt amount,
    required double satsPerVbyte,
    required Uint8List destination,
    required _P2wpkhAddress source,
    required Uint8List privateKey,
    required Uint8List publicKey,
  }) async {
    final fee = total - amount;
    if (fee <= BigInt.zero) {
      return null;
    }
    final transaction = _UnsignedBitcoinTransaction(
      inputs: inputs,
      outputs: [_BitcoinOutput(value: amount, scriptPubKey: destination)],
    );
    final rawTransaction = await _signP2wpkh(
      transaction,
      source: source,
      privateKey: privateKey,
      publicKey: publicKey,
    );
    final requiredFee = _feeForRate(
      satsPerVbyte,
      _transactionVbytes(rawTransaction, transaction),
    );
    return fee >= requiredFee ? rawTransaction : null;
  }

  Future<List<_BitcoinUtxo>> _fetchSpendableUtxos(
    String apiBaseUrl,
    String address,
  ) async {
    final response = await _client.get(
      _endpoint(apiBaseUrl, '/address/$address/utxo'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Bitcoin UTXO query failed');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw StateError('Bitcoin UTXO response was not a list');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(_BitcoinUtxo.fromJson)
        .where((utxo) => utxo.value > BigInt.zero)
        .toList(growable: false);
  }

  Future<String> _broadcast(String apiBaseUrl, Uint8List rawTransaction) async {
    final request = http.Request('POST', _endpoint(apiBaseUrl, '/tx'))
      ..headers['content-type'] = 'text/plain'
      ..bodyBytes = utf8.encode(web3.bytesToHex(rawTransaction));
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Bitcoin transaction broadcast failed '
        '(${response.statusCode}): ${response.body}',
      );
    }
    final txid = response.body.trim();
    if (txid.isEmpty) {
      throw StateError('Bitcoin transaction broadcast returned empty txid');
    }
    return txid;
  }

  Future<Uint8List> _signP2wpkh(
    _UnsignedBitcoinTransaction transaction, {
    required _P2wpkhAddress source,
    required Uint8List privateKey,
    required Uint8List publicKey,
  }) async {
    final signatures = <Uint8List>[];
    for (
      var inputIndex = 0;
      inputIndex < transaction.inputs.length;
      inputIndex += 1
    ) {
      final sighash = await _signatureHash(
        transaction,
        inputIndex: inputIndex,
        source: source,
      );
      final signature = web3.sign(sighash, privateKey);
      signatures.add(
        Uint8List.fromList([
          ..._derEncode(signature.r, signature.s),
          _sighashAll,
        ]),
      );
    }
    return _serializeWitnessTransaction(
      transaction,
      signatures: signatures,
      publicKey: publicKey,
    );
  }

  Future<Uint8List> _signatureHash(
    _UnsignedBitcoinTransaction transaction, {
    required int inputIndex,
    required _P2wpkhAddress source,
  }) async {
    final currentInput = transaction.inputs[inputIndex];
    final writer = _ByteWriter()
      ..writeUint32(_transactionVersion)
      ..writeBytes(await _hash256(_serializeOutpoints(transaction.inputs)))
      ..writeBytes(await _hash256(_serializeSequences(transaction.inputs)))
      ..writeBytes(_outpoint(currentInput))
      ..writeVarInt(source.scriptCode.length)
      ..writeBytes(source.scriptCode)
      ..writeUint64(currentInput.value)
      ..writeUint32(_sequence)
      ..writeBytes(
        await _hash256(_serializeOutputsForSignature(transaction.outputs)),
      )
      ..writeUint32(_lockTime)
      ..writeUint32(_sighashAll);
    return _hash256(writer.toBytes());
  }

  void close() => _client.close();
}

Future<Uint8List> _hash256(Uint8List bytes) async {
  final first = await _sha256.hash(bytes);
  final second = await _sha256.hash(first.bytes);
  return Uint8List.fromList(second.bytes);
}

final class _BitcoinUtxo {
  const _BitcoinUtxo({
    required this.txid,
    required this.vout,
    required this.value,
  });

  factory _BitcoinUtxo.fromJson(Map<String, dynamic> json) {
    final txid = json['txid'];
    final vout = json['vout'];
    final value = json['value'];
    if (txid is! String || vout is! int || value is! num) {
      throw StateError('Bitcoin UTXO response has invalid fields');
    }
    return _BitcoinUtxo(txid: txid, vout: vout, value: BigInt.from(value));
  }

  final String txid;
  final int vout;
  final BigInt value;
}

final class _UtxoSelection {
  const _UtxoSelection({required this.utxos, required this.change});

  final List<_BitcoinUtxo> utxos;
  final BigInt change;
}

final class _UnsignedBitcoinTransaction {
  const _UnsignedBitcoinTransaction({
    required this.inputs,
    required this.outputs,
  });

  final List<_BitcoinUtxo> inputs;
  final List<_BitcoinOutput> outputs;
}

final class _BitcoinOutput {
  const _BitcoinOutput({required this.value, required this.scriptPubKey});

  final BigInt value;
  final Uint8List scriptPubKey;
}

final class _P2wpkhAddress {
  const _P2wpkhAddress({
    required this.address,
    required this.witnessProgram,
    required this.scriptPubKey,
  });

  final String address;
  final Uint8List witnessProgram;
  final Uint8List scriptPubKey;

  Uint8List get scriptCode {
    return Uint8List.fromList([
      0x76,
      0xa9,
      0x14,
      ...witnessProgram,
      0x88,
      0xac,
    ]);
  }
}

_UtxoSelection _selectUtxos({
  required List<_BitcoinUtxo> utxos,
  required BigInt amount,
  required BigInt fee,
}) {
  final target = amount + fee;
  final selected = <_BitcoinUtxo>[];
  var total = BigInt.zero;
  for (final utxo in utxos) {
    selected.add(utxo);
    total += utxo.value;
    if (total >= target) {
      return _UtxoSelection(utxos: selected, change: total - target);
    }
  }
  throw StateError('Bitcoin balance is insufficient for transfer');
}

List<_BitcoinOutput> _outputsFor({
  required Uint8List destination,
  required BigInt amount,
  required _P2wpkhAddress changeAddress,
  required BigInt change,
}) {
  final outputs = [_BitcoinOutput(value: amount, scriptPubKey: destination)];
  if (change >= _dustSatoshis) {
    outputs.add(
      _BitcoinOutput(value: change, scriptPubKey: changeAddress.scriptPubKey),
    );
  }
  return outputs;
}

Uint8List _serializeWitnessTransaction(
  _UnsignedBitcoinTransaction transaction, {
  required List<Uint8List> signatures,
  required Uint8List publicKey,
}) {
  final writer = _ByteWriter()
    ..writeUint32(_transactionVersion)
    ..writeByte(0x00)
    ..writeByte(0x01)
    ..writeVarInt(transaction.inputs.length);
  for (final input in transaction.inputs) {
    writer
      ..writeBytes(_outpoint(input))
      ..writeVarInt(0)
      ..writeUint32(_sequence);
  }
  writer.writeBytes(_serializeOutputs(transaction.outputs));
  for (final signature in signatures) {
    writer
      ..writeVarInt(2)
      ..writeVarInt(signature.length)
      ..writeBytes(signature)
      ..writeVarInt(publicKey.length)
      ..writeBytes(publicKey);
  }
  writer.writeUint32(_lockTime);
  return writer.toBytes();
}

Uint8List _serializeStrippedTransaction(
  _UnsignedBitcoinTransaction transaction,
) {
  final writer = _ByteWriter()
    ..writeUint32(_transactionVersion)
    ..writeVarInt(transaction.inputs.length);
  for (final input in transaction.inputs) {
    writer
      ..writeBytes(_outpoint(input))
      ..writeVarInt(0)
      ..writeUint32(_sequence);
  }
  writer
    ..writeBytes(_serializeOutputs(transaction.outputs))
    ..writeUint32(_lockTime);
  return writer.toBytes();
}

int _transactionVbytes(
  Uint8List witnessTransaction,
  _UnsignedBitcoinTransaction transaction,
) {
  final strippedSize = _serializeStrippedTransaction(transaction).length;
  final weight = (strippedSize * 3) + witnessTransaction.length;
  return (weight + 3) ~/ 4;
}

BigInt _feeForRate(double satsPerVbyte, int transactionVbytes) {
  final fee = satsPerVbyte * transactionVbytes;
  if (!fee.isFinite || fee <= 0) {
    throw StateError('Bitcoin fee calculation overflowed');
  }
  return BigInt.from(math.max(1, fee.ceil()));
}

Uint8List _serializeOutpoints(List<_BitcoinUtxo> inputs) {
  final writer = _ByteWriter();
  for (final input in inputs) {
    writer.writeBytes(_outpoint(input));
  }
  return writer.toBytes();
}

Uint8List _serializeSequences(List<_BitcoinUtxo> inputs) {
  final writer = _ByteWriter();
  for (var index = 0; index < inputs.length; index += 1) {
    writer.writeUint32(_sequence);
  }
  return writer.toBytes();
}

Uint8List _serializeOutputs(List<_BitcoinOutput> outputs) {
  final writer = _ByteWriter()..writeVarInt(outputs.length);
  for (final output in outputs) {
    writer
      ..writeUint64(output.value)
      ..writeVarInt(output.scriptPubKey.length)
      ..writeBytes(output.scriptPubKey);
  }
  return writer.toBytes();
}

Uint8List _serializeOutputsForSignature(List<_BitcoinOutput> outputs) {
  final writer = _ByteWriter();
  for (final output in outputs) {
    writer
      ..writeUint64(output.value)
      ..writeVarInt(output.scriptPubKey.length)
      ..writeBytes(output.scriptPubKey);
  }
  return writer.toBytes();
}

Uint8List _outpoint(_BitcoinUtxo input) {
  return Uint8List.fromList([
    ...web3.hexToBytes(input.txid).reversed,
    ..._uint32Bytes(input.vout),
  ]);
}

_P2wpkhAddress _p2wpkhAddress(String address) {
  final decoded = wallet.segwit.decode(address);
  if (decoded.version != 0 || decoded.program.length != 20) {
    throw StateError('Only native P2WPKH Bitcoin addresses are supported');
  }
  return _P2wpkhAddress(
    address: address,
    witnessProgram: Uint8List.fromList(decoded.program),
    scriptPubKey: Uint8List.fromList(web3.hexToBytes(decoded.scriptPubKey)),
  );
}

BigInt _amountInSatoshis(TransactionRequest request) {
  final amount = request.amountInBaseUnits;
  if (amount == null) {
    throw ArgumentError.value(amount, 'amountInBaseUnits', 'must not be null');
  }
  return BigInt.parse(amount);
}

Future<Uint8List> _privateKeyBytes(String privateKey) async {
  final normalized = _normalizePrivateKey(privateKey);
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(normalized)) {
    return _wifPrivateKeyBytes(normalized);
  }
  final bytes = web3.hexToBytes(normalized);
  if (bytes.length != 32) {
    throw ArgumentError.value(privateKey, 'privateKey', 'must be 32 bytes');
  }
  return bytes;
}

String _normalizePrivateKey(String privateKey) {
  final trimmed = privateKey.trim();
  return trimmed.startsWith('0x') ? trimmed.substring(2) : trimmed;
}

Future<Uint8List> _wifPrivateKeyBytes(String privateKey) async {
  final decoded = _decodeBase58(privateKey);
  if (decoded.length != 37 && decoded.length != 38) {
    throw FormatException('Invalid Bitcoin WIF private key', privateKey);
  }
  final payload = decoded.sublist(0, decoded.length - 4);
  final checksum = decoded.sublist(decoded.length - 4);
  final expectedChecksum = (await _hash256(
    Uint8List.fromList(payload),
  )).sublist(0, 4);
  for (var index = 0; index < checksum.length; index += 1) {
    if (checksum[index] != expectedChecksum[index]) {
      throw FormatException('Invalid Bitcoin WIF checksum', privateKey);
    }
  }
  final version = payload.first;
  if (version != 0x80 && version != 0xef) {
    throw FormatException('Unsupported Bitcoin WIF network', privateKey);
  }
  if (payload.length == 34 && payload.last != 0x01) {
    throw FormatException('Invalid Bitcoin WIF compression flag', privateKey);
  }
  return Uint8List.fromList(payload.sublist(1, 33));
}

Uint8List _decodeBase58(String value) {
  var decoded = BigInt.zero;
  for (final codeUnit in value.codeUnits) {
    final index = _base58Alphabet.indexOf(String.fromCharCode(codeUnit));
    if (index < 0) {
      throw FormatException('Invalid Bitcoin WIF character', value);
    }
    decoded = decoded * BigInt.from(58) + BigInt.from(index);
  }
  final leadingZeroes = value.codeUnits
      .takeWhile((unit) => unit == 0x31)
      .length;
  return Uint8List.fromList([
    ...List<int>.filled(leadingZeroes, 0),
    ..._unsignedIntToBytes(decoded),
  ]);
}

List<int> _unsignedIntToBytes(BigInt value) {
  if (value == BigInt.zero) {
    return const [];
  }
  final bytes = <int>[];
  var remaining = value;
  while (remaining > BigInt.zero) {
    bytes.insert(0, (remaining & BigInt.from(0xff)).toInt());
    remaining >>= 8;
  }
  return bytes;
}

Uint8List _derEncode(BigInt r, BigInt s) {
  final encodedR = _derInteger(r);
  final encodedS = _derInteger(s);
  final sequenceLength = encodedR.length + encodedS.length;
  return Uint8List.fromList([0x30, sequenceLength, ...encodedR, ...encodedS]);
}

Uint8List _derInteger(BigInt value) {
  final bytes = web3.unsignedIntToBytes(value);
  final normalized = bytes.isEmpty ? Uint8List.fromList([0]) : bytes;
  final prefixed = normalized.first >= 0x80
      ? Uint8List.fromList([0, ...normalized])
      : normalized;
  return Uint8List.fromList([0x02, prefixed.length, ...prefixed]);
}

Uri _endpoint(String apiBaseUrl, String path) {
  final base = Uri.parse(apiBaseUrl);
  final normalizedBasePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(path: '$normalizedBasePath$path');
}

Uint8List _uint32Bytes(int value) {
  return Uint8List.fromList([
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ]);
}

final class _ByteWriter {
  final _bytes = <int>[];

  void writeByte(int value) {
    _bytes.add(value & 0xff);
  }

  void writeBytes(Iterable<int> bytes) {
    _bytes.addAll(bytes.map((byte) => byte & 0xff));
  }

  void writeUint32(int value) {
    writeBytes(_uint32Bytes(value));
  }

  void writeUint64(BigInt value) {
    var remaining = value;
    for (var index = 0; index < 8; index += 1) {
      writeByte((remaining & BigInt.from(0xff)).toInt());
      remaining >>= 8;
    }
  }

  void writeVarInt(int value) {
    if (value < 0xfd) {
      writeByte(value);
      return;
    }
    if (value <= 0xffff) {
      writeByte(0xfd);
      writeByte(value & 0xff);
      writeByte((value >> 8) & 0xff);
      return;
    }
    if (value <= 0xffffffff) {
      writeByte(0xfe);
      writeUint32(value);
      return;
    }
    writeByte(0xff);
    writeUint64(BigInt.from(value));
  }

  Uint8List toBytes() => Uint8List.fromList(_bytes);
}

const _transactionVersion = 2;
const _sequence = 0xffffffff;
const _lockTime = 0;
const _sighashAll = 1;
final _sha256 = Sha256();
final _dustSatoshis = BigInt.from(546);
const _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
