import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/errors/rpc_error.dart';
import '../../../shared/network/bounded_http_client.dart';
import '../domain/tron_staking_models.dart';

typedef TronStakingClock = DateTime Function();

abstract interface class TronStakingRepository {
  Future<TronStakingOverview> loadOverview({
    required String apiBaseUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  });

  Future<List<TronDelegation>> loadDelegations({
    required String apiBaseUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  });

  Future<List<TronWitness>> loadWitnesses({
    required String apiBaseUrl,
    Map<String, String> headers = const {},
  });

  Future<BigInt> getMaxDelegatableSun({
    required String apiBaseUrl,
    required String walletAddress,
    required TronResourceType resource,
    Map<String, String> headers = const {},
  });
}

final class HttpTronStakingRepository implements TronStakingRepository {
  HttpTronStakingRepository({http.Client? client, TronStakingClock? clock})
    : _client = client ?? BoundedHttpClient(),
      _clock = clock ?? (() => DateTime.now().toUtc());

  final http.Client _client;
  final TronStakingClock _clock;

  @override
  Future<TronStakingOverview> loadOverview({
    required String apiBaseUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    final account = await _post(apiBaseUrl, '/wallet/getaccount', {
      'address': walletAddress,
      'visible': true,
    }, headers);
    final resources = await _post(apiBaseUrl, '/wallet/getaccountresource', {
      'address': walletAddress,
      'visible': true,
    }, headers);
    final parameters = await _post(
      apiBaseUrl,
      '/wallet/getchainparameters',
      const {},
      headers,
    );
    final availableUnfreeze = await _post(
      apiBaseUrl,
      '/wallet/getavailableunfreezecount',
      {'owner_address': walletAddress, 'visible': true},
      headers,
    );
    final withdrawable =
        await _post(apiBaseUrl, '/wallet/getcanwithdrawunfreezeamount', {
          'owner_address': walletAddress,
          'timestamp': _clock().millisecondsSinceEpoch,
          'visible': true,
        }, headers);
    final reward = await _post(apiBaseUrl, '/wallet/getReward', {
      'address': walletAddress,
      'visible': true,
    }, headers);

    final frozen = _objects(account['frozenV2']);
    final bandwidthStaked = _sumFrozen(frozen, TronResourceType.bandwidth);
    final energyStaked = _sumFrozen(frozen, TronResourceType.energy);
    final fallbackTronPowerSun = frozen.fold<BigInt>(
      BigInt.zero,
      (total, item) => total + _bigInt(item['amount']),
    );
    final resourceTronPowerSun = _bigInt(resources['tronPowerLimit']);
    final tronPowerSun = resourceTronPowerSun > BigInt.zero
        ? resourceTronPowerSun
        : fallbackTronPowerSun;
    final freeNetLimit = _int(resources['freeNetLimit']);
    final netLimit = _int(resources['NetLimit']);
    final freeNetUsed = _int(resources['freeNetUsed']);
    final netUsed = _int(resources['NetUsed']);
    final chainParameters = _chainParameters(parameters);

    return TronStakingOverview(
      availableBalanceSun: _bigInt(account['balance']),
      bandwidthStakedSun: bandwidthStaked,
      energyStakedSun: energyStaked,
      bandwidthLimit: freeNetLimit + netLimit,
      bandwidthUsed: freeNetUsed + netUsed,
      energyLimit: _int(resources['EnergyLimit']),
      energyUsed: _int(resources['EnergyUsed']),
      tronPower: (tronPowerSun ~/ BigInt.from(1000000)).toInt(),
      votes: _parseVotes(account['votes']),
      pendingUnfreezes: _parsePendingUnfreezes(account['unfrozenV2']),
      availableUnfreezeCount: _int(availableUnfreeze['count']),
      withdrawableSun: _bigInt(withdrawable['amount']),
      rewardSun: _bigInt(reward['reward']),
      unfreezeDelayDays: chainParameters['getUnfreezeDelayDays'] ?? 0,
      cancelAllUnfreezeSupported:
          chainParameters['getAllowCancelAllUnfreezeV2'] == 1,
      delegateResourceSupported:
          chainParameters['getAllowDelegateResource'] == 1,
      maxDelegateLockPeriod: chainParameters['getMaxDelegateLockPeriod'] ?? 0,
    );
  }

  @override
  Future<List<TronDelegation>> loadDelegations({
    required String apiBaseUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    final index = await _post(
      apiBaseUrl,
      '/wallet/getdelegatedresourceaccountindexv2',
      {'value': walletAddress, 'visible': true},
      headers,
    );
    final result = <TronDelegation>[];
    for (final address in _strings(index['toAccounts'])) {
      result.addAll(
        await _loadDelegationPair(
          apiBaseUrl: apiBaseUrl,
          fromAddress: walletAddress,
          toAddress: address,
          direction: TronDelegationDirection.outgoing,
          counterpartyAddress: address,
          headers: headers,
        ),
      );
    }
    for (final address in _strings(index['fromAccounts'])) {
      result.addAll(
        await _loadDelegationPair(
          apiBaseUrl: apiBaseUrl,
          fromAddress: address,
          toAddress: walletAddress,
          direction: TronDelegationDirection.incoming,
          counterpartyAddress: address,
          headers: headers,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  Future<List<TronDelegation>> _loadDelegationPair({
    required String apiBaseUrl,
    required String fromAddress,
    required String toAddress,
    required TronDelegationDirection direction,
    required String counterpartyAddress,
    required Map<String, String> headers,
  }) async {
    final response = await _post(apiBaseUrl, '/wallet/getdelegatedresourcev2', {
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'visible': true,
    }, headers);
    return _objects(response['delegatedResource'])
        .map(
          (item) => TronDelegation(
            direction: direction,
            counterpartyAddress: counterpartyAddress,
            bandwidthSun: _bigInt(item['frozen_balance_for_bandwidth']),
            energySun: _bigInt(item['frozen_balance_for_energy']),
            bandwidthExpiresAt: _dateTime(item['expire_time_for_bandwidth']),
            energyExpiresAt: _dateTime(item['expire_time_for_energy']),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<TronWitness>> loadWitnesses({
    required String apiBaseUrl,
    Map<String, String> headers = const {},
  }) async {
    final response = await _post(
      apiBaseUrl,
      '/wallet/listwitnesses',
      const {},
      headers,
    );
    return _objects(response['witnesses'])
        .map(
          (item) => TronWitness(
            address: _string(item['address']),
            voteCount: _int(item['voteCount'] ?? item['vote_count']),
            url: _string(item['url']),
            isActive: item['isJobs'] == true || item['is_jobs'] == true,
          ),
        )
        .where((witness) => witness.address.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<BigInt> getMaxDelegatableSun({
    required String apiBaseUrl,
    required String walletAddress,
    required TronResourceType resource,
    Map<String, String> headers = const {},
  }) async {
    final response = await _post(apiBaseUrl, '/wallet/getcandelegatedmaxsize', {
      'owner_address': walletAddress,
      'type': resource.apiCode,
      'visible': true,
    }, headers);
    return _bigInt(response['max_size']);
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
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const RpcError.invalidCredential();
    }
    if (response.statusCode == 429) {
      throw const RpcError.rateLimited();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RpcError.unavailable(
        debugMessage: 'Tron staking API returned HTTP ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const RpcError.unavailable(
        debugMessage: 'Tron staking API response is invalid',
      );
    }
    return decoded;
  }

  void close() => _client.close();
}

BigInt _sumFrozen(
  List<Map<String, Object?>> frozen,
  TronResourceType resource,
) {
  return frozen.fold(BigInt.zero, (total, item) {
    final type = item['type'];
    final parsed = type == null
        ? TronResourceType.bandwidth
        : _tryResourceType(type);
    return parsed == resource ? total + _bigInt(item['amount']) : total;
  });
}

TronResourceType? _tryResourceType(Object? value) {
  try {
    return TronResourceType.fromApiValue(value);
  } on FormatException {
    return null;
  }
}

List<TronVote> _parseVotes(Object? value) {
  return _objects(value)
      .map(
        (item) => TronVote(
          witnessAddress: _string(item['vote_address'] ?? item['voteAddress']),
          voteCount: _int(item['vote_count'] ?? item['voteCount']),
        ),
      )
      .where((vote) => vote.witnessAddress.isNotEmpty && vote.voteCount > 0)
      .toList(growable: false);
}

List<TronPendingUnfreeze> _parsePendingUnfreezes(Object? value) {
  final result = <TronPendingUnfreeze>[];
  for (final item in _objects(value)) {
    final resource = _tryResourceType(item['type']);
    final amount = _bigInt(item['unfreeze_amount'] ?? item['unfreezeAmount']);
    final expiresAt = _dateTime(
      item['unfreeze_expire_time'] ?? item['unfreezeExpireTime'],
    );
    if (resource != null && amount > BigInt.zero && expiresAt != null) {
      result.add(
        TronPendingUnfreeze(
          resource: resource,
          amountSun: amount,
          expiresAt: expiresAt,
        ),
      );
    }
  }
  return result;
}

Map<String, int> _chainParameters(Map<String, Object?> response) {
  return {
    for (final item in _objects(response['chainParameter']))
      if (_string(item['key']).isNotEmpty)
        _string(item['key']): _int(item['value']),
  };
}

List<Map<String, Object?>> _objects(Object? value) {
  if (value is! List<Object?>) {
    return const [];
  }
  return value.whereType<Map<String, Object?>>().toList(growable: false);
}

List<String> _strings(Object? value) {
  if (value is! List<Object?>) {
    return const [];
  }
  return value.whereType<String>().where((item) => item.isNotEmpty).toList();
}

String _string(Object? value) => value is String ? value : '';

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return value is String ? int.tryParse(value) ?? 0 : 0;
}

BigInt _bigInt(Object? value) {
  if (value is int) {
    return BigInt.from(value);
  }
  if (value is num) {
    return BigInt.from(value);
  }
  return value is String ? BigInt.tryParse(value) ?? BigInt.zero : BigInt.zero;
}

DateTime? _dateTime(Object? value) {
  final milliseconds = _int(value);
  return milliseconds > 0
      ? DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true)
      : null;
}

Uri _endpoint(String apiBaseUrl, String path) {
  final base = Uri.tryParse(apiBaseUrl);
  if (base == null ||
      !base.hasAuthority ||
      (base.scheme != 'https' && base.scheme != 'http')) {
    throw const RpcError.invalidUrl();
  }
  final normalizedBasePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(path: '$normalizedBasePath$path');
}
