import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/staking/data/tron_staking_repository.dart';
import 'package:safe_wallet/features/staking/domain/tron_staking_models.dart';
import 'package:safe_wallet/shared/errors/rpc_error.dart';

void main() {
  group('HttpTronStakingRepository', () {
    test(
      'loads a complete Stake 2.0 overview with dynamic chain parameters',
      () async {
        final requests = <http.Request>[];
        final repository = HttpTronStakingRepository(
          client: MockClient((request) async {
            requests.add(request);
            expect(request.headers['TRON-PRO-API-KEY'], 'test-key');
            return switch (request.url.path) {
              '/wallet/getaccount' => _json({
                'balance': '20000000',
                'frozenV2': [
                  {'type': 'BANDWIDTH', 'amount': 5000000},
                  {'type': 'ENERGY', 'amount': '7000000'},
                  {'type': 'TRON_POWER', 'amount': 1000000},
                ],
                'unfrozenV2': [
                  {
                    'type': 'BANDWIDTH',
                    'unfreeze_amount': 2000000,
                    'unfreeze_expire_time': 1786838400000,
                  },
                ],
                'votes': [
                  {'vote_address': _witness, 'vote_count': 4},
                ],
              }),
              '/wallet/getaccountresource' => _json({
                'freeNetLimit': 600,
                'freeNetUsed': 100,
                'NetLimit': 5000,
                'NetUsed': 1200,
                'EnergyLimit': 9000,
                'EnergyUsed': 2500,
                'tronPowerLimit': 13000000,
              }),
              '/wallet/getchainparameters' => _json({
                'chainParameter': [
                  {'key': 'getUnfreezeDelayDays', 'value': 14},
                  {'key': 'getAllowDelegateResource', 'value': 1},
                  {'key': 'getAllowCancelAllUnfreezeV2', 'value': 1},
                  {'key': 'getMaxDelegateLockPeriod', 'value': 864000},
                ],
              }),
              '/wallet/getavailableunfreezecount' => _json({'count': 31}),
              '/wallet/getcanwithdrawunfreezeamount' => _json({
                'amount': '500000',
              }),
              '/wallet/getReward' => _json({'reward': 250000}),
              _ => http.Response('not found', 404),
            };
          }),
          clock: () => DateTime.utc(2026, 8, 2),
        );

        final result = await repository.loadOverview(
          apiBaseUrl: 'https://api.trongrid.io',
          walletAddress: _owner,
          headers: const {'TRON-PRO-API-KEY': 'test-key'},
        );

        expect(result.availableBalanceSun, BigInt.from(20000000));
        expect(result.bandwidthStakedSun, BigInt.from(5000000));
        expect(result.energyStakedSun, BigInt.from(7000000));
        expect(result.bandwidthLimit, 5600);
        expect(result.bandwidthUsed, 1300);
        expect(result.energyLimit, 9000);
        expect(result.energyUsed, 2500);
        expect(result.tronPower, 13);
        expect(result.usedVotes, 4);
        expect(result.pendingUnfreezes.single.amountSun, BigInt.from(2000000));
        expect(
          result.pendingUnfreezes.single.expiresAt,
          DateTime.fromMillisecondsSinceEpoch(1786838400000, isUtc: true),
        );
        expect(result.availableUnfreezeCount, 31);
        expect(result.withdrawableSun, BigInt.from(500000));
        expect(result.rewardSun, BigInt.from(250000));
        expect(result.unfreezeDelayDays, 14);
        expect(result.delegateResourceSupported, isTrue);
        expect(result.cancelAllUnfreezeSupported, isTrue);
        expect(result.maxDelegateLockPeriod, 864000);
        expect(
          requests.map((request) => request.url.path),
          containsAll(<String>[
            '/wallet/getaccount',
            '/wallet/getaccountresource',
            '/wallet/getchainparameters',
            '/wallet/getavailableunfreezecount',
            '/wallet/getcanwithdrawunfreezeamount',
            '/wallet/getReward',
          ]),
        );
        final withdrawRequest = requests.firstWhere(
          (request) =>
              request.url.path == '/wallet/getcanwithdrawunfreezeamount',
        );
        expect(jsonDecode(withdrawRequest.body), {
          'owner_address': _owner,
          'timestamp': DateTime.utc(2026, 8, 2).millisecondsSinceEpoch,
          'visible': true,
        });
      },
    );

    test('loads incoming outgoing delegations and witness list', () async {
      final repository = HttpTronStakingRepository(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          return switch (request.url.path) {
            '/wallet/getdelegatedresourceaccountindexv2' => _json({
              'account': _owner,
              'fromAccounts': [_sender],
              'toAccounts': [_receiver],
            }),
            '/wallet/getdelegatedresourcev2'
                when body['fromAddress'] == _owner =>
              _json({
                'delegatedResource': [
                  {
                    'from': _owner,
                    'to': _receiver,
                    'frozen_balance_for_bandwidth': 3000000,
                    'expire_time_for_bandwidth': 1786838400000,
                  },
                ],
              }),
            '/wallet/getdelegatedresourcev2' => _json({
              'delegatedResource': [
                {
                  'from': _sender,
                  'to': _owner,
                  'frozen_balance_for_energy': 4000000,
                },
              ],
            }),
            '/wallet/listwitnesses' => _json({
              'witnesses': [
                {
                  'address': _witness,
                  'voteCount': 12345,
                  'url': 'https://sr.example',
                  'isJobs': true,
                },
              ],
            }),
            '/wallet/getcandelegatedmaxsize' => _json({'max_size': 8000000}),
            _ => http.Response('not found', 404),
          };
        }),
      );

      final delegations = await repository.loadDelegations(
        apiBaseUrl: 'https://api.trongrid.io',
        walletAddress: _owner,
      );
      final witnesses = await repository.loadWitnesses(
        apiBaseUrl: 'https://api.trongrid.io',
      );
      final maxDelegatable = await repository.getMaxDelegatableSun(
        apiBaseUrl: 'https://api.trongrid.io',
        walletAddress: _owner,
        resource: TronResourceType.energy,
      );

      expect(delegations, hasLength(2));
      expect(delegations[0].direction, TronDelegationDirection.outgoing);
      expect(delegations[0].counterpartyAddress, _receiver);
      expect(delegations[0].bandwidthSun, BigInt.from(3000000));
      expect(delegations[1].direction, TronDelegationDirection.incoming);
      expect(delegations[1].counterpartyAddress, _sender);
      expect(delegations[1].energySun, BigInt.from(4000000));
      expect(witnesses.single.address, _witness);
      expect(witnesses.single.voteCount, 12345);
      expect(witnesses.single.url, 'https://sr.example');
      expect(witnesses.single.isActive, isTrue);
      expect(maxDelegatable, BigInt.from(8000000));
    });

    test('treats omitted zero fields in an empty account as zero', () async {
      final repository = HttpTronStakingRepository(
        client: MockClient((request) async {
          return switch (request.url.path) {
            '/wallet/getaccount' => _json({
              'frozenV2': [
                <String, Object?>{},
                {'type': 'ENERGY'},
                {'type': 'TRON_POWER'},
              ],
            }),
            '/wallet/getaccountresource' => _json({}),
            '/wallet/getchainparameters' => _json({'chainParameter': []}),
            '/wallet/getavailableunfreezecount' => _json({'count': 32}),
            '/wallet/getcanwithdrawunfreezeamount' => _json({}),
            '/wallet/getReward' => _json({}),
            _ => http.Response('not found', 404),
          };
        }),
      );

      final result = await repository.loadOverview(
        apiBaseUrl: 'https://api.trongrid.io',
        walletAddress: _owner,
      );

      expect(result.availableBalanceSun, BigInt.zero);
      expect(result.bandwidthStakedSun, BigInt.zero);
      expect(result.energyStakedSun, BigInt.zero);
      expect(result.withdrawableSun, BigInt.zero);
      expect(result.rewardSun, BigInt.zero);
    });

    test(
      'maps a TronGrid 429 response to the rate-limited RPC error',
      () async {
        final repository = HttpTronStakingRepository(
          client: MockClient((request) async => http.Response('limited', 429)),
        );

        await expectLater(
          repository.loadOverview(
            apiBaseUrl: 'https://api.trongrid.io',
            walletAddress: _owner,
          ),
          throwsA(
            isA<RpcError>().having(
              (error) => error.code,
              'code',
              'rpc_rate_limited',
            ),
          ),
        );
      },
    );

    for (final statusCode in [401, 403]) {
      test(
        'maps TronGrid $statusCode to the invalid credential RPC error',
        () async {
          final repository = HttpTronStakingRepository(
            client: MockClient(
              (request) async => http.Response('unauthorized', statusCode),
            ),
          );

          await expectLater(
            repository.loadOverview(
              apiBaseUrl: 'https://api.trongrid.io',
              walletAddress: _owner,
            ),
            throwsA(
              isA<RpcError>().having(
                (error) => error.code,
                'code',
                'rpc_invalid_credential',
              ),
            ),
          );
        },
      );
    }
  });
}

http.Response _json(Map<String, Object?> body) =>
    http.Response(jsonEncode(body), 200);

const _owner = 'TJ4uT7n9LQvz1J9jQK5hJkCcnHJfLgkSnj';
const _receiver = 'TNFRxT9A4Nx2wDU69keYpLcE8TCSyFztgi';
const _sender = 'TBXSw8fVY3vQ2rhxQqCiuXj5RYnCcGLBZj';
const _witness = 'TXYQGKy7jQ6VQpJY7Qx9sZ1Ew3FzY9nGxY';
