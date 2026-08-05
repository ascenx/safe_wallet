import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_input_borders.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_action_sheet.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../chains/data/default_chains.dart';
import '../../chains/presentation/chain_selector_page.dart';
import '../../dapp/presentation/solana_dapp_test_page.dart';
import '../application/dapp_catalog_provider.dart';
import '../application/dapp_favorites_controller.dart';
import '../application/dapp_recent_visits_controller.dart';
import '../data/dapp_icon_assets.dart';
import '../domain/dapp_entry.dart';
import '../domain/dapp_recent_visit.dart';
import '../domain/internal_dapp_routes.dart';
import 'dapp_browser_page.dart';

final class BrowserHomePage extends ConsumerStatefulWidget {
  const BrowserHomePage({this.onOpenUrl, super.key});

  final ValueChanged<String>? onOpenUrl;

  @override
  ConsumerState<BrowserHomePage> createState() => _BrowserHomePageState();
}

final class _BrowserHomePageState extends ConsumerState<BrowserHomePage> {
  final _urlController = TextEditingController();
  late final Future<int> _initialTabIndexFuture;
  String? _urlError;
  String _filterText = '';
  String? _selectedSwapChainId;
  DappSwapType? _selectedSwapType;

  @override
  void initState() {
    super.initState();
    _initialTabIndexFuture = _loadInitialTabIndex();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(dappCatalogProvider);
    final recent = ref.watch(dappRecentVisitsControllerProvider);
    final favoriteVisits = ref.watch(dappFavoriteVisitsControllerProvider);

    return FutureBuilder<int>(
      future: _initialTabIndexFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SafeArea(
            bottom: false,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return DefaultTabController(
          length: 6,
          initialIndex: snapshot.data!,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageX,
                    18,
                    AppSpacing.pageX,
                    0,
                  ),
                  child: TextField(
                    key: const Key('browserSearchField'),
                    spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                    autocorrect: false,
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    onChanged: (value) {
                      setState(() {
                        _filterText = value.trim().toLowerCase();
                        _urlError = null;
                      });
                    },
                    onSubmitted: (_) => _openInputUrl(),
                    decoration: InputDecoration(
                      border: AppInputBorders.pill(context),
                      enabledBorder: AppInputBorders.pill(context),
                      focusedBorder: AppInputBorders.pillFocused(context),
                      errorBorder: AppInputBorders.pillError,
                      focusedErrorBorder: AppInputBorders.pillError,
                      hintText: t.browser.urlHint,
                      errorText: _urlError,
                      prefixIcon: const Icon(AppIcons.search, size: 20),
                      suffixIcon: IconButton(
                        onPressed: _openInputUrl,
                        icon: const Icon(AppIcons.forward, size: 20),
                        tooltip: t.actions.confirm,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TabBar(
                  key: const Key('browserCategoryTabBar'),
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: context.appColors.textSecondary,
                  labelStyle: context.appTextStyles.bodyLarge,
                  unselectedLabelStyle: context.appTextStyles.bodyMedium,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: context.appColors.divider,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tabs: [
                    Tab(height: 44, text: t.browser.recent),
                    Tab(height: 44, text: t.browser.favorites),
                    Tab(
                      key: const Key('browserSwapCategoryTab'),
                      height: 44,
                      text: t.browser.swap,
                    ),
                    Tab(height: 44, text: t.browser.predictions),
                    Tab(height: 44, text: t.browser.staking),
                    Tab(height: 44, text: t.browser.bridge),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    key: const Key('browserCategoryTabView'),
                    children: [
                      _recentTab(recent, catalog, favoriteVisits),
                      _favoritesTab(catalog, favoriteVisits),
                      _swapTab(catalog, key: const Key('browserSwapTab')),
                      _catalogTab(
                        catalog,
                        key: const Key('browserPredictionsTab'),
                        category: DappCategory.predictions,
                      ),
                      _catalogTab(
                        catalog,
                        key: const Key('browserStakingTab'),
                        category: DappCategory.staking,
                      ),
                      _catalogTab(
                        catalog,
                        key: const Key('browserBridgeTab'),
                        category: DappCategory.bridge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int> _loadInitialTabIndex() async {
    try {
      final favoriteDappIdsFuture = ref.read(
        dappFavoritesControllerProvider.future,
      );
      final favoriteVisitsFuture = ref.read(
        dappFavoriteVisitsControllerProvider.future,
      );
      final favoriteDappIds = await favoriteDappIdsFuture;
      final favoriteVisits = await favoriteVisitsFuture;
      return favoriteDappIds.isNotEmpty || favoriteVisits.isNotEmpty ? 1 : 2;
    } catch (_) {
      return 2;
    }
  }

  Widget _recentTab(
    AsyncValue<List<DappRecentVisit>> recent,
    AsyncValue<List<DappEntry>> catalog,
    AsyncValue<List<DappRecentVisit>> favoriteVisits,
  ) {
    if (recent.hasError || catalog.hasError || favoriteVisits.hasError) {
      return _StatusText(t.errors.unknown);
    }
    if (!recent.hasValue || !catalog.hasValue || !favoriteVisits.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    final entries = catalog.value ?? const <DappEntry>[];
    final savedVisits = favoriteVisits.value ?? const <DappRecentVisit>[];
    final filteredVisits = _filteredVisits(
      recent.value ?? const <DappRecentVisit>[],
    );
    return _BrowserTabList(
      key: const Key('browserRecentTab'),
      emptyText: _filterText.isEmpty
          ? t.browser.emptyRecent
          : t.browser.noResults,
      children: [
        for (final visit in filteredVisits)
          _RecentTile(
            visit: visit,
            isFavorite: _isRecentVisitFavorite(
              visit,
              entries: entries,
              favoriteVisits: savedVisits,
            ),
            onOpen: () => _openRecentVisit(visit),
            onToggleFavorite: () => _toggleRecentFavorite(visit, entries),
          ),
      ],
    );
  }

  Widget _favoritesTab(
    AsyncValue<List<DappEntry>> catalog,
    AsyncValue<List<DappRecentVisit>> favoriteVisits,
  ) {
    if (catalog.hasError || favoriteVisits.hasError) {
      return _StatusText(t.errors.unknown);
    }
    if (!catalog.hasValue || !favoriteVisits.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    final catalogFavorites = _filteredEntries(
      catalog.value ?? const <DappEntry>[],
    ).where((entry) => entry.isFavorite).toList();
    final catalogFavoriteDomains = {
      for (final entry in catalogFavorites) Uri.parse(entry.url).host,
    };
    final savedVisits = _filteredVisits(
      favoriteVisits.value ?? const <DappRecentVisit>[],
    ).where((visit) => !catalogFavoriteDomains.contains(visit.domain)).toList();
    return _BrowserTabList(
      key: const Key('browserFavoritesTab'),
      emptyText: _filterText.isEmpty
          ? t.browser.emptyFavorites
          : t.browser.noResults,
      children: [
        for (final entry in catalogFavorites)
          _DappTile(
            entry: entry,
            title: _entryTitle(entry),
            chainLabelsById: _defaultChainLabelsById,
            onOpen: () => _openDapp(entry),
            onToggleFavorite: () => ref
                .read(dappFavoritesControllerProvider.notifier)
                .toggleFavorite(entry.id),
          ),
        for (final visit in savedVisits)
          _RecentTile(
            visit: visit,
            isFavorite: true,
            onOpen: () => _openRecentVisit(visit),
            onToggleFavorite: () => ref
                .read(dappFavoriteVisitsControllerProvider.notifier)
                .toggle(visit),
          ),
      ],
    );
  }

  Widget _catalogTab(
    AsyncValue<List<DappEntry>> catalog, {
    required Key key,
    required DappCategory category,
  }) {
    return catalog.when(
      data: (entries) {
        final filteredEntries = _filteredEntries(entries).where((entry) {
          return entry.category == category;
        }).toList();
        return _BrowserTabList(
          key: key,
          emptyText: t.browser.noResults,
          children: [
            for (final entry in filteredEntries)
              _DappTile(
                entry: entry,
                title: _entryTitle(entry),
                chainLabelsById: _defaultChainLabelsById,
                onOpen: () => _openDapp(entry),
                onToggleFavorite: () => ref
                    .read(dappFavoritesControllerProvider.notifier)
                    .toggleFavorite(entry.id),
              ),
          ],
        );
      },
      error: (_, _) => _StatusText(t.errors.unknown),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _swapTab(AsyncValue<List<DappEntry>> catalog, {required Key key}) {
    return catalog.when(
      data: (entries) {
        final filteredEntries = _filteredEntries(entries).where((entry) {
          if (entry.category != DappCategory.swap) {
            return false;
          }
          final selectedChainId = _selectedSwapChainId;
          if (selectedChainId != null &&
              !entry.supportedChainIds.contains(selectedChainId)) {
            return false;
          }
          final selectedType = _selectedSwapType;
          return selectedType == null || entry.swapType == selectedType;
        }).toList();
        return _BrowserTabList(
          key: key,
          emptyText: t.browser.noResults,
          children: [
            _SwapFilters(
              networkLabel: _selectedSwapNetworkLabel,
              typeLabel: _selectedSwapTypeLabel,
              onSelectNetwork: _selectSwapNetwork,
              onSelectType: _selectSwapType,
            ),
            const SizedBox(height: 12),
            if (filteredEntries.isEmpty)
              _StatusText(t.browser.noResults)
            else
              for (final entry in filteredEntries)
                _DappTile(
                  entry: entry,
                  title: _entryTitle(entry),
                  chainLabelsById: _defaultChainLabelsById,
                  onOpen: () => _openDapp(entry),
                  onToggleFavorite: () => ref
                      .read(dappFavoritesControllerProvider.notifier)
                      .toggleFavorite(entry.id),
                ),
          ],
        );
      },
      error: (_, _) => _StatusText(t.errors.unknown),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  String get _selectedSwapNetworkLabel {
    final selectedChainId = _selectedSwapChainId;
    if (selectedChainId == null) {
      return t.browser.allNetworks;
    }
    return _defaultChainLabelsById[selectedChainId] ?? selectedChainId;
  }

  String get _selectedSwapTypeLabel {
    final selectedType = _selectedSwapType;
    return selectedType == null
        ? t.browser.allTypes
        : _swapTypeLabel(selectedType);
  }

  Future<void> _selectSwapNetwork() async {
    var selectedAll = false;
    final selectedChain = await showChainSelectorSheet(
      context,
      selectCurrentChain: false,
      title: t.browser.selectNetwork,
      filter: (chain) =>
          !chain.isTestnet && _swapSupportedChainIds.contains(chain.chainId),
      allOptionTitle: t.browser.allNetworks,
      allOptionSelected: _selectedSwapChainId == null,
      onSelectAll: () {
        selectedAll = true;
      },
    );
    if (!mounted) {
      return;
    }
    if (selectedAll) {
      setState(() {
        _selectedSwapChainId = null;
      });
      return;
    }
    if (selectedChain != null) {
      setState(() {
        _selectedSwapChainId = selectedChain.chainId;
      });
    }
  }

  Future<void> _selectSwapType() async {
    final selection = await showAppActionSheet<_SwapTypeFilter>(
      context,
      title: t.browser.selectType,
      actions: [
        AppActionSheetAction(
          value: _SwapTypeFilter.all,
          title: t.browser.allTypes,
          icon: AppIcons.apps,
          isSelected: _selectedSwapType == null,
        ),
        for (final type in DappSwapType.values)
          AppActionSheetAction(
            value: _SwapTypeFilter.fromType(type),
            title: _swapTypeLabel(type),
            icon: _swapTypeIcon(type),
            isSelected: _selectedSwapType == type,
          ),
      ],
    );
    if (!mounted || selection == null) {
      return;
    }
    setState(() {
      _selectedSwapType = selection.type;
    });
  }

  List<DappEntry> _filteredEntries(List<DappEntry> entries) {
    final query = _filterText;
    if (query.isEmpty) {
      return entries;
    }
    return entries.where((entry) {
      final searchableText = [
        entry.name,
        entry.url,
        entry.category.name,
        if (entry.swapType != null) entry.swapType!.name,
        entry.riskLevel.name,
        ...entry.supportedChainIds,
      ].join(' ').toLowerCase();
      return searchableText.contains(query);
    }).toList();
  }

  List<DappRecentVisit> _filteredVisits(List<DappRecentVisit> visits) {
    final query = _filterText;
    if (query.isEmpty) {
      return visits;
    }
    return visits.where((visit) {
      return '${visit.title} ${visit.domain} ${visit.url}'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  bool _isRecentVisitFavorite(
    DappRecentVisit visit, {
    required List<DappEntry> entries,
    required List<DappRecentVisit> favoriteVisits,
  }) {
    final catalogEntry = _catalogEntryForVisit(entries, visit);
    if (catalogEntry != null) {
      return catalogEntry.isFavorite;
    }
    return favoriteVisits.any((favorite) => favorite.domain == visit.domain);
  }

  Future<void> _toggleRecentFavorite(
    DappRecentVisit visit,
    List<DappEntry> entries,
  ) async {
    final catalogEntry = _catalogEntryForVisit(entries, visit);
    if (catalogEntry != null) {
      await ref
          .read(dappFavoritesControllerProvider.notifier)
          .toggleFavorite(catalogEntry.id);
      return;
    }
    await ref.read(dappFavoriteVisitsControllerProvider.notifier).toggle(visit);
  }

  DappEntry? _catalogEntryForVisit(
    List<DappEntry> entries,
    DappRecentVisit visit,
  ) {
    for (final entry in entries) {
      if (Uri.parse(entry.url).host == visit.domain) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _openInputUrl() async {
    final target = resolveDappNavigationTarget(_urlController.text);
    if (target == null) {
      setState(() {
        _urlError = t.browser.invalidUrl;
      });
      return;
    }
    setState(() {
      _urlError = null;
    });
    if (!target.isSearch && !await _confirmOpenExternalUrl(target.url)) {
      return;
    }
    await ref
        .read(dappRecentVisitsControllerProvider.notifier)
        .recordVisit(title: Uri.parse(target.url).host, url: target.url);
    _openUrl(target.url);
  }

  Future<bool> _confirmOpenExternalUrl(String url) async {
    final domain = Uri.parse(url).host;
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: t.browser.confirmExternalTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.browser.confirmExternalBody),
          const SizedBox(height: 12),
          Text(domain, style: context.appTextStyles.bodyLarge),
        ],
      ),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmTitle: t.browser.openExternal,
      confirmCallback: () => Navigator.of(context).pop(true),
    );
    return confirmed == true;
  }

  Future<void> _openDapp(DappEntry entry) async {
    if (isSolanaDappTestUrl(entry.url)) {
      _openUrl(entry.url);
      return;
    }
    final confirmed = await _confirmOpenExternalUrl(entry.url);
    if (!confirmed) {
      return;
    }
    await ref
        .read(dappRecentVisitsControllerProvider.notifier)
        .recordVisit(title: _entryTitle(entry), url: entry.url);
    _openUrl(entry.url);
  }

  Future<void> _openRecentVisit(DappRecentVisit visit) async {
    await ref
        .read(dappRecentVisitsControllerProvider.notifier)
        .recordVisit(title: visit.title, url: visit.url);
    _openUrl(visit.url);
  }

  void _openUrl(String url) {
    if (isSolanaDappTestUrl(url)) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SolanaDappTestPage()),
      );
      return;
    }
    final onOpenUrl = widget.onOpenUrl;
    if (onOpenUrl != null) {
      onOpenUrl(url);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DappBrowserPage(initialUrl: url)),
    );
  }

  String _entryTitle(DappEntry entry) {
    return entry.id == solanaDappTestId ? t.dapp.solanaTestTitle : entry.name;
  }
}

final _defaultChainLabelsById = {
  for (final chain in defaultChains) ...{
    chain.id: chain.name,
    chain.chainId: chain.name,
  },
};

final class _BrowserTabList extends StatelessWidget {
  const _BrowserTabList({
    required this.children,
    required this.emptyText,
    super.key,
  });

  final List<Widget> children;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageX,
        AppSpacing.sectionY,
        AppSpacing.pageX,
        AppSpacing.bottomNavHeight + 28,
      ),
      children: children.isEmpty ? [_StatusText(emptyText)] : children,
    );
  }
}

final class _SwapFilters extends StatelessWidget {
  const _SwapFilters({
    required this.networkLabel,
    required this.typeLabel,
    required this.onSelectNetwork,
    required this.onSelectType,
  });

  final String networkLabel;
  final String typeLabel;
  final VoidCallback onSelectNetwork;
  final VoidCallback onSelectType;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DropdownFilterButton(
          key: const Key('swapNetworkFilter'),
          label: networkLabel,
          onPressed: onSelectNetwork,
        ),
        const SizedBox(width: 16),
        _DropdownFilterButton(
          key: const Key('swapTypeFilter'),
          label: typeLabel,
          onPressed: onSelectType,
        ),
      ],
    );
  }
}

final class _DropdownFilterButton extends StatelessWidget {
  const _DropdownFilterButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.appTextStyles.bodyMedium,
          ),
          const SizedBox(width: 2),
          const Icon(AppIcons.chevronDown, size: 20),
        ],
      ),
    );
  }
}

const _swapSupportedChainIds = {
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
};

enum _SwapTypeFilter {
  all(null),
  aggregator(DappSwapType.aggregator),
  dex(DappSwapType.dex),
  meme(DappSwapType.meme),
  crossChain(DappSwapType.crossChain);

  const _SwapTypeFilter(this.type);

  final DappSwapType? type;

  static _SwapTypeFilter fromType(DappSwapType type) {
    return switch (type) {
      DappSwapType.aggregator => aggregator,
      DappSwapType.dex => dex,
      DappSwapType.meme => meme,
      DappSwapType.crossChain => crossChain,
    };
  }
}

final class _DappTile extends StatelessWidget {
  const _DappTile({
    required this.entry,
    required this.title,
    required this.chainLabelsById,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  final DappEntry entry;
  final String title;
  final Map<String, String> chainLabelsById;
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      onTap: onOpen,
      leading: _DappIcon(entry: entry),
      title: title,
      subtitle: _dappSubtitle(entry, chainLabelsById),
      trailing: IconButton(
        onPressed: onToggleFavorite,
        icon: Icon(
          entry.isFavorite ? AppIcons.favoriteSelected : AppIcons.favorite,
          color: entry.isFavorite
              ? AppColors.warning
              : context.appColors.textMuted,
        ),
        tooltip: entry.isFavorite ? t.browser.unfavorite : t.browser.favorite,
      ),
    );
  }

  String _dappSubtitle(DappEntry entry, Map<String, String> chainLabelsById) {
    final host = Uri.parse(entry.url).host;
    final labels = <String>[
      if (entry.swapType != null) _swapTypeLabel(entry.swapType!),
      if (entry.riskLevel == DappRiskLevel.high) t.browser.riskHigh,
    ];
    final chainLabels = <String>[];
    for (final chainId in entry.supportedChainIds) {
      final label = chainLabelsById[chainId];
      if (label == null || chainLabels.contains(label)) {
        continue;
      }
      chainLabels.add(label);
    }
    labels.add(host);
    if (chainLabels.isNotEmpty) {
      labels.add(chainLabels.join(', '));
    }
    return labels.join(' · ');
  }
}

String _swapTypeLabel(DappSwapType type) {
  return switch (type) {
    DappSwapType.aggregator => t.browser.swapAggregator,
    DappSwapType.dex => t.browser.swapDex,
    DappSwapType.meme => t.browser.swapMeme,
    DappSwapType.crossChain => t.browser.swapCrossChain,
  };
}

IconData _swapTypeIcon(DappSwapType type) {
  return switch (type) {
    DappSwapType.aggregator => AppIcons.route,
    DappSwapType.dex => AppIcons.swap,
    DappSwapType.meme => AppIcons.fire,
    DappSwapType.crossChain => AppIcons.network,
  };
}

final class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.visit,
    required this.isFavorite,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  final DappRecentVisit visit;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      onTap: onOpen,
      leading: Icon(AppIcons.history, color: context.appColors.textMuted),
      title: visit.title,
      subtitle: visit.domain,
      trailing: IconButton(
        onPressed: onToggleFavorite,
        icon: Icon(
          isFavorite ? AppIcons.favoriteSelected : AppIcons.favorite,
          color: isFavorite ? AppColors.warning : context.appColors.textMuted,
        ),
        tooltip: isFavorite ? t.browser.unfavorite : t.browser.favorite,
      ),
    );
  }
}

