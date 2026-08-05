import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/shared/utils/receive_qr_payload.dart';

void main() {
  test('Solana receive QR stays as a raw address unless amount is set', () {
    const address = '11111111111111111111111111111111';

    expect(
      receiveQrPayloadForChain(
        chainType: ChainType.solana,
        address: address,
      ),
      address,
    );

    final payload = receiveQrPayloadForChain(
      chainType: ChainType.solana,
      address: address,
      amount: '8.5',
    );

    expect(payload, startsWith('solana:$address?'));
    expect(Uri.parse(payload).queryParameters['amount'], '8.5');
  });

  test('Bitcoin receive QR stays raw unless amount is set', () {
    const address = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';

    expect(
      receiveQrPayloadForChain(
        chainType: ChainType.bitcoin,
        address: address,
      ),
      address,
    );

    final payload = receiveQrPayloadForChain(
      chainType: ChainType.bitcoin,
      address: address,
      amount: '0.001',
    );

    expect(payload, startsWith('bitcoin:$address?'));
    expect(Uri.parse(payload).queryParameters['amount'], '0.001');
  });

  test('Sui receive QR uses the raw normalized address', () {
    const address =
        '0xa2d14fad60c56049ecf75246a481934691214ce413e6a8ae2fe6834c173a6133';

    expect(
      receiveQrPayloadForChain(
        chainType: ChainType.sui,
        address: address,
        amount: '1.5',
      ),
      address,
    );
  });
}
