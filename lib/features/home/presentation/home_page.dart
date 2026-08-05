import 'dart:async';

import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/main_shell_tab.dart';
import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_spacing.dart';
import '../../assets/application/asset_portfolio_provider.dart';
import '../../assets/application/asset_refresh_controller.dart';
import '../../assets/presentation/asset_detail_page.dart';
import '../../assets/presentation/token_management_page.dart';
import '../../browser/presentation/dapp_browser_page.dart';
import '../../chains/domain/block_explorer_url_builder.dart';
import '../../chains/presentation/chain_selector_page.dart';
import '../../transfer/presentation/transaction_history_page.dart';
import '../../transfer/presentation/transfer_page.dart';
import '../../transfer/presentation/scan_page.dart';
import '../../wallet/presentation/wallet_management_page.dart';
import '../../wallet/presentation/receive_page.dart';
import '../application/home_controller.dart';
import 'widgets/asset_list_card.dart';
import 'widgets/balance_summary_card.dart';
import 'widgets/quick_action_card.dart';
import 'widgets/recent_transactions_card.dart';
import 'widgets/wallet_top_bar.dart';

const homeAssetPollingInterval = Duration(seconds: 10);

final class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

final class _HomePageState extends ConsumerState<HomePage> {
  Timer? _pollTimer;
  var _isHomeTabActive = true;
  var _refreshInFlight = false;
  var _amountsHidden = false;

  @override
  void initState() {
    super.initState();
    _isHomeTabActive = ref.read(mainShellTabProvider) == MainShellTab.home;
    ref.listenManual<HomeState>(
      homeControllerProvider,
      _handleHomeStateChanged,
      fireImmediately: true,
    );
    ref.listenManual<MainShellTab>(
      mainShellTabProvider,
      _handleTabChanged,
      fireImmediately: false,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _handleHomeStateChanged(HomeState? previous, HomeState next) {
    if (next.assetStatus == HomeAssetStatus.loading) {
      _pollTimer?.cancel();
      return;
    }
    _resetPollingCountdown();
  }

  void _handleTabChanged(MainShellTab? previous, MainShellTab next) {
    if (next != MainShellTab.home) {
      _isHomeTabActive = false;
      _pollTimer?.cancel();
      return;
    }
    _isHomeTabActive = true;
    if (previous != MainShellTab.home) {
      unawaited(_refreshAssets());
    }
  }

  Future<void> _refreshAssets() async {
    _pollTimer?.cancel();
    if (_refreshInFlight) {
      return;
    }
    _refreshInFlight = true;
    try {
      await ref.read(assetRefreshControllerProvider.notifier).refresh();
    } finally {
      _refreshInFlight = false;
      _resetPollingCountdown();
    }
  }

  void _resetPollingCountdown() {
    _pollTimer?.cancel();
    if (!mounted || !_isHomeTabActive) {
      return;
    }
    _pollTimer = Timer(homeAssetPollingInterval, () {
      _pollTimer = null;
      unawaited(_refreshAssets());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeControllerProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageX,
              AppSpacing.sectionY,
              AppSpacing.pageX,
              0,
            ),
            child: WalletTopBar(
              walletName: state.walletName,
              chainName: state.chainName,
              chainSymbol: state.chainSymbol,
              chainLogoUri: state.chainLogoUri,
              isNodeUnavailable: state.isNodeUnavailable,
              onWalletTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WalletManagementPage(),
                  ),
                );
              },
              onChainTap: () {
                showChainSelectorSheet(context);
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAssets,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageX,
                  AppSpacing.sectionY,
                  AppSpacing.pageX,
                  32,
                ),
                children: [
                  BalanceSummaryCard(
                    totalValue: state.totalValue,
                    fiatEquivalent: state.fiatEquivalent,
                    amountsHidden: _amountsHidden,
                    onToggleAmountsVisibility: () {
                      setState(() {
                        _amountsHidden = !_amountsHidden;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.sectionY),
                  Row(
                    children: [
                      QuickActionCard(
                        icon: AppIcons.receive,
                        label: t.actions.receive,
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ReceivePage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: AppSpacing.quickActionGap),
                      QuickActionCard(
                        icon: AppIcons.send,
                        label: t.actions.send,
                        color: AppColors.success,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const TransferPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: AppSpacing.quickActionGap),
                      QuickActionCard(
                        icon: AppIcons.scan,
                        label: t.actions.scan,
                        color: AppColors.purple,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ScanPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sectionY),
                  RecentTransactionsCard(
                    transactions: state.recentTransactions,
                    onViewAll: () => _openTransactionHistory(
                      context,
                      ref,
                      hasTransactions: state.recentTransactions.isNotEmpty,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sectionY),
                  AssetListCard(
                    state: state,
                    amountsHidden: _amountsHidden,
                    onManageTokens: () => _openTokenManagement(context, ref),
                    onAssetSelected: (asset) => _openAssetDetail(
                      context,
                      asset: asset,
                      chainName: state.chainName,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTransactionHistory(
    BuildContext context,
    WidgetRef ref, {
    required bool hasTransactions,
  }) async {
    final request = await ref.read(assetPortfolioRequestProvider);
    if (!context.mounted) {
      return;
    }
    if (!hasTransactions && request != null) {
      final explorerUrl = buildBlockExplorerAddressUrl(
        chainType: request.chain.chainType,
        chainId: request.chain.chainId,
        address: request.account.addressForChainType(request.chain.chainType),
        blockExplorerUrl: request.chain.blockExplorerUrl,
      );
      if (explorerUrl != null) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DappBrowserPage(initialUrl: explorerUrl),
          ),
        );
        return;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionHistoryPage(
          chain: request?.chain,
          walletAddress: request?.account.addressForChainType(
            request.chain.chainType,
          ),
          blockExplorerUrl: request?.chain.blockExplorerUrl,
        ),
      ),
    );
  }

  Future<void> _openTokenManagement(BuildContext context, WidgetRef ref) async {
    final request = await ref.read(assetPortfolioRequestProvider);
    if (!context.mounted || request == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TokenManagementPage(
          chain: request.chain,
          rpcUrl: request.rpcNode.endpointUrl,
          rpcHeaders: request.rpcNode.endpointHeaders,
          walletAddress: request.account.addressForChainType(
            request.chain.chainType,
          ),
        ),
      ),
    );
  }

  void _openAssetDetail(
    BuildContext context, {
    required HomeAssetPreview asset,
    required String chainName,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AssetDetailPage(
          name: asset.name,
          symbol: asset.symbol,
          amount: asset.amount,
          fiatValue: asset.fiatValue,
          price: asset.price,
          priceUsd: asset.priceUsd,
          chainName: chainName,
          contractAddress: asset.contractAddress,
          logoUri: asset.logoUri,
        ),
      ),
    );
  }
}
