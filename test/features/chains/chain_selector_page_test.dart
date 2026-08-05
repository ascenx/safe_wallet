import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/chains/presentation/chain_selector_page.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

void main() {
  testWidgets('chain selector displays bundled svg logos for default chains', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_buildSelector(_FakeChainRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsNWidgets(defaultChains.length));
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('selecting a different chain returns to the previous page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeChainRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(repository),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      showChainSelectorSheet(context);
                    },
                    child: const Text('Open networks'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open networks'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
        find.byKey(const Key('chainSelectorSheetDragHandle')), findsOneWidget);
    final handlePadding = tester.widget<Padding>(
      find.byKey(const Key('chainSelectorSheetDragHandle')),
    );
    expect(
      handlePadding.padding,
      const EdgeInsets.symmetric(vertical: 12),
    );

    await tester.scrollUntilVisible(find.text('Solana Mainnet'), 200);
    await tester.ensureVisible(find.text('Solana Mainnet'));
    expect(find.text('Solana Mainnet'), findsOneWidget);

    await tester.tap(find.text('Solana Mainnet'));
    await tester.pumpAndSettle();

    expect(repository.selectedChainId, 'solana-mainnet');
    expect(find.text('Open networks'), findsOneWidget);
    expect(find.text('Solana Mainnet'), findsNothing);
  });

  testWidgets('bottom sheet list keeps scroll space below the last network',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(_FakeChainRepository()),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showChainSelectorSheet(context),
                  child: const Text('Open networks'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open networks'));
    await tester.pumpAndSettle();

    final listView = tester.widget<ListView>(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(ListView),
      ),
    );
    final padding = listView.padding! as EdgeInsets;

    expect(padding.bottom, greaterThanOrEqualTo(20));
  });

  testWidgets('selecting Bitcoin updates the selected chain', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repository = _FakeChainRepository();

    await tester.pumpWidget(_buildSelector(repository));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Bitcoin'), 200);
    await tester.ensureVisible(find.text('Bitcoin'));

    await tester.tap(find.text('Bitcoin'));
    await tester.pumpAndSettle();

    expect(repository.selectedChainId, 'bitcoin-mainnet');
  });
}

Widget _buildSelector(ChainRepository repository) {
  return ProviderScope(
    overrides: [
      chainRepositoryProvider.overrideWithValue(repository),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const ChainSelectorPage(),
      ),
    ),
  );
}

final class _FakeChainRepository implements ChainRepository {
  String selectedChainId = 'ethereum';

  @override
  Future<List<ChainConfig>> getChains() async => defaultChains;

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
  Future<ChainConfig> getSelectedChain() async {
    return defaultChains.firstWhere((chain) => chain.id == selectedChainId);
  }

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    selectedChainId = chainId;
    return getSelectedChain();
  }
}
