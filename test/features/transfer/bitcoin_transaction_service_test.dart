import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/transfer/application/fee_estimate_provider.dart';
import 'package:safe_wallet/features/transfer/data/bitcoin_transaction_service.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_request.dart';
import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart' as web3;

void main() {
  group('HttpBitcoinTransactionService', () {
    test('builds a P2WPKH transaction and broadcasts it to the API', () async {
      final requests = <http.Request>[];
      String? rawTransaction;
      final service = HttpBitcoinTransactionService(
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET' &&
              request.url.path == '/api/address/$_fromAddress/utxo') {
            return http.Response('''
              [
                {
                  "txid": "$_previousTxid",
                  "vout": 1,
                  "value": 10010000,
                  "status": {"confirmed": true}
                }
              ]
              ''', 200);
          }
          if (request.method == 'POST' && request.url.path == '/api/tx') {
            rawTransaction = request.body;
            return http.Response('btctxid', 200);
          }
          return http.Response('not found', 404);
        }),
      );

      final txid = await service.signAndBroadcast(_input());

      expect(txid, 'btctxid');
      expect(requests.map((request) => request.method), ['GET', 'POST']);
      expect(
        requests.first.url.toString(),
        'https://blockstream.info/api/address/$_fromAddress/utxo',
      );
      expect(requests.last.url.toString(), 'https://blockstream.info/api/tx');
      expect(requests.last.headers['content-type'], 'text/plain');
      expect(rawTransaction, isNotNull);
      expect(rawTransaction, startsWith('020000000001'));
      expect(rawTransaction, contains(_recipientScriptPubKey));
      expect(rawTransaction, contains(_changeScriptPubKey));
      expect(rawTransaction, _expectedSignedRawTransaction);
    });

    test('does not broadcast when UTXOs cannot cover amount and fee', () async {
      final requests = <http.Request>[];
      final service = HttpBitcoinTransactionService(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('''
            [
              {
                "txid": "$_previousTxid",
                "vout": 0,
                "value": 999,
                "status": {"confirmed": true}
              }
            ]
            ''', 200);
        }),
      );

      await expectLater(
        service.signAndBroadcast(_input()),
        throwsA(isA<StateError>()),
      );

      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
    });

    test(
      'reselects UTXOs for a custom fee rate as input vbytes grow',
      () async {
        String? rawTransaction;
        final service = HttpBitcoinTransactionService(
          client: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response('''
              [
                {"txid": "$_previousTxid", "vout": 0, "value": 10001000},
                {"txid": "$_secondPreviousTxid", "vout": 1, "value": 700},
                {"txid": "$_thirdPreviousTxid", "vout": 2, "value": 2000}
              ]
              ''', 200);
            }
            rawTransaction = request.body;
            return http.Response('btctxid', 200);
          }),
        );
        final customFee = FeeEstimate.bitcoin(
          feeAssetSymbol: 'BTC',
          satoshis: BigInt.from(1410),
          satsPerVbyte: 10,
          transactionVbytes: 141,
        );

        await service.signAndBroadcast(_input(feeEstimate: customFee));

        expect(rawTransaction, isNotNull);
        expect(rawTransaction!.substring(12, 14), '03');
        expect(rawTransaction, contains(_changeScriptPubKey));
      },
    );

    test('sweep spends every UTXO without creating change', () async {
      String? rawTransaction;
      final service = HttpBitcoinTransactionService(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response('''
              [
                {"txid": "$_previousTxid", "vout": 0, "value": 6000000},
                {"txid": "$_secondPreviousTxid", "vout": 1, "value": 5000000}
              ]
              ''', 200);
          }
          rawTransaction = request.body;
          return http.Response('btctxid', 200);
        }),
      );
      final sweepFee = FeeEstimate.bitcoin(
        feeAssetSymbol: 'BTC',
        satoshis: BigInt.from(1780),
        satsPerVbyte: 10,
        transactionVbytes: 178,
      );

      await service.signAndBroadcast(
        _input(
          amount: '0.1099822',
          amountInBaseUnits: '10998220',
          feeEstimate: sweepFee,
        ),
      );

      expect(rawTransaction, isNotNull);
      expect(rawTransaction!.substring(12, 14), '02');
      expect(rawTransaction, contains(_recipientScriptPubKey));
      expect(rawTransaction, isNot(contains(_changeScriptPubKey)));
    });

    test('builds an output for a legacy P2PKH recipient address', () async {
      String? rawTransaction;
      final service = HttpBitcoinTransactionService(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response('''
              [
                {
                  "txid": "$_previousTxid",
                  "vout": 1,
                  "value": 10010000,
                  "status": {"confirmed": true}
                }
              ]
              ''', 200);
          }
          rawTransaction = request.body;
          return http.Response('btctxid', 200);
        }),
      );

      final txid = await service.signAndBroadcast(
        _input(toAddress: _legacyRecipientAddress),
      );

      expect(txid, 'btctxid');
      expect(rawTransaction, contains(_legacyRecipientScriptPubKey));
    });

    test('builds an output for a Taproot recipient address', () async {
      String? rawTransaction;
      final service = HttpBitcoinTransactionService(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response('''
              [
                {
                  "txid": "$_previousTxid",
                  "vout": 1,
                  "value": 10010000,
                  "status": {"confirmed": true}
                }
              ]
              ''', 200);
          }
          rawTransaction = request.body;
          return http.Response('btctxid', 200);
        }),
      );

      final txid = await service.signAndBroadcast(
        _input(toAddress: _taprootRecipientAddress),
      );

      expect(txid, 'btctxid');
      expect(rawTransaction, contains(_taprootRecipientScriptPubKey));
    });

    test('accepts compressed testnet WIF private keys', () async {
      String? rawTransaction;
      final service = HttpBitcoinTransactionService(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response('''
              [
                {
                  "txid": "$_previousTxid",
                  "vout": 1,
                  "value": 10010000,
                  "status": {"confirmed": true}
                }
              ]
              ''', 200);
          }
          rawTransaction = request.body;
          return http.Response('btctxid', 200);
        }),
      );

      final txid = await service.signAndBroadcast(
        _input(privateKey: _compressedTestnetWif),
      );

      expect(txid, 'btctxid');
      expect(rawTransaction, _expectedSignedRawTransaction);
    });
  });
}

