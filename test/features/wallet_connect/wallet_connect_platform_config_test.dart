import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android accepts WalletConnect links with singleTop delivery', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/safewallet/app/MainActivity.kt',
    ).readAsStringSync();

    expect(manifest, contains('android:launchMode="singleTop"'));
    expect(manifest, contains('android:scheme="wc"'));
    expect(manifest, contains('android:scheme="safewallet"'));
    expect(activity, contains('override fun onNewIntent'));
    expect(activity, contains('safe_wallet/wallet_connect_link'));
  });

  test(
    'Android resolves the Reown WalletConnect Pay artifact from JitPack',
    () {
      final build = File('android/build.gradle.kts').readAsStringSync();

      expect(build, contains('maven("https://jitpack.io")'));
    },
  );

  test('iOS registers link schemes and forwards scene URLs to Flutter', () {
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final sceneDelegate = File(
      'ios/Runner/SceneDelegate.swift',
    ).readAsStringSync();

    expect(info, contains('<string>wc</string>'));
    expect(info, contains('<string>safewallet</string>'));
    expect(appDelegate, contains('safe_wallet/wallet_connect_link'));
    expect(sceneDelegate, contains('openURLContexts'));
  });
}
