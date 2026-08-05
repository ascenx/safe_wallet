import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/transfer/data/evm_fee_service.dart';

void main() {
  test('fee history uses median low middle and high reward percentiles', () {
    final priorities = evmPriorityFeesFromHistory({
      'reward': [
        [BigInt.one, BigInt.two, BigInt.from(3)],
        [BigInt.two, BigInt.from(4), BigInt.from(8)],
        [BigInt.from(3), BigInt.from(6), BigInt.from(12)],
      ],
    });

    expect(
      priorities,
      [BigInt.two, BigInt.from(4), BigInt.from(8)],
    );
  });
}