BitcoinTransactionBroadcastInput _input({
  String privateKey = _privateKey,
  String toAddress = _recipientAddress,
  String amount = '0.1',
  String amountInBaseUnits = '10000000',
  FeeEstimate? feeEstimate,
}) {
  return BitcoinTransactionBroadcastInput(
    apiBaseUrl: 'https://blockstream.info/api',
    privateKey: privateKey,
    fromAddress: _fromAddress,
    transaction: TransactionRequest(
      chainId: 'bitcoin-mainnet',
      chainType: ChainType.bitcoin,
      assetSymbol: 'BTC',
      toAddress: toAddress,
      amount: amount,
      amountInBaseUnits: amountInBaseUnits,
      tokenDecimals: 8,
      transactionType: TransactionType.bitcoinTransfer,
    ),
    feeEstimate:
        feeEstimate ??
        FeeEstimate.bitcoin(feeAssetSymbol: 'BTC', satoshis: BigInt.from(1000)),
  );
}

String _addressForPrivateKey(String privateKey) {
  final key = wallet.PrivateKey(
    web3.bytesToUnsignedInt(web3.hexToBytes(privateKey)),
  );
  return wallet.bitcoinbech32.createAddress(
    wallet.bitcoinbech32.createPublicKey(key),
  );
}

String _scriptPubKey(String address) {
  return wallet.segwit.decode(address).scriptPubKey;
}

const _privateKey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _compressedTestnetWif =
    'cN9spWsvaxA8taS7DFMxnk1yJD2gaF2PX1npuTpy3vuZFJdwavaw';
final _fromAddress = _addressForPrivateKey(_privateKey);
const _recipientAddress = 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';
final _recipientScriptPubKey = _scriptPubKey(_recipientAddress);
final _changeScriptPubKey = _scriptPubKey(_fromAddress);
const _legacyRecipientAddress = '1BoatSLRHtKNngkdXEeobR76b53LETtpyT';
const _legacyRecipientScriptPubKey =
    '76a9147680adec8eabcabac676be9e83854ade0bd22cdb88ac';
const _taprootRecipientAddress =
    'bc1ph4lmxwklchcvvh2wchzassw86yvahdt902mpe0velxzuz2c70sps70mzj4';
const _taprootRecipientScriptPubKey =
    '5120bd7fb33adfc5f0c65d4ec5c5d841c7d119dbb5657ab61cbd99f985c12b1e7c03';
const _previousTxid =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _secondPreviousTxid =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _thirdPreviousTxid =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _expectedSignedRawTransaction =
    '02000000000101aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    '0100000000ffffffff028096980000000000160014311564348890e005880a9bc834aa'
    'a5884f1b59322823000000000000160014fc7250a211deddc70ee5a2738de5f0781735'
    '1cef024730440220595fcd8f41961c9931fdd56c8e4146f0e2a8c5df3375b97c8e4'
    'b0b947c90f4090220775974a114a7136ccfcb0ee39c53e886f70cc8bfb206030719b'
    'c24a5835eaa220121034f355bdcb7cc0af728ef3cceb9615d90684bb5b2ca5f859a'
    'b0f0b704075871aa00000000';
