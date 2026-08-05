import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../../shared/network/bounded_http_client.dart';
import '../domain/tron_staking_action.dart';

final class TronStakingFeeEstimate {
  const TronStakingFeeEstimate({
    required this.burnedSun,
    required this.bandwidth,
    required this.availableBandwidth,
  });

  final BigInt burnedSun;
  final int bandwidth;
  final int availableBandwidth;
}

abstract interface class TronStakingFeeService {
  Future<TronStakingFeeEstimate> estimateFee({
    required String apiBaseUrl,
    required String ownerAddress,
    required TronStakingAction action,
    Map<String, String> headers = const {},
  });
}

final class HttpTronStakingFeeService implements TronStakingFeeService {
  HttpTronStakingFeeService({http.Client? client})
    : _client = client ?? BoundedHttpClient();

  final http.Client _client;

  @override
  Future<TronStakingFeeEstimate> estimateFee({
    required String apiBaseUrl,
    required String ownerAddress,
    required TronStakingAction action,
    Map<String, String> headers = const {},
  }) async {
    final created = await _post(
      apiBaseUrl,
      _endpointFor(action),
      _requestBody(ownerAddress, action),
      headers,
    );
    final transaction = created['transaction'];
    final transactionJson = transaction is Map<String, Object?>
        ? transaction
        : created;
    final rawDataHex = transactionJson['raw_data_hex'];
    if (rawDataHex is! String ||
        rawDataHex.isEmpty ||
        rawDataHex.length.isOdd) {
      throw StateError('Tron staking transaction is missing raw_data_hex');
    }
    final bandwidth = (rawDataHex.length ~/ 2) + 64 + 67 + 3;
    final resources = await _post(apiBaseUrl, '/wallet/getaccountresource', {
      'address': ownerAddress,
      'visible': true,
    }, headers);
    final parameters = await _post(
      apiBaseUrl,
      '/wallet/getchainparameters',
      const {},
      headers,
    );
    final availableBandwidth =
        (math.max(0, _int(resources['NetLimit']) - _int(resources['NetUsed'])) +
                math.max(
                  0,
                  _int(resources['freeNetLimit']) -
                      _int(resources['freeNetUsed']),
                ))
            .toInt();
    final paidBandwidth = math.max(0, bandwidth - availableBandwidth).toInt();
    final unitPrice = _chainParameter(
      parameters,
      'getTransactionFee',
      fallback: 1000,
    );
    return TronStakingFeeEstimate(
      burnedSun: BigInt.from(paidBandwidth) * BigInt.from(unitPrice),
      bandwidth: bandwidth,
      availableBandwidth: availableBandwidth,
    );
  }

  Future<Map<String, Object?>> _post(
    String apiBaseUrl,
    String path,
    Map<String, Object?> body,
    Map<String, String> headers,
  ) async {
    final response = await _client.post(
      _endpoint(apiBaseUrl, path),
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Tron staking fee request failed');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw StateError('Tron staking fee response is invalid');
    }
    return decoded;
  }

  void close() => _client.close();
}

String _endpointFor(TronStakingAction action) => switch (action) {
  TronStakeAction() => '/wallet/freezebalancev2',
  TronUnstakeAction() => '/wallet/unfreezebalancev2',
  TronWithdrawUnfreezeAction() => '/wallet/withdrawexpireunfreeze',
  TronCancelAllUnfreezeAction() => '/wallet/cancelallunfreezev2',
  TronDelegateAction() => '/wallet/delegateresource',
  TronUndelegateAction() => '/wallet/undelegateresource',
  TronVoteAction() => '/wallet/votewitnessaccount',
  TronClaimRewardAction() => '/wallet/withdrawbalance',
};

Map<String, Object?> _requestBody(
  String ownerAddress,
  TronStakingAction action,
) {
  return switch (action) {
    TronStakeAction() => {
      'owner_address': ownerAddress,
      'frozen_balance': action.amountSun.toInt(),
      'resource': action.resource.apiValue,
      'visible': true,
    },
    TronUnstakeAction() => {
      'owner_address': ownerAddress,
      'unfreeze_balance': action.amountSun.toInt(),
      'resource': action.resource.apiValue,
      'visible': true,
    },
    TronWithdrawUnfreezeAction() ||
    TronCancelAllUnfreezeAction() ||
    TronClaimRewardAction() => {'owner_address': ownerAddress, 'visible': true},
    TronDelegateAction() => {
      'owner_address': ownerAddress,
      'receiver_address': action.receiverAddress,
      'balance': action.amountSun.toInt(),
      'resource': action.resource.apiValue,
      'lock': action.lock,
      if (action.lockPeriod != null) 'lock_period': action.lockPeriod,
      'visible': true,
    },
    TronUndelegateAction() => {
      'owner_address': ownerAddress,
      'receiver_address': action.receiverAddress,
      'balance': action.amountSun.toInt(),
      'resource': action.resource.apiValue,
      'visible': true,
    },
    TronVoteAction() => {
      'owner_address': ownerAddress,
      'votes': [
        for (final vote in action.votes)
          {'vote_address': vote.witnessAddress, 'vote_count': vote.voteCount},
      ],
      'visible': true,
    },
  };
}

int _chainParameter(
  Map<String, Object?> response,
  String key, {
  required int fallback,
}) {
  final values = response['chainParameter'];
  if (values is List<Object?>) {
    for (final value in values) {
      if (value is Map<String, Object?> && value['key'] == key) {
        return _int(value['value']);
      }
    }
  }
  return fallback;
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return value is String ? int.tryParse(value) ?? 0 : 0;
}

Uri _endpoint(String apiBaseUrl, String path) {
  final base = Uri.parse(apiBaseUrl);
  final normalizedBasePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(path: '$normalizedBasePath$path');
}
