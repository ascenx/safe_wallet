import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/settings/application/app_update_checker.dart';
import 'package:safe_wallet/features/settings/application/app_version_provider.dart';
import 'package:safe_wallet/features/settings/presentation/about_page.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/network/external_url_launcher.dart';

void main() {
  testWidgets('about page shows the first-phase information and actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const AboutPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final logo = tester.widget<SvgPicture>(
      find.byKey(const Key('aboutAppLogo')),
    );
    final logoLoader = logo.bytesLoader as SvgAssetLoader;
    expect(
      logoLoader.assetName,
      'assets/common/logo.svg',
    );

    for (final label in [
      '检查更新',
      '更新日志',
      'GitHub',
      '数据与网络说明',
      '开源软件许可',
      '问题反馈',
      '隐私政策',
      '使用条款',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        250,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('available update opens a release sheet and update link', (
    tester,
  ) async {
    final launcher = _RecordingUrlLauncher();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionReaderProvider.overrideWithValue(
            const _FakeAppVersionReader(),
          ),
          appReleaseRepositoryProvider.overrideWithValue(
            const _FakeAppReleaseRepository(),
          ),
          externalUrlLauncherProvider.overrideWithValue(launcher),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const AboutPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checkForUpdatesRow')));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 1.1.0'), findsOneWidget);
    expect(find.text('Privacy and network improvements'), findsOneWidget);
    expect(find.text('发布时间：2026-07-28'), findsOneWidget);

    await tester.tap(find.text('前往更新'));
    await tester.pumpAndSettle();

    expect(launcher.urls, [
      'https://github.com/ascenx/safe_wallet/releases/tag/v1.1.0',
    ]);
  });

  testWidgets('data, privacy, and terms entries open local explanations', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const AboutPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openRow(tester, '数据与网络说明');
    expect(find.text('不依赖自建私有后端'), findsOneWidget);
    expect(find.textContaining('CoinGecko'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await _openRow(tester, '隐私政策');
    expect(find.textContaining('不会向 Safe Wallet 自建服务器上传'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await _openRow(tester, '使用条款');
    expect(find.textContaining('区块链交易通常不可撤销'), findsOneWidget);
  });

  testWidgets('about links use the expected public GitHub destinations', (
    tester,
  ) async {
    final launcher = _RecordingUrlLauncher();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          externalUrlLauncherProvider.overrideWithValue(launcher),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const AboutPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapRowWithoutNavigation(tester, '更新日志');
    await _tapRowWithoutNavigation(tester, 'GitHub');
    await _tapRowWithoutNavigation(tester, '问题反馈');

    expect(launcher.urls, [
      safeWalletReleasesUrl,
      safeWalletGitHubUrl,
      safeWalletFeedbackUrl,
    ]);
  });

  testWidgets('update failure shows a retryable error message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionReaderProvider.overrideWithValue(
            const _FakeAppVersionReader(),
          ),
          appReleaseRepositoryProvider.overrideWithValue(
            const _FailingAppReleaseRepository(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const AboutPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checkForUpdatesRow')));
    await tester.pumpAndSettle();

    expect(find.text('检查更新失败，请稍后重试'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
  });
}

Future<void> _openRow(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    300,
    scrollable: find.byType(Scrollable),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _tapRowWithoutNavigation(
  WidgetTester tester,
  String label,
) async {
  await tester.scrollUntilVisible(
    find.text(label),
    300,
    scrollable: find.byType(Scrollable),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pump();
}

final class _FakeAppVersionReader implements AppVersionReader {
  const _FakeAppVersionReader();

  @override
  Future<AppVersionInfo> read() async {
    return const AppVersionInfo(version: '1.0.0', buildNumber: '1');
  }
}

final class _FakeAppReleaseRepository implements AppReleaseRepository {
  const _FakeAppReleaseRepository();

  @override
  Future<AppReleaseInfo?> getLatestRelease() async {
    return AppReleaseInfo(
      version: '1.1.0',
      title: 'Safe Wallet 1.1.0',
      notes: 'Privacy and network improvements',
      url: 'https://github.com/ascenx/safe_wallet/releases/tag/v1.1.0',
      publishedAt: DateTime.utc(2026, 7, 28),
    );
  }
}

final class _FailingAppReleaseRepository implements AppReleaseRepository {
  const _FailingAppReleaseRepository();

  @override
  Future<AppReleaseInfo?> getLatestRelease() {
    throw StateError('offline');
  }
}

final class _RecordingUrlLauncher implements ExternalUrlLauncher {
  final urls = <String>[];

  @override
  Future<bool> openExternal(String url) async {
    urls.add(url);
    return true;
  }
}
