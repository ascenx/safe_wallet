// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/dapp/data/dapp_provider_webview_injector.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelDappProviderDocumentStartInjector', () {
    test(
      'sends WebKit web view identifier and provider source to native code',
      () async {
        const channel = MethodChannel('safe_wallet/test_webview');
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });

        final injector = MethodChannelDappProviderDocumentStartInjector(
          channel: channel,
        );

        final installed = await injector.install(
          controller: _WebKitLikeController(
            const PlatformWebViewControllerCreationParams(),
            webViewIdentifier: 42,
          ),
          source: 'window.ethereum = provider;',
        );

        expect(installed, isTrue);
        expect(calls, hasLength(1));
        expect(calls.single.method, 'addDocumentStartScript');
        expect(calls.single.arguments, {
          'webViewIdentifier': 42,
          'source': 'window.ethereum = provider;',
        });
      },
    );

    test('native iOS injection is restricted to the main frame', () {
      final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

      expect(source, contains('forMainFrameOnly: true'));
    });
  });
}

final class _WebKitLikeController extends PlatformWebViewController {
  _WebKitLikeController(super.params, {required this.webViewIdentifier})
    : super.implementation();

  final int webViewIdentifier;
}
