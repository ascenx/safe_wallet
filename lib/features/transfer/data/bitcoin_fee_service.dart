import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../../shared/network/bounded_http_client.dart';
import 'bitcoin_address_script.dart';

final class BitcoinFeeEstimate {
  const BitcoinFeeEstimate({
    required this.satoshis,
    this.satsPerVbyte,
    this.transactionVbytes,
    this.feeRateOptions = const [],
    this.transactionVbytesOptions = const [],
    this.feeOptionsSatoshis = const [],
    this.confirmationBlocks,
    this.confirmationBlockOptions = const [],
  });

  final BigInt satoshis;
  final double? satsPerVbyte;
  final int? transactionVbytes;
  final List<double> feeRateOptions;
  final List<int> transactionVbytesOptions;
  final List<BigInt> feeOptionsSatoshis;
  final int? confirmationBlocks;
  final List<int> confirmationBlockOptions;
}

abstract interface class BitcoinFeeService {
  Future<BitcoinFeeEstimate> estimateTransferFee({
    required String apiBaseUrl,
    required String fromAddress,
    required String toAddress,
    required BigInt satoshis,
    bool sweep = false,
  });
}

final class HttpBitcoinFeeService implements BitcoinFeeService {
  HttpBitcoinFeeService({http.Client? client})
    : _client = client ?? BoundedHttpClient();

  final http.Client _client;

  @override
  Future<BitcoinFeeEstimate> estimateTransferFee({
    required String apiBaseUrl,
    required String fromAddress,
    required String toAddress,
    required BigInt satoshis,
    bool sweep = false,
  }) async {
    final feeResponse = await _client.get(
      _endpoint(apiBaseUrl, '/fee-estimates'),
    );
    if (feeResponse.statusCode < 200 || feeResponse.statusCode >= 300) {
      throw StateError('Bitcoin fee estimate query failed');
    }
    final decoded = jsonDecode(feeResponse.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Bitcoin fee estimate response was not an object');
    }
    final rateSelection = _feeRates(decoded);
    final feeRates = rateSelection.rates;
    final utxos = await _fetchUtxos(apiBaseUrl, fromAddress);
    final recipientOutputVbytes = _outputVbytes(
      await bitcoinScriptPubKeyForAddress(toAddress),
    );
    final selections = feeRates
        .map(
          (rate) => sweep
              ? _estimateSweepFee(
                  utxos: utxos,
                  satsPerVbyte: rate,
                  recipientOutputVbytes: recipientOutputVbytes,
                )
              : _estimateSelectedFee(
                  utxos: utxos,
                  amount: satoshis,
                  satsPerVbyte: rate,
                  recipientOutputVbytes: recipientOutputVbytes,
                ),
        )
        .toList(growable: false);
    return BitcoinFeeEstimate(
      satoshis: selections[1].fee,
      satsPerVbyte: feeRates[1],
      transactionVbytes: selections[1].vbytes,
      feeRateOptions: feeRates,
      transactionVbytesOptions: selections
          .map((selection) => selection.vbytes)
          .toList(),
      feeOptionsSatoshis: selections.map((selection) => selection.fee).toList(),
      confirmationBlocks: rateSelection.confirmationBlocks[1],
      confirmationBlockOptions: rateSelection.confirmationBlocks,
    );
  }

  Future<List<_BitcoinFeeUtxo>> _fetchUtxos(
    String apiBaseUrl,
    String fromAddress,
  ) async {
    final response = await _client.get(
      _endpoint(apiBaseUrl, '/address/$fromAddress/utxo'),
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
        .map(_BitcoinFeeUtxo.fromJson)
        .where((utxo) => utxo.value > BigInt.zero)
        .toList(growable: false);
  }

  void close() => _client.close();
}

final class _BitcoinFeeUtxo {
  const _BitcoinFeeUtxo({required this.value});

  factory _BitcoinFeeUtxo.fromJson(Map<String, dynamic> json) {
    final value = json['value'];
    if (value is! num) {
      throw StateError('Bitcoin UTXO response has invalid value');
    }
    return _BitcoinFeeUtxo(value: BigInt.from(value));
  }

  final BigInt value;
}

final class _BitcoinFeeSelection {
  const _BitcoinFeeSelection({required this.fee, required this.vbytes});

