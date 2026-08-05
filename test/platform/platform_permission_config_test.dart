import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('platform permission configuration', () {
    test(
      'mobile release application identifiers use the Safe Wallet domain',
      () {
        final androidBuild = _requiredFileText('android/app/build.gradle.kts');
        final androidActivity = _requiredFileText(
          'android/app/src/main/kotlin/com/safewallet/app/MainActivity.kt',
        );
        final iosProject = _requiredFileText(
          'ios/Runner.xcodeproj/project.pbxproj',
        );

        expect(androidBuild, contains('namespace = "com.safewallet.app"'));
        expect(androidBuild, contains('applicationId = "com.safewallet.app"'));
        expect(androidActivity, startsWith('package com.safewallet.app'));
        expect(
          iosProject,
          contains('PRODUCT_BUNDLE_IDENTIFIER = com.safewallet.app;'),
        );
        expect(
          androidBuild,
          isNot(contains('signingConfigs.getByName("debug")')),
        );
      },
    );

    test('only mobile platform runners are checked in', () {
      for (final path in ['android', 'ios']) {
        expect(
          Directory(path).existsSync(),
          isTrue,
          reason: '$path is a supported mobile platform.',
        );
      }

      for (final path in ['linux', 'macos', 'web', 'windows']) {
        expect(
          Directory(path).existsSync(),
          isFalse,
          reason: '$path is outside the supported mobile platform scope.',
        );
      }
    });

    test('iOS signing team is configured locally', () {
      final iosProject = _requiredFileText(
        'ios/Runner.xcodeproj/project.pbxproj',
      );

      expect(
        iosProject,
        isNot(contains('DEVELOPMENT_TEAM =')),
        reason: 'Contributor-specific Apple Team IDs must not be committed.',
      );
    });

    test('Android release declares internet permission', () {
      final manifest = _requiredFileText(
        'android/app/src/main/AndroidManifest.xml',
      );

      expect(
        manifest,
        contains('android.permission.INTERNET'),
        reason: 'Release builds need network access for RPC and market data.',
      );
    });

    test('wallet storage is excluded from Android and iOS backups', () {
      final manifest = _requiredFileText(
        'android/app/src/main/AndroidManifest.xml',
      );
      final extractionRules = _requiredFileText(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      );
      final bootstrap = _requiredFileText('lib/app/app_bootstrap.dart');
      final iosDelegate = _requiredFileText('ios/Runner/AppDelegate.swift');

      expect(manifest, contains('android:allowBackup="false"'));
      expect(manifest, contains('android:fullBackupContent="false"'));
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      expect(extractionRules, contains('<exclude domain="root" path="."/>'));
      expect(bootstrap, contains('excludeWalletStorageFromBackup'));
      expect(
        bootstrap.indexOf('excludeWalletStorageFromBackup'),
        greaterThan(bootstrap.indexOf(').initialize()')),
        reason: 'The iOS storage directory must exist before it is excluded.',
      );
      expect(iosDelegate, contains('isExcludedFromBackup = true'));
    });

    test(
      'native platforms mark exported secrets as sensitive clipboard data',
      () {
        final androidActivity = _requiredFileText(
          'android/app/src/main/kotlin/com/safewallet/app/MainActivity.kt',
        );
        final iosDelegate = _requiredFileText('ios/Runner/AppDelegate.swift');

        expect(androidActivity, contains('ClipDescription.EXTRA_IS_SENSITIVE'));
        expect(androidActivity, contains('clearSensitiveClipboardIfMatches'));
        expect(iosDelegate, contains('UIPasteboard.OptionsKey.localOnly'));
        expect(iosDelegate, contains('UIPasteboard.OptionsKey.expirationDate'));
        expect(iosDelegate, contains('public.utf8-plain-text'));
        expect(iosDelegate, isNot(contains('UTType.utf8PlainText')));
        expect(iosDelegate, contains('clearSensitiveClipboardIfMatches'));
      },
    );

    test('iOS obscures sensitive content while the screen is captured', () {
      final iosDelegate = _requiredFileText('ios/Runner/AppDelegate.swift');

      expect(iosDelegate, contains('UIScreen.capturedDidChangeNotification'));
      expect(iosDelegate, contains('UIScreen.main.isCaptured'));
      expect(iosDelegate, contains('UIVisualEffectView'));
      expect(iosDelegate, contains('setSensitiveScreenProtection'));
    });

    test('Android declares camera permission for QR scanning', () {
      final manifest = _requiredFileText(
        'android/app/src/main/AndroidManifest.xml',
      );

      expect(
        manifest,
        contains('android.permission.CAMERA'),
        reason: 'QR scanning needs the Android camera runtime permission.',
      );
    });

    test('Android declares legacy gallery write permission', () {
      final manifest = _requiredFileText(
        'android/app/src/main/AndroidManifest.xml',
      );

      expect(manifest, contains('android.permission.WRITE_EXTERNAL_STORAGE'));
      expect(manifest, contains('android:maxSdkVersion="29"'));
    });

    test('Android app label uses string resources for system prompts', () {
      final manifest = _requiredFileText(
        'android/app/src/main/AndroidManifest.xml',
      );
      final defaultStrings = _requiredFileText(
        'android/app/src/main/res/values/strings.xml',
      );
      final zhStrings = _requiredFileText(
        'android/app/src/main/res/values-zh/strings.xml',
      );

      expect(manifest, contains('android:label="@string/app_name"'));
      expect(
        defaultStrings,
        contains('<string name="app_name">Safe Wallet</string>'),
      );
      expect(
        zhStrings,
        contains('<string name="app_name">Safe Wallet</string>'),
      );
    });

    test(
      'Android enables FLAG_SECURE through the security platform channel',
      () {
        final mainActivity = _requiredFileText(
          'android/app/src/main/kotlin/com/safewallet/app/MainActivity.kt',
        );

        expect(mainActivity, contains('safe_wallet/security'));
        expect(mainActivity, contains('setSensitiveScreenProtection'));
        expect(
          mainActivity,
          contains('WindowManager.LayoutParams.FLAG_SECURE'),
        );
        expect(mainActivity, contains('window.clearFlags'));
      },
    );

    test('Android provides native PBKDF2 on a background executor', () {
      final mainActivity = _requiredFileText(
        'android/app/src/main/kotlin/com/safewallet/app/MainActivity.kt',
      );

      expect(mainActivity, contains('safe_wallet/crypto'));
      expect(mainActivity, contains('derivePbkdf2HmacSha256'));
      expect(mainActivity, contains('SecretKeyFactory'));
      expect(mainActivity, contains('PBKDF2WithHmacSHA256'));
      expect(mainActivity, contains('cryptoExecutor.execute'));
    });

    test('iOS declares localized camera usage descriptions', () {
      final plist = _requiredFileText('ios/Runner/Info.plist');
      final xcodeProject = _requiredFileText(
        'ios/Runner.xcodeproj/project.pbxproj',
      );
      final englishStrings = _requiredFileText(
        'ios/Runner/en.lproj/InfoPlist.strings',
      );
      final simplifiedChineseStrings = _requiredFileText(
        'ios/Runner/zh-Hans.lproj/InfoPlist.strings',
      );

      expect(
        plist,
        contains('<key>NSCameraUsageDescription</key>'),
        reason: 'iOS requires a camera usage description before scanning.',
      );
      expect(
        englishStrings,
        contains('Scan payment addresses, WalletConnect URIs, and dApp links.'),
      );
      expect(
        simplifiedChineseStrings,
        contains('用于扫码识别收款地址、WalletConnect URI 和 dApp 链接。'),
      );
      expect(xcodeProject, contains('InfoPlist.strings in Resources'));
      expect(xcodeProject, contains('zh-Hans'));
    });

    test('iOS declares localized photo library usage descriptions', () {
      final plist = _requiredFileText('ios/Runner/Info.plist');
      final englishStrings = _requiredFileText(
        'ios/Runner/en.lproj/InfoPlist.strings',
      );
      final simplifiedChineseStrings = _requiredFileText(
        'ios/Runner/zh-Hans.lproj/InfoPlist.strings',
      );

      expect(plist, contains('<key>NSPhotoLibraryAddUsageDescription</key>'));
      expect(plist, contains('<key>NSPhotoLibraryUsageDescription</key>'));
      expect(
        englishStrings,
        contains(
          '"NSPhotoLibraryAddUsageDescription" = "Save wallet receive QR images to your photo library.";',
        ),
      );
      expect(
        englishStrings,
        contains(
          '"NSPhotoLibraryUsageDescription" = "Access your photo library to save wallet receive QR images.";',
        ),
      );
      expect(
        simplifiedChineseStrings,
        contains('"NSPhotoLibraryAddUsageDescription" = "用于将钱包收款二维码保存到系统相册。";'),
      );
      expect(
        simplifiedChineseStrings,
        contains('"NSPhotoLibraryUsageDescription" = "用于访问系统相册并保存钱包收款二维码。";'),
      );
    });

    test('iOS provides native PBKDF2 through CommonCrypto', () {
      final appDelegate = _requiredFileText('ios/Runner/AppDelegate.swift');
      final bridgingHeader = _requiredFileText(
        'ios/Runner/Runner-Bridging-Header.h',
      );

      expect(appDelegate, contains('safe_wallet/crypto'));
      expect(appDelegate, contains('derivePbkdf2HmacSha256'));
      expect(appDelegate, contains('CCKeyDerivationPBKDF'));
      expect(bridgingHeader, contains('CommonCrypto/CommonKeyDerivation.h'));
    });
  });
}

String _requiredFileText(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path must exist.');
  return file.readAsStringSync();
}
