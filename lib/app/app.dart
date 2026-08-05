import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/i18n/application/locale_controller.dart';
import '../features/settings/application/theme_color_setting.dart';
import '../features/settings/application/theme_mode_setting.dart';
import '../features/wallet_connect/presentation/wallet_connect_request_host.dart';
import '../i18n/generated/translations.g.dart';
import '../shared/design/app_brand_colors.dart';
import '../shared/design/app_theme.dart';
import 'android_double_back_exit.dart';
import 'app_lifecycle_observer.dart';
import 'app_router.dart';

final class SafeWalletApp extends ConsumerStatefulWidget {
  const SafeWalletApp({super.key});

  @override
  ConsumerState<SafeWalletApp> createState() => _SafeWalletAppState();
}

final class _SafeWalletAppState extends ConsumerState<SafeWalletApp> {
  AppLocale? _pendingSlangLocale;

  @override
  Widget build(BuildContext context) {
    final localeModeState = ref.watch(localeControllerProvider);
    final themeColor =
        ref.watch(themeColorSettingProvider).value ?? AppThemeColor.indigo;
    final themeMode =
        ref.watch(themeModeSettingProvider).value ?? AppThemeMode.light;
    final navigatorKey = ref.watch(appNavigatorKeyProvider);
    final localeMode = localeModeState.value;
    final appLocale = localeModeState.hasValue
        ? _appLocaleFor(localeMode)
        : LocaleSettings.currentLocale;
    final localeReady =
        localeModeState.hasValue && _ensureSlangLocale(appLocale);

    return TranslationProvider(
      child: MaterialApp(
        title: t.app.name,
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(themeColor),
        darkTheme: buildAppDarkTheme(themeColor),
        themeMode: themeMode.materialThemeMode,
        locale: appLocale.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => WalletConnectRequestHost(
          child: _KeyboardDismissOnTap(child: child ?? const SizedBox.shrink()),
        ),
        home: localeReady
            ? const AndroidDoubleBackExit(
                child: AppLifecycleObserver(child: AppRouter()),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  AppLocale _appLocaleFor(AppLocaleMode? mode) {
    return switch (mode) {
      AppLocaleMode.en => AppLocale.en,
      AppLocaleMode.zh => AppLocale.zh,
      AppLocaleMode.system || null => AppLocaleUtils.findDeviceLocale(),
    };
  }

  bool _ensureSlangLocale(AppLocale appLocale) {
    if (LocaleSettings.currentLocale == appLocale &&
        _pendingSlangLocale == null) {
      return true;
    }

    if (LocaleSettings.instance.isLocaleLoaded(appLocale)) {
      LocaleSettings.setLocaleSync(appLocale);
      _pendingSlangLocale = null;
      return true;
    }

    if (_pendingSlangLocale == appLocale) {
      return false;
    }
    _pendingSlangLocale = appLocale;
    unawaited(_setSlangLocale(appLocale));
    return false;
  }

  Future<void> _setSlangLocale(AppLocale locale) async {
    await LocaleSettings.instance.loadLocale(locale);
    if (!mounted || _pendingSlangLocale != locale) {
      return;
    }
    LocaleSettings.setLocaleSync(locale);
    setState(() {
      _pendingSlangLocale = null;
    });
  }
}

final class _KeyboardDismissOnTap extends StatelessWidget {
  const _KeyboardDismissOnTap({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
