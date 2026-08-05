import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/wallet_connect/data/wallet_connect_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('safe_wallet/wallet_connect_link_test');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('reads a valid cold-start URI and rejects unrelated links', () async {
    final service = MethodChannelWalletConnectLinkService(channel: channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getInitialLink');
      return 'wc:topic@2?symKey=secret';
    });

    expect(await service.getInitialUri(), 'wc:topic@2?symKey=secret');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 'https://example.com');
    expect(await service.getInitialUri(), isNull);
  });

  test('emits warm-start links once and filters malformed values', () async {
    final service = MethodChannelWalletConnectLinkService(channel: channel);
    final values = <String>[];
    final subscription = service.links.listen(values.add);
    addTearDown(subscription.cancel);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onLink', 'wc:topic@2?symKey=secret'),
      ),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onLink', 'not-wallet-connect'),
      ),
      (_) {},
    );
    await pumpEventQueue();

    expect(values, ['wc:topic@2?symKey=secret']);
  });

  test('extracts encoded wc URI from the SafeWallet redirect scheme', () {
    expect(
      walletConnectUriFromLink(
        'safewallet://walletconnect?uri='
        'wc%3Atopic%402%3FsymKey%3Dsecret',
      ),
      'wc:topic@2?symKey=secret',
    );
    expect(
      walletConnectUriFromLink('safewallet://walletconnect?uri=https://bad'),
      isNull,
    );
  });
}
