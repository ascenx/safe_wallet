import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/shared/security/wallet_password_policy.dart';

void main() {
  test('requires at least eight characters', () {
    expect(
      WalletPasswordPolicy.issueFor('A3!xyz7'),
      WalletPasswordIssue.tooShort,
    );
    expect(WalletPasswordPolicy.issueFor('A3!xyz78'), isNull);
  });

  test('surrounding whitespace does not satisfy the minimum length', () {
    expect(
      WalletPasswordPolicy.issueFor('       five!       '),
      WalletPasswordIssue.tooShort,
    );
  });

  test('rejects repeated eight-character passwords as too common', () {
    expect(
      WalletPasswordPolicy.issueFor('aaaaaaaa'),
      WalletPasswordIssue.tooCommon,
    );
  });

  test('rejects a common eight-digit sequence', () {
    expect(
      WalletPasswordPolicy.issueFor('12345678'),
      WalletPasswordIssue.tooCommon,
    );
  });
}
