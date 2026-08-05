import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/app/app.dart';
import 'package:safe_wallet/features/home/application/home_controller.dart';
import 'package:safe_wallet/features/i18n/application/locale_controller.dart';
import 'package:safe_wallet/features/i18n/application/locale_preference_store.dart';
import 'package:safe_wallet/features/settings/application/launch_lock_setting.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/application/wallet_session_controller.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/shared/security/biometric_password_store.dart';
import 'package:safe_wallet/shared/security/session_key_cache.dart';

void main() {
  testWidgets('existing wallet shows app unlock by default', (tester) async {
    final repository = _ExistingWalletRepository();

    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appUnlockPasswordInput')), findsOneWidget);
    expect(repository.unlockCalls, 0);
    expect(find.text('总资产估值'), findsNothing);
  });

  testWidgets('disabled launch lock opens main shell without password unlock', (
    tester,
  ) async {
    final repository = _ExistingWalletRepository();
    final launchLockStore = InMemoryLaunchLockSettingStore();
    await launchLockStore.saveRequirePasswordOnLaunch(false);

    await tester.pumpWidget(
      _app(repository: repository, launchLockStore: launchLockStore),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appUnlockPasswordInput')), findsNothing);
    expect(repository.unlockCalls, 0);
    expect(find.text('总资产估值'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('浏览器'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('android root back requires confirmation before exiting', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    try {
      final repository = _ExistingWalletRepository();
      final launchLockStore = InMemoryLaunchLockSettingStore(
        requirePasswordOnLaunch: false,
      );

      await tester.pumpWidget(
        _app(repository: repository, launchLockStore: launchLockStore),
      );
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.text('再次返回即可退出 App'), findsOneWidget);
      expect(
        platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
        isEmpty,
      );

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(
        platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
        hasLength(1),
      );
      await tester.pump(const Duration(seconds: 2));
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    }
  });

  testWidgets('manual app unlock opens the main shell', (tester) async {
    final repository = _ExistingWalletRepository();

    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('appUnlockPasswordInput')),
      'password',
    );
    await tester.tap(find.byKey(const Key('appUnlockButton')));
    await tester.pumpAndSettle();

    expect(repository.unlockCalls, 1);
    expect(repository.lastUnlockPassword, 'password');
    expect(find.text('总资产估值'), findsOneWidget);
  });

  testWidgets('locking the wallet session returns to app unlock', (
    tester,
  ) async {
    final repository = _ExistingWalletRepository();

    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('appUnlockPasswordInput')),
      'password',
    );
    await tester.tap(find.byKey(const Key('appUnlockButton')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.text('总资产估值')),
    );
    container.read(walletSessionControllerProvider.notifier).lock();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appUnlockPasswordInput')), findsOneWidget);
    expect(find.text('总资产估值'), findsNothing);
  });

  testWidgets('manual app unlock does not wait for biometric setup checks', (
    tester,
  ) async {
    final repository = _ExistingWalletRepository();
    final authenticator = _BlockingSecondBiometricAuthenticator();
    addTearDown(authenticator.completePendingCheck);
    final biometricStore = BiometricPasswordStore(
      authenticator: authenticator,
      storage: _FakeSecurePasswordStorage(),
    );

    await tester.pumpWidget(
      _app(repository: repository, biometricStore: biometricStore),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('appUnlockPasswordInput')),
      'password',
    );
    await tester.tap(find.byKey(const Key('appUnlockButton')));
    await tester.pump();

    expect(repository.unlockCalls, 1);
    expect(find.text('总资产估值'), findsOneWidget);
    expect(authenticator.canAuthenticateCallCount, 1);
  });

  testWidgets('tapping blank app space dismisses the keyboard focus', (
    tester,
  ) async {
    final repository = _ExistingWalletRepository();

    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('appUnlockPasswordInput')));
    await tester.pump();

    final focusedInput = tester.widget<EditableText>(find.byType(EditableText));
    expect(focusedInput.focusNode.hasFocus, isTrue);

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    expect(focusedInput.focusNode.hasFocus, isFalse);
  });

  testWidgets('legacy saved biometric password is discarded', (tester) async {
    final repository = _ExistingWalletRepository();
    final authenticator = _FakeBiometricAuthenticator(
      canAuthenticate: true,
      authenticateResult: true,
    );
    final storage = _FakeSecurePasswordStorage()..password = 'saved-password';
    final biometricStore = BiometricPasswordStore(
      authenticator: authenticator,
      storage: storage,
    );

    await tester.pumpWidget(
      _app(repository: repository, biometricStore: biometricStore),
    );
    await tester.pumpAndSettle();

    expect(repository.unlockCalls, 0);
    expect(storage.password, isNull);
    expect(find.byKey(const Key('appUnlockPasswordInput')), findsOneWidget);
  });

  testWidgets('saved biometric wallet key bypasses password derivation', (
    tester,
  ) async {
    final repository = _ExistingWalletRepository();
    final authenticator = _FakeBiometricAuthenticator(
      canAuthenticate: true,
      authenticateResult: true,
    );
    final storage = _FakeSecurePasswordStorage()
      ..password = jsonEncode({
        'kind': 'safe_wallet_biometric_credential',
        'version': 2,
        'walletId': _account.id,
        'walletDek': base64Encode(
          List<int>.generate(32, (index) => 31 - index),
        ),
      });
    final biometricStore = BiometricPasswordStore(
      authenticator: authenticator,
      storage: storage,
    );

    await tester.pumpWidget(
      _app(repository: repository, biometricStore: biometricStore),
    );
    await tester.pumpAndSettle();

    expect(repository.unlockCalls, 0);
    expect(authenticator.authenticateCallCount, 1);
    expect(find.text('总资产估值'), findsOneWidget);
  });

  testWidgets('biometric app unlock can switch to manual password', (
    tester,
  ) async {
    final repository = _ExistingWalletRepository();
    final biometricStore = BiometricPasswordStore(
      authenticator: _FakeBiometricAuthenticator(
        canAuthenticate: true,
        authenticateResult: false,
      ),
      storage: _FakeSecurePasswordStorage()
        ..password = jsonEncode({
          'kind': 'safe_wallet_biometric_credential',
          'version': 2,
          'walletId': _account.id,
          'walletDek': base64Encode(List<int>.filled(32, 7)),
        }),
    );

    await tester.pumpWidget(
      _app(repository: repository, biometricStore: biometricStore),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appUnlockUsePasswordButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('appUnlockUsePasswordButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('appUnlockPasswordInput')),
      'manual-password',
    );
    await tester.tap(find.byKey(const Key('appUnlockButton')));
    await tester.pumpAndSettle();

    expect(repository.unlockCalls, 1);
    expect(repository.lastUnlockPassword, 'manual-password');
    expect(find.text('总资产估值'), findsOneWidget);
  });
}

