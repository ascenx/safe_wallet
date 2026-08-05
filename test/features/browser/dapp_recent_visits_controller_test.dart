import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/browser/application/dapp_recent_visits_controller.dart';

void main() {
  test('dApp URLs are canonicalized to HTTPS without query or fragment', () {
    expect(
      normalizeDappRecentVisitUrl(
        'http://app.example.com/swap?token=secret#confirm',
      ),
      'https://app.example.com/swap',
    );
    expect(
      normalizeDappRecentVisitUrl('app.example.com/swap?token=secret#confirm'),
      'https://app.example.com/swap',
    );
  });
}
