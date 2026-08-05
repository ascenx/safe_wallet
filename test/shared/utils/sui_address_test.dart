import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/shared/utils/sui_address.dart';

void main() {
  test('normalizes short and uppercase Sui addresses to 32-byte lowercase', () {
    expect(
      normalizeSuiAddressInput(' 0X2 '),
      '0x0000000000000000000000000000000000000000000000000000000000000002',
    );
    expect(
      normalizeSuiAddressInput(
        'A2D14FAD60C56049ECF75246A481934691214CE413E6A8AE2FE6834C173A6133',
      ),
      '0xa2d14fad60c56049ecf75246a481934691214ce413e6a8ae2fe6834c173a6133',
    );
  });

  test('rejects empty, non-hex, and overlong Sui addresses', () {
    expect(normalizeSuiAddressInput(''), isNull);
    expect(normalizeSuiAddressInput('0xgg'), isNull);
    expect(normalizeSuiAddressInput('0x${'1'.padLeft(65, '1')}'), isNull);
  });
}
