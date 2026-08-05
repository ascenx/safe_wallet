import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/shared/security/inactive_privacy_shield_suppression.dart';
import 'package:safe_wallet/shared/security/sensitive_clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sensitive clipboard automatically clears only the copied secret',
    () async {
      final platform = _FakeSensitiveClipboardPlatform();
      final service = SensitiveClipboardService(
        platform: platform,
        clearAfter: const Duration(milliseconds: 10),
      );

      await service.copy('secret phrase');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(platform.copiedValues, ['secret phrase']);
      expect(platform.clearMatches, ['secret phrase']);
      service.dispose();
    },
  );

  test('background clearing cancels the pending clipboard timer', () async {
    final platform = _FakeSensitiveClipboardPlatform();
    final service = SensitiveClipboardService(
      platform: platform,
      clearAfter: const Duration(seconds: 30),
    );

    await service.copy('private-key');
    await service.clearNow();

    expect(platform.clearMatches, ['private-key']);
    service.dispose();
  });

  test(
    'unsupported platform clears a matching secret with privacy suppression',
    () async {
      String? clipboardText;
      bool? suppressionWasActive;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final suppression = container.read(
        inactivePrivacyShieldSuppressionProvider,
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            final arguments = call.arguments as Map<Object?, Object?>;
            clipboardText = arguments['text'] as String?;
          case 'Clipboard.getData':
            suppressionWasActive = suppression.isActive;
            return <String, Object?>{'text': clipboardText};
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      final platform = MethodChannelSensitiveClipboardPlatform(
        channel: const MethodChannel('safe_wallet/test_missing_clipboard'),
      );

      await platform.copy(
        'secret phrase',
        expiresAfter: const Duration(seconds: 30),
      );
      await platform.clearIfMatches('secret phrase');

      expect(clipboardText, isEmpty);
      expect(suppressionWasActive, isTrue);

      clipboardText = 'replacement text';
      await platform.clearIfMatches('secret phrase');

      expect(clipboardText, 'replacement text');
    },
  );
}

final class _FakeSensitiveClipboardPlatform
    implements SensitiveClipboardPlatform {
  final copiedValues = <String>[];
  final clearMatches = <String>[];

  @override
  Future<void> copy(String value, {required Duration expiresAfter}) async {
    copiedValues.add(value);
  }

  @override
  Future<void> clearIfMatches(String value) async {
    clearMatches.add(value);
  }
}