final class _TileShell extends StatelessWidget {
  const _TileShell({
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: AppRadius.smallBorder,
          border: Border.all(color: context.appColors.border),
        ),
        child: ListTile(
          onTap: onTap,
          leading: leading,
          title: Text(title, style: context.appTextStyles.bodyLarge),
          subtitle: Text(subtitle, style: context.appTextStyles.caption),
          trailing: trailing,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          minLeadingWidth: 32,
        ),
      ),
    );
  }
}

final class _DappIcon extends StatelessWidget {
  const _DappIcon({required this.entry});

  final DappEntry entry;

  @override
  Widget build(BuildContext context) {
    final assetPath = dappIconAssetPath(entry);
    if (assetPath == null) {
      return _fallback();
    }
    final image = assetPath.endsWith('.svg')
        ? SvgPicture.asset(
            assetPath,
            fit: BoxFit.contain,
            semanticsLabel: entry.name,
            placeholderBuilder: (_) => _fallback(),
            errorBuilder: (_, _, _) => _fallback(),
          )
        : Image.asset(
            assetPath,
            fit: BoxFit.contain,
            semanticLabel: entry.name,
            errorBuilder: (_, _, _) => _fallback(),
          );
    return ClipRRect(
      borderRadius: AppRadius.smallBorder,
      child: ColoredBox(
        color: context.appColors.surfaceSoft,
        child: SizedBox.square(
          dimension: 36,
          child: Padding(padding: const EdgeInsets.all(3), child: image),
        ),
      ),
    );
  }

  Widget _fallback() {
    return SizedBox.square(
      dimension: 36,
      child: Center(child: _CategoryIcon(category: entry.category)),
    );
  }
}

final class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category});

  final DappCategory category;

  @override
  Widget build(BuildContext context) {
    final icon = switch (category) {
      DappCategory.swap => AppIcons.swap,
      DappCategory.predictions => AppIcons.predictions,
      DappCategory.staking => AppIcons.staking,
      DappCategory.bridge => AppIcons.route,
      DappCategory.defi => AppIcons.bank,
      DappCategory.nft => AppIcons.collection,
      DappCategory.tool => AppIcons.tools,
    };
    return Icon(icon, color: Theme.of(context).colorScheme.primary);
  }
}

final class _StatusText extends StatelessWidget {
  const _StatusText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: context.appTextStyles.bodySmall),
    );
  }
}
