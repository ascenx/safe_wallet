import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/wallet/data/key_derivation_service.dart';
import 'package:safe_wallet/features/wallet/data/mnemonic_service.dart';

void main() {
  group('KeyDerivationService', () {
    const mnemonicService = MnemonicService();
    const derivationService = KeyDerivationService();
    const mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

    test('derives the expected default EVM account', () {
      final parsed = mnemonicService.parseMnemonic(mnemonic);

      final account = derivationService.deriveEvmAccount(parsed);

      expect(account.derivationPath, "m/44'/60'/0'/0/0");
      expect(
        account.address.toLowerCase(),
        '0x9858effd232b4033e47d90003d41ec34ecaeda94',
      );
      expect(account.privateKey, hasLength(32));
    });

    test('derives deterministic EVM account indexes', () {
      final parsed = mnemonicService.parseMnemonic(mnemonic);

      final first = derivationService.deriveEvmAccount(parsed);
      final firstAgain = derivationService.deriveEvmAccount(parsed);
      final second = derivationService.deriveEvmAccount(parsed, index: 1);

      expect(first, firstAgain);
      expect(second.derivationPath, "m/44'/60'/0'/0/1");
      expect(second.address, isNot(first.address));
    });

    test('derives deterministic Solana default account', () {
      final parsed = mnemonicService.parseMnemonic(mnemonic);

      final first = derivationService.deriveSolanaAccount(parsed);
      final second = derivationService.deriveSolanaAccount(parsed);

      expect(first, second);
      expect(first.derivationPath, "m/44'/501'/0'/0'");
      expect(first.address, isNotEmpty);
      expect(first.privateKey, hasLength(64));
    });

    test('derives the expected default Bitcoin BIP84 account', () {
      final parsed = mnemonicService.parseMnemonic(mnemonic);

      final account = derivationService.deriveBitcoinAccount(parsed);

      expect(account.derivationPath, "m/84'/0'/0'/0/0");
      expect(account.address, 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu');
      expect(account.privateKey, hasLength(32));
    });

    test('derives the expected default Tron BIP44 account', () {
      const tronMnemonic =
          'into feed allow salt consider rebuild agree light lizard word foil bar';
      final parsed = mnemonicService.parseMnemonic(tronMnemonic);

      final account = derivationService.deriveTronAccount(parsed);

      expect(account.derivationPath, "m/44'/195'/0'/0/0");
      expect(account.address, 'TNFRxT9A4Nx2wDU69keYpLcE8TCSyFztgi');
      expect(account.privateKey, hasLength(32));
    });

    test('derives the Mysten keytool Ed25519 Sui account vector', () {
      const suiMnemonic =
          'film crazy soon outside stand loop subway crumble thrive popular '
          'green nuclear struggle pistol arm wife phrase warfare march wheat '
          'nephew ask sunny firm';
      final parsed = mnemonicService.parseMnemonic(suiMnemonic);

      final account = derivationService.deriveSuiAccount(parsed);

      expect(account.derivationPath, "m/44'/784'/0'/0'/0'");
      expect(
        account.address,
        '0xa2d14fad60c56049ecf75246a481934691214ce413e6a8ae2fe6834c173a6133',
      );
      expect(account.privateKey, hasLength(32));
    });
  });
}