Widget _app({
  required _ExistingWalletRepository repository,
  LaunchLockSettingStore? launchLockStore,
  BiometricPasswordStore? biometricStore,
}) {
  return ProviderScope(
    overrides: [
      walletRepositoryProvider.overrideWithValue(repository),
      sessionKeyCacheProvider.overrideWithValue(SessionKeyCache()),
      homeControllerProvider.overrideWithValue(HomeState.emptyAssets()),
      localePreferenceStoreProvider.overrideWithValue(
        InMemoryLocalePreferenceStore(initialMode: AppLocaleMode.zh),
      ),
      if (launchLockStore != null)
        launchLockSettingStoreProvider.overrideWithValue(launchLockStore),
      if (biometricStore != null)
        biometricPasswordStoreProvider.overrideWithValue(biometricStore),
    ],
    child: const SafeWalletApp(),
  );
}

final _now = DateTime.utc(2026, 6, 6);
final _account = WalletAccount(
  id: 'wallet-1',
  name: 'Wallet 1',
  evmAddress: '0x1111111111111111111111111111111111111111',
  solanaAddress: '11111111111111111111111111111111',
  createdAt: _now,
  updatedAt: _now,
);

final class _ExistingWalletRepository implements WalletRepository {
  int unlockCalls = 0;
  String? lastUnlockPassword;

  @override
  Future<List<WalletAccount>> getWallets() async => [_account];

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    unlockCalls += 1;
    lastUnlockPassword = password;
    return WalletUnlockResult(account: _account, walletDek: const [1, 2, 3, 4]);
  }

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> renameWallet({
    required String walletId,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) {
    throw UnimplementedError();
  }
}

final class _FakeBiometricAuthenticator implements BiometricAuthenticator {
  _FakeBiometricAuthenticator({
    required this.canAuthenticate,
    required this.authenticateResult,
  });

  final bool canAuthenticate;
  final bool authenticateResult;
  int canAuthenticateCallCount = 0;
  int authenticateCallCount = 0;

  @override
  Future<bool> canAuthenticateWithBiometrics() async {
    canAuthenticateCallCount += 1;
    return canAuthenticate;
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCallCount += 1;
    return authenticateResult;
  }
}

final class _BlockingSecondBiometricAuthenticator
    implements BiometricAuthenticator {
  final Completer<bool> _pendingCheck = Completer<bool>();
  int canAuthenticateCallCount = 0;

  @override
  Future<bool> canAuthenticateWithBiometrics() {
    canAuthenticateCallCount += 1;
    if (canAuthenticateCallCount == 1) {
      return Future<bool>.value(false);
    }
    return _pendingCheck.future;
  }

  @override
  Future<bool> authenticate({required String reason}) async => false;

  void completePendingCheck() {
    if (!_pendingCheck.isCompleted) {
      _pendingCheck.complete(false);
    }
  }
}

final class _FakeSecurePasswordStorage implements SecurePasswordStorage {
  String? password;
  int readCallCount = 0;

  @override
  Future<String?> readPassword() async {
    readCallCount += 1;
    return password;
  }

  @override
  Future<void> savePassword(String password) async {
    this.password = password;
  }

  @override
  Future<void> deletePassword() async {
    password = null;
  }
}
