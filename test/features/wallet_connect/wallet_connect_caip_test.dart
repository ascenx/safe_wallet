import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_caip.dart';

void main() {
  group('Caip2ChainId', () {
    test('parses and formats EVM and Solana identifiers', () {
      expect(
        Caip2ChainId.parse('eip155:56'),
        const Caip2ChainId(namespace: 'eip155', reference: '56'),
      );
      expect(
        Caip2ChainId.parse(
          'solana:4sGjMW1sUnHzSxGspuhpqLDx6wiyjNtZ',
        ).toString(),
        'solana:4sGjMW1sUnHzSxGspuhpqLDx6wiyjNtZ',
      );
    });

    test('rejects malformed identifiers', () {
      for (final value in ['', 'eip155', 'eip155:', ':1', 'EIP155:1:2']) {
        expect(
          () => Caip2ChainId.parse(value),
          throwsA(isA<FormatException>()),
          reason: value,
        );
      }
    });
  });

  group('Caip10AccountId', () {
    test('round trips an EVM account', () {
      const value = 'eip155:1:0x9659B6Ed9FAFfa7f3f04E3B0aD5EeE214162acfc';
      final account = Caip10AccountId.parse(value);

      expect(
        account.chain,
        const Caip2ChainId(namespace: 'eip155', reference: '1'),
      );
      expect(account.address, '0x9659B6Ed9FAFfa7f3f04E3B0aD5EeE214162acfc');
      expect(account.toString(), value);
    });

    test('matches EVM addresses case-insensitively only on the same chain', () {
      final account = Caip10AccountId.parse(
        'eip155:56:0x9659B6Ed9FAFfa7f3f04E3B0aD5EeE214162acfc',
      );

      expect(
        account.matches(
          chain: const Caip2ChainId(namespace: 'eip155', reference: '56'),
          address: '0x9659b6ed9faffa7f3f04e3b0ad5eee214162acfc',
        ),
        isTrue,
      );
      expect(
        account.matches(
          chain: const Caip2ChainId(namespace: 'eip155', reference: '1'),
          address: account.address,
        ),
        isFalse,
      );
    });

    test('keeps non-EVM address matching case-sensitive', () {
      final account = Caip10AccountId.parse('solana:mainnet:AbCd');

      expect(
        account.matches(
          chain: const Caip2ChainId(namespace: 'solana', reference: 'mainnet'),
          address: 'abcd',
        ),
        isFalse,
      );
    });

    test('rejects malformed account identifiers', () {
      for (final value in ['', 'eip155:1', 'eip155:1:', ':1:0x1']) {
        expect(
          () => Caip10AccountId.parse(value),
          throwsA(isA<FormatException>()),
          reason: value,
        );
      }
    });
  });
}