  final BigInt fee;
  final int vbytes;
}

_BitcoinFeeSelection _estimateSelectedFee({
  required List<_BitcoinFeeUtxo> utxos,
  required BigInt amount,
  required double satsPerVbyte,
  required int recipientOutputVbytes,
}) {
  var total = BigInt.zero;
  for (var index = 0; index < utxos.length; index += 1) {
    total += utxos[index].value;
    final inputCount = index + 1;
    final feeWithChange = _feeFor(
      satsPerVbyte: satsPerVbyte,
      inputCount: inputCount,
      recipientOutputVbytes: recipientOutputVbytes,
      hasChange: true,
    );
    if (total >= amount + feeWithChange) {
      final change = total - amount - feeWithChange;
      if (change >= _dustSatoshis) {
        return _BitcoinFeeSelection(
          fee: feeWithChange,
          vbytes: _transactionVbytes(
            inputCount: inputCount,
            recipientOutputVbytes: recipientOutputVbytes,
            hasChange: true,
          ),
        );
      }
    }

    final feeWithoutChange = _feeFor(
      satsPerVbyte: satsPerVbyte,
      inputCount: inputCount,
      recipientOutputVbytes: recipientOutputVbytes,
      hasChange: false,
    );
    final remainder = total - amount;
    if (remainder >= feeWithoutChange) {
      return _BitcoinFeeSelection(
        fee: remainder,
        vbytes: _transactionVbytes(
          inputCount: inputCount,
          recipientOutputVbytes: recipientOutputVbytes,
          hasChange: false,
        ),
      );
    }
  }
  throw StateError('Bitcoin balance is insufficient for fee estimate');
}

_BitcoinFeeSelection _estimateSweepFee({
  required List<_BitcoinFeeUtxo> utxos,
  required double satsPerVbyte,
  required int recipientOutputVbytes,
}) {
  if (utxos.isEmpty) {
    throw StateError('Bitcoin balance is insufficient for fee estimate');
  }
  final inputCount = utxos.length;
  return _BitcoinFeeSelection(
    fee: _feeFor(
      satsPerVbyte: satsPerVbyte,
      inputCount: inputCount,
      recipientOutputVbytes: recipientOutputVbytes,
      hasChange: false,
    ),
    vbytes: _transactionVbytes(
      inputCount: inputCount,
      recipientOutputVbytes: recipientOutputVbytes,
      hasChange: false,
    ),
  );
}

BigInt _feeFor({
  required double satsPerVbyte,
  required int inputCount,
  required int recipientOutputVbytes,
  required bool hasChange,
}) {
  final vbytes = _transactionVbytes(
    inputCount: inputCount,
    recipientOutputVbytes: recipientOutputVbytes,
    hasChange: hasChange,
  );
  return BigInt.from(math.max(1, (satsPerVbyte * vbytes).ceil()));
}

int _transactionVbytes({
  required int inputCount,
  required int recipientOutputVbytes,
  required bool hasChange,
}) {
  return _p2wpkhBaseVbytes +
      (inputCount * _p2wpkhInputVbytes) +
      recipientOutputVbytes +
      (hasChange ? _p2wpkhOutputVbytes : 0);
}

int _outputVbytes(List<int> scriptPubKey) {
  return 8 + _compactSizeVbytes(scriptPubKey.length) + scriptPubKey.length;
}

int _compactSizeVbytes(int value) {
  if (value < 0xfd) {
    return 1;
  }
  if (value <= 0xffff) {
    return 3;
  }
  if (value <= 0xffffffff) {
    return 5;
  }
  return 9;
}

const _p2wpkhBaseVbytes = 11;
const _p2wpkhInputVbytes = 68;
const _p2wpkhOutputVbytes = 31;
final _dustSatoshis = BigInt.from(546);

final class _BitcoinFeeRates {
  const _BitcoinFeeRates({
    required this.rates,
    required this.confirmationBlocks,
  });

  final List<double> rates;
  final List<int> confirmationBlocks;
}

_BitcoinFeeRates _feeRates(Map<String, dynamic> feeEstimates) {
  final entries =
      feeEstimates.entries
          .map((entry) => MapEntry(int.tryParse(entry.key), entry.value))
          .where((entry) => entry.key != null && entry.value is num)
          .map((entry) => MapEntry(entry.key!, (entry.value as num).toDouble()))
          .where((entry) => entry.value > 0 && entry.value.isFinite)
          .toList()
        ..sort((left, right) => left.key.compareTo(right.key));
  if (entries.isEmpty) {
    throw StateError('Bitcoin fee estimate response has no usable fee rate');
  }
  final fastEntry = entries.first;
  final economyEntry = entries.last;
  final standardEntry = entries.reduce((best, candidate) {
    return (candidate.key - 3).abs() < (best.key - 3).abs() ? candidate : best;
  });
  final fast = fastEntry.value;
  final economy = economyEntry.value;
  final standard = standardEntry.value;
  final low = math.min(economy, math.min(standard, fast));
  final high = math.max(economy, math.max(standard, fast));
  final middle = standard.clamp(low, high).toDouble();
  return _BitcoinFeeRates(
    rates: [low, middle, high],
    confirmationBlocks: [economyEntry.key, standardEntry.key, fastEntry.key],
  );
}

Uri _endpoint(String apiBaseUrl, String path) {
  final base = Uri.parse(apiBaseUrl);
  final normalizedBasePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(path: '$normalizedBasePath$path');
}
