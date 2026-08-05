import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/shared/security/address_poisoning_detector.dart';

void main() {
  test('detects a recipient that mimics a historical address', () {
    final result = detectAddressRisk(
      recipient: '0x123456aaaaaaaaaaaaaaaaaaaaaaaaaaaaabcdef',
      historicalRecipients: const [
        '0x123456bbbbbbbbbbbbbbbbbbbbbbbbbbbbabcdef',
      ],
    );

    expect(result.kind, AddressRiskKind.lookalike);
    expect(result.similarAddress, '0x123456bbbbbbbbbbbbbbbbbbbbbbbbbbbbabcdef');
  });

  test('marks an unseen recipient as new', () {
    final result = detectAddressRisk(
      recipient: '0x2222222222222222222222222222222222222222',
      historicalRecipients: const [
        '0x1111111111111111111111111111111111111111',
      ],
    );

    expect(result.kind, AddressRiskKind.newRecipient);
  });

  test('recognizes a previously used recipient case-insensitively', () {
    final result = detectAddressRisk(
      recipient: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
      historicalRecipients: const [
        '0xABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCD',
      ],
    );

    expect(result.kind, AddressRiskKind.knownRecipient);
  });
}
