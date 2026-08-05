import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/shared/crypto/kdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses the hardened work factor for new password encryption', () {
    expect(const KdfService().params['iterations'], 600000);
  });

  test(
    'deriveKey uses native PBKDF2 on supported platforms',
    () async {
      const channel = MethodChannel('safe_wallet/crypto');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final expected = Uint8List.fromList(
        List<int>.generate(32, (index) => index),
      );
      MethodCall? receivedCall;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(channel, (call) async {
        receivedCall = call;
        return expected;
      });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
      });

      final result = await const KdfService(
        iterations: 1234,
      ).deriveKey(password: 'password', salt: const [1, 2, 3, 4]);

      expect(result, expected);
      expect(receivedCall?.method, 'derivePbkdf2HmacSha256');
      expect(receivedCall?.arguments, {
        'password': 'password',
        'salt': Uint8List.fromList(const [1, 2, 3, 4]),
        'iterations': 1234,
        'bits': 256,
      });
    },
    skip: kIsWeb ? 'Native mobile channels are unavailable on web.' : false,
  );

  test('deriveKey matches the PBKDF2-HMAC-SHA256 reference vector', () async {
    final result = await const KdfService(
      iterations: 1,
    ).deriveKey(password: 'password', salt: utf8.encode('salt'));

    expect(
      result,
      _hexToBytes(
        '120fb6cffcf8b32c43e7225256c4f837'
        'a86548c92ccc35480805987cb70be17b',
      ),
    );
  });

  test(
    'deriveKey does not schedule delay timers on the caller isolate',
    () async {
      var timerCount = 0;

      final result = await runZoned(
        () => const KdfService(iterations: 4000).deriveKey(
          password: 'password',
          salt: List<int>.generate(16, (index) => index),
        ),
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) {
            timerCount += 1;
            return parent.createTimer(zone, duration, callback);
          },
        ),
      );

      expect(result, hasLength(32));
      expect(timerCount, 0);
    },
  );

  test('rejects an excessive PBKDF2 work factor before deriving', () async {
    await expectLater(
      const KdfService().deriveKey(
        password: 'password',
        salt: List<int>.filled(16, 1),
        params: const {
          'iterations': KdfService.maximumIterations + 1,
          'bits': 256,
        },
      ),
      throwsArgumentError,
    );
  });
}

List<int> _hexToBytes(String value) {
  return List<int>.generate(
    value.length ~/ 2,
    (index) => int.parse(value.substring(index * 2, index * 2 + 2), radix: 16),
  );
}
