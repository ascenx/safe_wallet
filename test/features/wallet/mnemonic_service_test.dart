import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/wallet/data/mnemonic_service.dart';

void main() {
  group('MnemonicService', () {
    const service = MnemonicService();
    const validMnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const invalidMnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon';

    test('generates a 12 word English mnemonic by default', () {
      final mnemonic = service.generateMnemonic();

      expect(mnemonic.split(' '), hasLength(12));
      expect(service.isValidMnemonic(mnemonic), isTrue);
    });

    test('validates BIP39 checksum on import', () {
      expect(service.isValidMnemonic(validMnemonic), isTrue);
      expect(service.isValidMnemonic(invalidMnemonic), isFalse);
      expect(() => service.parseMnemonic(invalidMnemonic), throwsArgumentError);
    });
  });
}
