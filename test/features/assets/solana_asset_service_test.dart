import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/assets/data/solana_asset_service.dart';

void main() {
  group('HttpSolanaAssetService', () {
    test('loads token balances from SPL Token and Token-2022 programs',
        () async {
      final requestedProgramIds = <String>[];
      final service = HttpSolanaAssetService(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final params = body['params'] as List<dynamic>;
          final filter = params[1] as Map<String, dynamic>;
          final programId = filter['programId'] as String;
          requestedProgramIds.add(programId);

          if (programId == splTokenProgramId) {
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': 1,
                'result': {
                  'value': [
                    _tokenAccountJson(
                      mintAddress: 'legacy-mint',
                      rawBalance: '12',
                      decimals: 0,
                      programId: splTokenProgramId,
                    ),
                  ],
                },
              }),
              200,
            );
          }

          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': 1,
              'result': {
                'value': [
                  _tokenAccountJson(
                    mintAddress: 'token-2022-mint',
                    rawBalance: '45942024',
                    decimals: 6,
                    programId: token2022ProgramId,
                  ),
                ],
              },
            }),
            200,
          );
        }),
      );

      final balances = await service.getTokenBalancesByOwner(
        rpcUrl: 'https://rpc.example.com',
        ownerAddress: 'CVa9m626gRHdPRPdfSibiJ9FkB4L9pouFqLBvDfGLdXa',
      );

      expect(requestedProgramIds, [splTokenProgramId, token2022ProgramId]);
      expect(
        balances.map((balance) => balance.mintAddress),
        ['legacy-mint', 'token-2022-mint'],
      );
      expect(
        balances.map((balance) => balance.rawBalance),
        [BigInt.from(12), BigInt.from(45942024)],
      );
    });

    test(
        'falls back to getProgramAccounts when SPL owner query is rate limited',
        () async {
      final requestedMethods = <String>[];
      final service = HttpSolanaAssetService(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final method = body['method'] as String;
          requestedMethods.add(method);

          if (method == 'getTokenAccountsByOwner') {
            final params = body['params'] as List<dynamic>;
            final filter = params[1] as Map<String, dynamic>;
            if (filter['programId'] == splTokenProgramId) {
              return http.Response(
                jsonEncode({
                  'jsonrpc': '2.0',
                  'id': 1,
                  'error': {
                    'code': 429,
                    'message': 'Too many requests for a specific RPC call',
                  },
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': 1,
                'result': {'value': []},
              }),
              200,
            );
          }

          return http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': 1,
              'result': [
                _tokenAccountJson(
                  mintAddress: '9raUVuzeWUk53co63M4WXLWPWE4Xc6Lpn7RS9dnkpump',
                  rawBalance: '168801913',
                  decimals: 6,
                  programId: splTokenProgramId,
                ),
              ],
            }),
            200,
          );
        }),
      );

      final balances = await service.getTokenBalancesByOwner(
        rpcUrl: 'https://rpc.example.com',
        ownerAddress: 'CVa9m626gRHdPRPdfSibiJ9FkB4L9pouFqLBvDfGLdXa',
      );

      expect(requestedMethods, [
        'getTokenAccountsByOwner',
        'getProgramAccounts',
        'getTokenAccountsByOwner',
      ]);
      expect(balances.single.mintAddress,
          '9raUVuzeWUk53co63M4WXLWPWE4Xc6Lpn7RS9dnkpump');
      expect(balances.single.rawBalance, BigInt.from(168801913));
    });
  });
}

Map<String, Object?> _tokenAccountJson({
  required String mintAddress,
  required String rawBalance,
  required int decimals,
  required String programId,
}) {
  return {
    'account': {
      'owner': programId,
      'data': {
        'parsed': {
          'info': {
            'mint': mintAddress,
            'tokenAmount': {
              'amount': rawBalance,
              'decimals': decimals,
            },
          },
        },
      },
    },
  };
}
