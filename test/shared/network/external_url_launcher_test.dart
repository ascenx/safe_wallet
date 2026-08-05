import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/shared/network/external_url_launcher.dart';

void main() {
  test('external URLs are limited to absolute HTTP and HTTPS URLs', () {
    expect(isAllowedExternalUrl('https://example.com/path'), isTrue);
    expect(isAllowedExternalUrl('http://localhost:3000/path'), isTrue);
    expect(isAllowedExternalUrl('javascript:alert(1)'), isFalse);
    expect(isAllowedExternalUrl('data:text/html,hello'), isFalse);
    expect(isAllowedExternalUrl('file:///tmp/secret'), isFalse);
    expect(isAllowedExternalUrl('//example.com/path'), isFalse);
    expect(isAllowedExternalUrl('https:///missing-host'), isFalse);
  });
}
