import 'dart:io';

import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/browser/application/dapp_favorites_controller.dart';
import 'package:safe_wallet/features/browser/application/dapp_recent_visits_controller.dart';
import 'package:safe_wallet/features/browser/data/default_dapp_catalog.dart';
import 'package:safe_wallet/features/browser/data/hive_browser_state_repository.dart';
import 'package:safe_wallet/features/browser/domain/dapp_recent_visit.dart';
import 'package:safe_wallet/features/browser/domain/internal_dapp_routes.dart';
import 'package:safe_wallet/features/browser/presentation/browser_home_page.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_radius.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  group('Browser home', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_browser_test_',
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    testWidgets('search is above ordered swipeable category tabs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _browserHome(repository: InMemoryBrowserStateRepository()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final search = find.byKey(const Key('browserSearchField'));
      final tabBarFinder = find.byKey(const Key('browserCategoryTabBar'));
      final tabView = find.byKey(const Key('browserCategoryTabView'));

      expect(search, findsOneWidget);
      expect(tabBarFinder, findsOneWidget);
      expect(tabView, findsOneWidget);
      expect(
        tester.widget<TextField>(search).decoration?.hintText,
        '搜索 dApp 或输入 URL',
      );
      expect(
        tester.getTopLeft(search).dy,
        lessThan(tester.getTopLeft(tabBarFinder).dy),
      );

      final tabBar = tester.widget<TabBar>(tabBarFinder);
      expect(tabBar.isScrollable, isTrue);
      expect(
        tabBar.tabs.map((tab) => (tab as Tab).text),
        [
          '最近',
          '收藏',
          'Swap',
          'Predictions',
          'Staking',
          'Bridge',
        ],
      );
    });

    testWidgets('URL input uses a pill border in every state', (tester) async {
      await tester.pumpWidget(
        _browserHome(repository: InMemoryBrowserStateRepository()),
      );
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const Key('browserSearchField')),
      );
      final decoration = field.decoration!;

      expect(
        (decoration.border! as OutlineInputBorder).borderRadius,
        AppRadius.pillBorder,
      );
      expect(
        (decoration.enabledBorder! as OutlineInputBorder).borderRadius,
        AppRadius.pillBorder,
      );
      expect(
        (decoration.focusedBorder! as OutlineInputBorder).borderRadius,
        AppRadius.pillBorder,
      );
      expect(
        (decoration.errorBorder! as OutlineInputBorder).borderRadius,
        AppRadius.pillBorder,
      );
      expect(
        (decoration.focusedErrorBorder! as OutlineInputBorder).borderRadius,
        AppRadius.pillBorder,
      );
    });

    test('default Bridge catalog includes the requested unique websites', () {
      final bridgeEntries = defaultDappCatalog
          .where((entry) => entry.category.name == 'bridge')
          .toList();

      expect(
        bridgeEntries.map((entry) => entry.name),
        containsAll([
          'Arbitrum Bridge',
          'JustCryptos',
          'Aster',
          'Mantle Bridge',
          'Scroll Bridge',
          'SunX Bridge',
          'Connext',
          'Orbit Bridge',
          'Eclipse Bridge',
          'Mode Bridge',
          'Sorare Bridge',
          'Unichain Bridge',
          'exSat Bridge',
          'Degen Bridge',
          'ioTube',
          'deBridge',
          'Rhino.fi',
          'Treasure Bridge',
          'SWFT',
          'Rango',
          'Orbiter Finance',
        ]),
      );
      expect(bridgeEntries, hasLength(21));
      expect(
        bridgeEntries.map((entry) => entry.id).toSet(),
        hasLength(bridgeEntries.length),
      );
      expect(
        bridgeEntries.map((entry) => Uri.parse(entry.url).host).toSet(),
        hasLength(bridgeEntries.length),
      );
      final nonBridgeHosts = defaultDappCatalog
          .where((entry) => entry.category.name != 'bridge')
          .map((entry) => Uri.parse(entry.url).host)
          .toSet();
      expect(
        bridgeEntries
            .map((entry) => Uri.parse(entry.url).host)
            .where(nonBridgeHosts.contains),
        isEmpty,
      );
    });

    test('default Bridge catalog uses current official entry points', () {
      final urlsByName = {
        for (final entry in defaultDappCatalog.where(
          (entry) => entry.category.name == 'bridge',
        ))
          entry.name: entry.url,
      };

      expect(
          urlsByName['Arbitrum Bridge'], 'https://portal.arbitrum.io/bridge');
      expect(urlsByName['Mantle Bridge'], 'https://app.mantle.xyz/bridge');
      expect(urlsByName['Scroll Bridge'], 'https://portal.scroll.io/bridge');
      expect(urlsByName['Eclipse Bridge'], 'https://app.eclipse.xyz/bridge');
      expect(urlsByName['Mode Bridge'], 'https://superbridge.app/mode');
      expect(urlsByName['Sorare Bridge'], 'https://sorare.com');
      expect(urlsByName['Unichain Bridge'], 'https://www.unichain.org');
      expect(urlsByName['exSat Bridge'], 'https://exsat.network');
      expect(urlsByName['ioTube'], 'https://bridge.iotex.io');
      expect(urlsByName['deBridge'], 'https://app.debridge.com');
    });

    test('every external catalog dApp has a bundled icon', () {
      final externalEntries = defaultDappCatalog.where(
        (entry) {
          final scheme = Uri.tryParse(entry.url)?.scheme;
          return scheme == 'http' || scheme == 'https';
        },
      );

      for (final entry in externalEntries) {
        final png = File('assets/dapp_icons/${entry.id}.png');
        final svg = File('assets/dapp_icons/${entry.id}.svg');
        final icons = [png, svg].where((icon) => icon.existsSync()).toList();
        expect(icons, hasLength(1), reason: entry.name);
        final icon = icons.single;
        final bytes = icon.readAsBytesSync();
        expect(bytes.length, greaterThan(100), reason: entry.name);
        if (icon.path.endsWith('.png')) {
          expect(
            bytes.take(8),
            [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
            reason: entry.name,
          );
        } else {
          expect(icon.readAsStringSync(), contains('<svg'), reason: entry.name);
        }
      }
    });

    test('default Swap catalog covers current mainnet ecosystems', () {
      final swapEntries = defaultDappCatalog
          .where((entry) => entry.category.name == 'swap')
          .toList();

      expect(
        swapEntries.map((entry) => entry.name),
        containsAll([
          '1inch',
          'CoW Swap',
          'Odos',
          'Uniswap',
          'PancakeSwap',
          'QuickSwap',
          'Camelot',
          'Velodrome',
          'Aerodrome',
          'Jupiter',
          'Raydium',
          'Orca',
          'Meteora',
          'pump.fun',
          'Project X',
          'SUN.io',
          'THORSwap',
        ]),
      );
      expect(
        swapEntries.expand((entry) => entry.supportedChainIds).toSet(),
        containsAll([
          '1',
          '56',
          '137',
          '42161',
          '10',
          '8453',
          '999',
          'mainnet-beta',
          'tron-mainnet',
          'bitcoin-mainnet',
        ]),
      );
    });

    test('default Staking catalog includes the requested protocols', () {
      final stakingEntries = defaultDappCatalog
          .where((entry) => entry.category.name == 'staking')
          .map((entry) => entry.name)
          .toList();

      expect(
        stakingEntries,
        containsAll([
          'StakeStone',
          'Lido',
          'Rocket Pool',
          'EigenLayer',
          'ether.fi',
          'Renzo',
          'StakeWise',
          'stake.fish',
          'Stable Vault',
          'Liquid Collective',
          'Marinade Native',
          'stHYPE',
          'BENQI Staked AVAX',
          'BlazeStake',
          'Veno Finance',
          'Stakee',
          'Ankr',
          'Infrared Finance',
          'marginfi LST',
          'AlphaFi stSUI',
          'Inception',
          'Save SOL',
          'Amnis Finance',
          'Hipo',
          'KTON',
          'Magma Staking',
          'SHUI',
          'Nucleon',
          'Meta Pool stIP',
          'HashKing',
          'Pell Network',
          'Lido Impact Staking',
          'BeraPaw',
          'Meta Pool mpSOL',
          'Tranchess Ether',
        ]),
      );
      expect(stakingEntries.toSet().length, stakingEntries.length);
      expect(
        defaultDappCatalog
            .singleWhere((entry) => entry.name == 'Inception')
            .url,
        'https://www.inceptionlrt.com',
      );
    });

    test('default Predictions catalog includes the requested markets', () {
      final predictionEntries = defaultDappCatalog
          .where((entry) => entry.category.name == 'predictions')
          .map((entry) => entry.name)
          .toList();

      expect(
        predictionEntries,
        containsAll([
          'Polymarket',
          'Predict Fun',
          'OPINION',
          'Sport.fun',
          'Limitless Exchange',
          'Myriad Markets',
          'Probable',
          'PredPred',
          'PancakeSwap Prediction',
        ]),
      );
      expect(predictionEntries.toSet().length, predictionEntries.length);
    });

    testWidgets('Swap tab is selected by default without favorites', (
      tester,
    ) async {
      await tester.pumpWidget(
        _browserHome(repository: InMemoryBrowserStateRepository()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('1inch'), findsOneWidget);
      expect(find.text('暂无收藏'), findsNothing);
    });

    testWidgets('favorites tab is selected by default when favorites exist', (
      tester,
    ) async {
      final repository = InMemoryBrowserStateRepository();
      await repository.saveFavoriteDappIds({'uniswap'});
      await repository.saveRecentVisit(
        DappRecentVisit(
          domain: 'recent.example',
          title: 'Recent App',
          url: 'https://recent.example',
          visitedAt: DateTime.utc(2026, 6, 6, 12),
        ),
      );

      await tester.pumpWidget(_browserHome(repository: repository));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Uniswap'), findsOneWidget);
      expect(find.text('Recent App'), findsNothing);
    });

    testWidgets('recent visits are shown after selecting recent', (
      tester,
    ) async {
      final repository = InMemoryBrowserStateRepository();
      await repository.saveRecentVisit(
        DappRecentVisit(
          domain: 'recent.example',
          title: 'Recent App',
          url: 'https://recent.example',
          visitedAt: DateTime.utc(2026, 6, 6, 12),
        ),
      );

      await tester.pumpWidget(_browserHome(repository: repository));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('最近'));
      await tester.pumpAndSettle();

      expect(find.text('Recent App'), findsOneWidget);
      expect(find.text('Uniswap'), findsNothing);
    });

    testWidgets('recent visits can be favorited and shown in favorites', (
      tester,
    ) async {
      final repository = InMemoryBrowserStateRepository();
      await repository.saveRecentVisit(
        DappRecentVisit(
          domain: 'custom.example',
          title: 'Custom App',
          url: 'https://custom.example',
          visitedAt: DateTime.utc(2026, 6, 6, 12),
        ),
      );

      await tester.pumpWidget(_browserHome(repository: repository));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('最近'));
      await tester.pumpAndSettle();

      final recentTile = find.ancestor(
        of: find.text('Custom App'),
        matching: find.byType(ListTile),
      );
      final favoriteButton = find.descendant(
        of: recentTile,
        matching: find.byTooltip('收藏'),
      );
      expect(favoriteButton, findsOneWidget);

      await tester.tap(favoriteButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('收藏'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Custom App'), findsOneWidget);
      expect(find.byTooltip('取消收藏'), findsOneWidget);
    });

    testWidgets('swiping right from favorites opens recent', (tester) async {
      final repository = InMemoryBrowserStateRepository();
      await repository.saveFavoriteDappIds({'uniswap'});
      await repository.saveRecentVisit(
        DappRecentVisit(
          domain: 'recent.example',
          title: 'Recent App',
          url: 'https://recent.example',
          visitedAt: DateTime.utc(2026, 6, 6, 12),
        ),
      );

      await tester.pumpWidget(_browserHome(repository: repository));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Uniswap'), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('browserCategoryTabView')),
        const Offset(500, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent App'), findsOneWidget);
      expect(find.text('Uniswap'), findsNothing);
    });

    testWidgets('default Swap entries are visible', (tester) async {
      await tester.pumpWidget(
        _browserHome(
          repository: InMemoryBrowserStateRepository(),
          chainRepository: _FakeChainRepository(),
          walletRepository: _FakeWalletRepository(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Swap'));
      await tester.pumpAndSettle();

      expect(find.text('Swap'), findsOneWidget);
      expect(find.text('1inch'), findsOneWidget);
      expect(find.text('CoW Swap'), findsOneWidget);
      expect(find.text('Matcha'), findsOneWidget);
      expect(find.text('Odos'), findsOneWidget);
    });

    testWidgets('catalog entries load bundled dApp icons', (tester) async {
      await tester.pumpWidget(
        _browserHome(repository: InMemoryBrowserStateRepository()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Swap'));
      await tester.pumpAndSettle();

      final tile = find.ancestor(
        of: find.text('1inch'),
        matching: find.byType(ListTile),
      );
      final imageFinder = find.descendant(
        of: tile,
        matching: find.byType(Image),
      );

      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(image.image, isA<AssetImage>());
      expect(
        (image.image as AssetImage).assetName,
        'assets/dapp_icons/1inch.png',
      );
    });

    testWidgets('default Staking entries are visible', (tester) async {
      await tester.pumpWidget(
        _browserHome(repository: InMemoryBrowserStateRepository()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Staking'));
      await tester.pumpAndSettle();

      expect(find.text('StakeStone'), findsOneWidget);
      expect(find.text('Lido'), findsOneWidget);
      expect(find.text('Rocket Pool'), findsOneWidget);
    });

    testWidgets('default Predictions entries are visible', (tester) async {
      await tester.pumpWidget(
        _browserHome(repository: InMemoryBrowserStateRepository()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Predictions'));
      await tester.pumpAndSettle();

      expect(find.text('Polymarket'), findsOneWidget);
      expect(find.text('Predict Fun'), findsOneWidget);
      expect(find.text('OPINION'), findsOneWidget);
    });

    testWidgets('default Bridge entries are visible', (tester) async {
      await tester.pumpWidget(
        _browserHome(repository: InMemoryBrowserStateRepository()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Bridge'));
      await tester.pumpAndSettle();

      expect(find.text('Arbitrum Bridge'), findsOneWidget);
      expect(find.text('JustCryptos'), findsOneWidget);
      expect(find.text('Aster'), findsOneWidget);
    });

    testWidgets('default dApp entries show supported chains', (tester) async {
      await tester.pumpWidget(
        _browserHome(
          repository: InMemoryBrowserStateRepository(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Swap'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'uniswap');
      await tester.pump();

      expect(
        find.text(
          'DEX · app.uniswap.org · Ethereum, BNB Smart Chain, Polygon, '
          'Arbitrum, Optimism, Base',
        ),
        findsOneWidget,
      );
    });

    test('favorite persists after repository reopen', () async {
      final repository = await _createRepository(tempDirectory);
      final container = _container(repository);

      await container
          .read(dappFavoritesControllerProvider.notifier)
          .favorite('uniswap');

      final restored = await _reopenRepository(tempDirectory);

      expect(await restored.favoriteDappIds(), contains('uniswap'));
    });

    test('favorite recent visit persists after repository reopen', () async {
      final repository = await _createRepository(tempDirectory);
      final visit = DappRecentVisit(
        domain: 'custom.example',
        title: 'Custom App',
        url: 'https://custom.example',
        visitedAt: DateTime.utc(2026, 6, 6, 12),
      );

      await repository.saveFavoriteVisits([visit]);

      final restored = await _reopenRepository(tempDirectory);

      expect(await restored.favoriteVisits(), [visit]);
    });

    test('recent visit persists newest first with repository max count',
        () async {
      final repository = await _createRepository(
        tempDirectory,
        maxRecentVisits: 2,
      );
      final container = _container(repository);
      final controller =
          container.read(dappRecentVisitsControllerProvider.notifier);

      await controller.recordVisit(
        title: 'First App',
        url: 'https://first.example/swap',
        visitedAt: DateTime.utc(2026, 6, 6, 12),
      );
      await controller.recordVisit(
        title: 'Second App',
        url: 'https://second.example',
        visitedAt: DateTime.utc(2026, 6, 6, 13),
      );
      await controller.recordVisit(
        title: 'Third App',
        url: 'https://third.example',
        visitedAt: DateTime.utc(2026, 6, 6, 14),
      );

      final restored = await _reopenRepository(
        tempDirectory,
        maxRecentVisits: 2,
      );
      final visits = await restored.recentVisits();

      expect(visits.map((visit) => visit.domain), [
        'third.example',
        'second.example',
      ]);
      expect(visits.first.title, 'Third App');
    });

    testWidgets('address input opens URLs or searches Google', (tester) async {
      final openedUrls = <String>[];
      final googleSearchUrl = Uri.https(
        'www.google.com',
        '/search',
        {'q': 'not a url'},
      ).toString();
      await tester.pumpWidget(
        _browserHome(
          repository: InMemoryBrowserStateRepository(),
          onOpenUrl: openedUrls.add,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(find.byType(TextField), 'not a url');
      await tester.tap(find.byIcon(AppIcons.forward));
      await tester.pumpAndSettle();

      expect(openedUrls, [googleSearchUrl]);
      expect(find.text('确认打开网站'), findsNothing);

      await tester.enterText(find.byType(TextField), 'app.uniswap.org');
      await tester.tap(find.byIcon(AppIcons.forward));
      await tester.pumpAndSettle();

      expect(openedUrls, [googleSearchUrl]);
      expect(find.text('确认打开网站'), findsOneWidget);

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(openedUrls, [googleSearchUrl, 'https://app.uniswap.org']);
    });

    testWidgets('URL input asks to confirm external domain before opening', (
      tester,
    ) async {
      final openedUrls = <String>[];
      await tester.pumpWidget(
        _browserHome(
          repository: InMemoryBrowserStateRepository(),
          onOpenUrl: openedUrls.add,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(find.byType(TextField), 'app.uniswap.org');
      await tester.tap(find.byIcon(AppIcons.forward));
      await tester.pumpAndSettle();

      expect(openedUrls, isEmpty);
      expect(find.text('确认打开网站'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('app.uniswap.org'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(openedUrls, isEmpty);

      await tester.tap(find.byIcon(AppIcons.forward));
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(openedUrls, ['https://app.uniswap.org']);
    });

    testWidgets('catalog dApp asks to confirm external domain before opening', (
      tester,
    ) async {
      final openedUrls = <String>[];
      await tester.pumpWidget(
        _browserHome(
          repository: InMemoryBrowserStateRepository(),
          onOpenUrl: openedUrls.add,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Swap'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'uniswap');
      await tester.pump();

      await tester.tap(find.text('Uniswap'));
      await tester.pumpAndSettle();

      expect(openedUrls, isEmpty);
      expect(find.text('确认打开网站'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('app.uniswap.org'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(openedUrls, isEmpty);

      await tester.tap(find.text('Uniswap'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(openedUrls, ['https://app.uniswap.org']);
    });

    testWidgets('URL input filters dApp catalog by name', (tester) async {
      await tester.pumpWidget(
        _browserHome(
          repository: InMemoryBrowserStateRepository(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Swap'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'pancake');
      await tester.pump();

      expect(find.text('PancakeSwap'), findsOneWidget);
      expect(find.text('Uniswap'), findsNothing);
      expect(find.text('Curve'), findsNothing);
    });

    testWidgets('pump.fun is labeled as high-risk Meme trading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _browserHome(
          repository: InMemoryBrowserStateRepository(),
          chainRepository: _FakeChainRepository(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Swap'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'pump.fun');
      await tester.pump();

      final pumpTile = find.widgetWithText(ListTile, 'pump.fun');
      expect(pumpTile, findsOneWidget);
      expect(
        find.descendant(of: pumpTile, matching: find.textContaining('Meme')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pumpTile, matching: find.textContaining('高风险')),
        findsOneWidget,
      );
    });

    testWidgets('Swap entries can be filtered by chain and type', (
      tester,
    ) async {
      await tester.pumpWidget(
        _browserHome(
          repository: InMemoryBrowserStateRepository(),
          chainRepository: _FakeChainRepository(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Swap'));
      await tester.pumpAndSettle();

      final networkFilter = find.byKey(const Key('swapNetworkFilter'));
      final typeFilter = find.byKey(const Key('swapTypeFilter'));
      expect(networkFilter, findsOneWidget);
      expect(typeFilter, findsOneWidget);
      expect(
        tester.getTopLeft(networkFilter).dy,
        tester.getTopLeft(typeFilter).dy,
      );
      expect(find.byType(ChoiceChip), findsNothing);

      await tester.tap(networkFilter);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('chainSelectorSheetDragHandle')),
        findsOneWidget,
      );
      final networkList = find.byKey(const Key('chainSelectorList'));
      await tester.drag(networkList, const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Solana Mainnet'));
      await tester.tap(find.text('Solana Mainnet'));
      await tester.pumpAndSettle();

      expect(find.text('Jupiter'), findsOneWidget);
      expect(find.text('1inch'), findsNothing);

      await tester.tap(typeFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('DEX').last);
      await tester.pumpAndSettle();

      expect(find.text('Raydium'), findsOneWidget);
      expect(find.text('Jupiter'), findsNothing);
    });

    testWidgets('Solana internal dApp test entry opens local test page', (
      tester,
    ) async {
      final repository = InMemoryBrowserStateRepository();
      await repository.saveFavoriteDappIds({solanaDappTestId});
      await tester.pumpWidget(
        _browserHome(
          repository: repository,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.enterText(find.byType(TextField), 'solana');
      await tester.pump();

      expect(find.text('Solana dApp 测试'), findsOneWidget);

      await tester.tap(find.text('Solana dApp 测试'));
      await tester.pumpAndSettle();

      expect(find.text('Solana dApp 测试'), findsWidgets);
      expect(find.text('Solana dApp 接口预留'), findsOneWidget);
    });
  });
}

Widget _browserHome({
  required BrowserStateRepository repository,
  ValueChanged<String>? onOpenUrl,
  ChainRepository? chainRepository,
  WalletRepository? walletRepository,
}) {
  return ProviderScope(
    overrides: [
      browserStateRepositoryProvider.overrideWithValue(repository),
      if (chainRepository != null)
        chainRepositoryProvider.overrideWithValue(chainRepository),
      if (walletRepository != null)
        walletRepositoryProvider.overrideWithValue(walletRepository),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: BrowserHomePage(onOpenUrl: onOpenUrl),
        ),
      ),
    ),
  );
}

final class _FakeChainRepository implements ChainRepository {
  @override
  Future<List<ChainConfig>> getChains() async => defaultChains;

  @override
  Future<ChainConfig> getSelectedChain() async {
    return defaultChains.firstWhere((chain) => chain.id == 'solana-devnet');
  }

  @override
  Future<ChainConfig> addCustomEvmChain({
    required String name,
    required String chainId,
    required String rpcUrl,
    required String symbol,
    String? blockExplorerUrl,
    bool isTestnet = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChainConfig> selectChain(String chainId) {
    throw UnimplementedError();
  }
}

final class _FakeWalletRepository implements WalletRepository {
  @override
  Future<List<WalletAccount>> getWallets() async => [
        WalletAccount(
          id: 'wallet-1',
          name: 'Wallet 1',
          evmAddress: '0x1111111111111111111111111111111111111111',
          solanaAddress: 'So11111111111111111111111111111111111111112',
          createdAt: DateTime.utc(2026, 6, 6),
          updatedAt: DateTime.utc(2026, 6, 6),
        ),
      ];

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
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) {
    throw UnimplementedError();
  }
}

ProviderContainer _container(BrowserStateRepository repository) {
  final container = ProviderContainer(
    overrides: [
      browserStateRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<BrowserStateRepository> _createRepository(
  Directory directory, {
  int maxRecentVisits = 8,
}) async {
  final initializer = StorageInitializer(path: directory.path);
  final registry = await initializer.initialize();
  return HiveBrowserStateRepository(
    registry: registry,
    maxRecentVisits: maxRecentVisits,
  );
}

Future<BrowserStateRepository> _reopenRepository(
  Directory directory, {
  int maxRecentVisits = 8,
}) async {
  await Hive.close();
  return _createRepository(directory, maxRecentVisits: maxRecentVisits);
}
