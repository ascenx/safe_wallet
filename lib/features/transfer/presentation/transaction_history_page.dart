import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading_state.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_refresh_icon_button.dart';
import '../../../shared/network/external_url_launcher.dart';
import '../../browser/presentation/dapp_browser_page.dart';
import '../../chains/application/available_chains_provider.dart';
import '../../chains/domain/block_explorer_url_builder.dart';
import '../../chains/domain/chain_config.dart';
import '../../chains/presentation/chain_selector_page.dart';
import '../application/transaction_history_provider.dart';
import '../application/transaction_status_refresh_controller.dart';
import '../domain/transaction_record.dart';

final class TransactionHistoryPage extends ConsumerStatefulWidget {
  const TransactionHistoryPage({
    this.chainId,
    this.chain,
    this.walletAddress,
    this.blockExplorerUrl,
    this.onOpenExplorer,
    super.key,
  });

  final String? chainId;
  final ChainConfig? chain;
  final String? walletAddress;
  final String? blockExplorerUrl;
  final ValueChanged<String>? onOpenExplorer;

  @override
  ConsumerState<TransactionHistoryPage> createState() =>
      _TransactionHistoryPageState();
}

final class _TransactionHistoryPageState
    extends ConsumerState<TransactionHistoryPage> {
  late final String? _initialChainId;
  String? _selectedChainId;
  ChainConfig? _selectedChain;

  @override
  void initState() {
    super.initState();
    _initialChainId = widget.chain?.chainId ?? widget.chainId;
    _selectedChainId = _initialChainId;
    _selectedChain = widget.chain;
  }

  @override
  Widget build(BuildContext context) {
    final recordsValue = ref.watch(
      transactionHistoryProvider(_selectedChainId),
    );
    final refreshValue = ref.watch(transactionStatusRefreshControllerProvider);
    final availableChains = ref.watch(availableChainsProvider).value;
    final selectedChain =
        _selectedChain ??
        _findChainByChainId(availableChains, _selectedChainId);
    final usesInitialChain = _selectedChainId == _initialChainId;
    final selectedBlockExplorerUrl =
        selectedChain?.blockExplorerUrl ??
        (usesInitialChain ? widget.blockExplorerUrl : null);
    final isRefreshing = refreshValue.isLoading;
    final explorerUrls = _explorerUrlsByChain(availableChains ?? const []);
    final openTransactionExplorer =
        widget.onOpenExplorer ??
        (url) {
          ref.read(externalUrlLauncherProvider).openExternal(url);
        };
    final openAddressExplorer =
        widget.onOpenExplorer ??
        (url) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DappBrowserPage(initialUrl: url),
            ),
          );
        };

    return Scaffold(
      appBar: AppBar(
        title: Text(t.transactions.historyTitle),
        actions: [
          AppRefreshIconButton(
            buttonKey: const Key('refreshTransactionStatusButton'),
            spinnerKey: const Key('transactionHistoryRefreshSpinner'),
            tooltip: t.browser.refresh,
            isRefreshing: isRefreshing,
            onPressed: () {
              ref
                  .read(transactionStatusRefreshControllerProvider.notifier)
                  .refreshCurrentChain();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageX,
                16,
                AppSpacing.pageX,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _TransactionHistoryNetworkFilter(
                  key: const Key('transactionHistoryNetworkFilter'),
                  label:
                      selectedChain?.name ??
                      _selectedChainId ??
                      t.browser.allNetworks,
                  onPressed: _selectNetwork,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionY),
            Expanded(
              child: recordsValue.when(
                data: (records) {
                  final addressExplorerUrl = _addressExplorerUrl(
                    records: records,
                    chain: selectedChain,
                    chainId: _selectedChainId,
                    walletAddress: usesInitialChain
                        ? widget.walletAddress
                        : null,
                    blockExplorerUrl: selectedBlockExplorerUrl,
                    explorerUrls: explorerUrls,
                  );
                  return Column(
                    children: [
                      Expanded(
                        child: records.isEmpty
                            ? AppEmptyState(
                                icon: AppIcons.receipt,
                                message: t.transactions.empty,
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.pageX,
                                  4,
                                  AppSpacing.pageX,
                                  24,
                                ),
                                itemBuilder: (context, index) {
                                  return _TransactionRow(
                                    record: records[index],
                                    blockExplorerUrl:
                                        _explorerUrlForRecord(
                                          records[index],
                                          explorerUrls,
                                        ) ??
                                        selectedBlockExplorerUrl,
                                    onOpenExplorer: openTransactionExplorer,
                                  );
                                },
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: AppSpacing.sectionY),
                                itemCount: records.length,
                              ),
                      ),
                      if (addressExplorerUrl != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.pageX,
                            8,
                            AppSpacing.pageX,
                            16,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: AppButton.secondary(
                              key: const Key(
                                'viewMoreTransactionsOnExplorerButton',
                              ),
                              label: t.transactions.viewMoreOnExplorer,
                              icon: const Icon(AppIcons.externalLink, size: 18),
                              onPressed: () {
                                openAddressExplorer(addressExplorerUrl);
                              },
                            ),
                          ),
                        ),
                    ],
                  );
                },
                error: (error, stackTrace) =>
                    AppErrorState(message: t.transactions.loadFailed),
                loading: () => const AppLoadingState(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectNetwork() async {
    var selectedAll = false;
    final selectedChain = await showChainSelectorSheet(
      context,
      selectCurrentChain: false,
      title: t.browser.selectNetwork,
      allOptionTitle: t.browser.allNetworks,
      allOptionSelected: _selectedChainId == null,
      onSelectAll: () {
        selectedAll = true;
      },
    );
    if (!mounted) {
      return;
    }
    if (selectedAll) {
      setState(() {
        _selectedChainId = null;
        _selectedChain = null;
      });
      return;
    }
    if (selectedChain != null) {
      setState(() {
        _selectedChainId = selectedChain.chainId;
        _selectedChain = selectedChain;
      });
    }
  }
}

ChainConfig? _findChainByChainId(List<ChainConfig>? chains, String? chainId) {
  if (chains == null || chainId == null) {
    return null;
  }
  for (final chain in chains) {
    if (chain.chainId == chainId) {
      return chain;
    }
  }
  return null;
}

final class _TransactionHistoryNetworkFilter extends StatelessWidget {
  const _TransactionHistoryNetworkFilter({
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

String? _addressExplorerUrl({
  required List<TransactionRecord> records,
  required ChainConfig? chain,
  required String? chainId,
  required String? walletAddress,
  required String? blockExplorerUrl,
  required Map<String, String> explorerUrls,
}) {
  final fallbackRecord = records.firstOrNull;
  final resolvedChainType = chain?.chainType ?? fallbackRecord?.chainType;
  final resolvedChainId = chain?.chainId ?? chainId ?? fallbackRecord?.chainId;
  final resolvedAddress = walletAddress ?? fallbackRecord?.fromAddress;
  if (resolvedChainType == null ||
      resolvedChainId == null ||
      resolvedAddress == null) {
    return null;
  }
  final resolvedExplorerUrl =
      chain?.blockExplorerUrl ??
      explorerUrls[_chainKey(resolvedChainType, resolvedChainId)] ??
      blockExplorerUrl;
  return buildBlockExplorerAddressUrl(
    chainType: resolvedChainType,
    chainId: resolvedChainId,
    address: resolvedAddress,
    blockExplorerUrl: resolvedExplorerUrl,
  );
}

Map<String, String> _explorerUrlsByChain(List<ChainConfig> chains) {
  return {
    for (final chain in chains)
      if (chain.blockExplorerUrl != null)
        _chainKey(chain.chainType, chain.chainId): chain.blockExplorerUrl!,
  };
}

String? _explorerUrlForRecord(
  TransactionRecord record,
  Map<String, String> explorerUrls,
) {
  return explorerUrls[_chainKey(record.chainType, record.chainId)];
}

String _chainKey(ChainType chainType, String chainId) {
  return '${chainType.name}:$chainId';
}

final class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.record,
    required this.blockExplorerUrl,
    required this.onOpenExplorer,
  });

  final TransactionRecord record;
  final String? blockExplorerUrl;
  final ValueChanged<String>? onOpenExplorer;

  @override
  Widget build(BuildContext context) {
    final isIncoming = record.direction == TransactionDirection.incoming;
    final isTransfer = record.operation == TransactionOperation.transfer;
    final color = _statusColor(record.status);
    final transactionExplorerUrl = buildBlockExplorerTransactionUrl(
      chainType: record.chainType,
      chainId: record.chainId,
      transactionHash: record.transactionHash,
      blockExplorerUrl: blockExplorerUrl,
    );

    return AppSectionCard(
      borderRadius: AppRadius.largeBorder,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isTransfer && isIncoming
                ? context.appColors.successSoft
                : isTransfer
                ? context.appColors.dangerSoft
                : context.appColors.warningSoft,
            foregroundColor: isTransfer && isIncoming
                ? AppColors.success
                : isTransfer
                ? AppColors.danger
                : AppColors.warning,
            child: Icon(_operationIcon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_operationTitle, style: context.appTextStyles.bodyLarge),
                if (_operationDetail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _operationDetail,
                    style: context.appTextStyles.bodySmall,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${t.transfer.chain}: ${record.chainId}',
                  style: context.appTextStyles.caption,
                ),
                const SizedBox(height: 4),
                Text(
                  record.transactionHash,
                  style: context.appTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _statusLabel(record.status),
                style: context.appTextStyles.caption.copyWith(color: color),
              ),
              const SizedBox(height: 6),
              Text(
                _dateLabel(record.createdAt),
                style: context.appTextStyles.caption,
              ),
              if (transactionExplorerUrl != null) ...[
                const SizedBox(height: 6),
                IconButton(
                  onPressed: () {
                    onOpenExplorer?.call(transactionExplorerUrl);
                  },
                  icon: const Icon(AppIcons.externalLink, size: 18),
                  color: context.appColors.textMuted,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(TransactionStatus status) {
    return switch (status) {
      TransactionStatus.submitting => AppColors.warning,
      TransactionStatus.submitted => AppColors.warning,
      TransactionStatus.success => AppColors.success,
      TransactionStatus.failed => AppColors.danger,
    };
  }

  IconData get _operationIcon {
    return switch (record.operation) {
      TransactionOperation.transfer =>
        record.direction == TransactionDirection.incoming
            ? AppIcons.receive
            : AppIcons.send,
      TransactionOperation.wrap || TransactionOperation.unwrap => AppIcons.swap,
      TransactionOperation.stake => AppIcons.staking,
      TransactionOperation.unstake ||
      TransactionOperation.withdrawUnfreeze ||
      TransactionOperation.cancelUnfreeze => AppIcons.pending,
      TransactionOperation.delegateResource ||
      TransactionOperation.undelegateResource => AppIcons.network,
      TransactionOperation.vote => AppIcons.checkCircle,
      TransactionOperation.claimReward => AppIcons.receive,
    };
  }

  String get _operationTitle {
    return switch (record.operation) {
      TransactionOperation.transfer =>
        record.direction == TransactionDirection.incoming
            ? t.transactions.incoming
            : t.transactions.outgoing,
      TransactionOperation.wrap => t.transactions.operationWrap,
      TransactionOperation.unwrap => t.transactions.operationUnwrap,
      TransactionOperation.stake => t.transactions.operationStake,
      TransactionOperation.unstake => t.transactions.operationUnstake,
      TransactionOperation.withdrawUnfreeze =>
        t.transactions.operationWithdrawUnfreeze,
      TransactionOperation.cancelUnfreeze =>
        t.transactions.operationCancelUnfreeze,
      TransactionOperation.delegateResource =>
        t.transactions.operationDelegateResource,
      TransactionOperation.undelegateResource =>
        t.transactions.operationUndelegateResource,
      TransactionOperation.vote => t.transactions.operationVote,
      TransactionOperation.claimReward => t.transactions.operationClaimReward,
    };
  }

  String get _operationDetail {
    if (record.operation == TransactionOperation.wrap ||
        record.operation == TransactionOperation.unwrap) {
      return '${record.amount} ${record.assetSymbol} → ${record.resource ?? ''}';
    }
    final parts = <String>[
      if (record.amount.isNotEmpty) '${record.amount} ${record.assetSymbol}',
      if (record.resource != null)
        switch (record.resource) {
          'BANDWIDTH' => t.tronStaking.bandwidth,
          'ENERGY' => t.tronStaking.energy,
          _ => record.resource!,
        },
    ];
    return parts.join(' · ');
  }

  String _statusLabel(TransactionStatus status) {
    return switch (status) {
      TransactionStatus.submitting => t.transactions.submitting,
      TransactionStatus.submitted => t.transactions.submitted,
      TransactionStatus.success => t.transactions.success,
      TransactionStatus.failed => t.transactions.failed,
    };
  }

  String _dateLabel(DateTime value) {
    final localValue = value.toLocal();
    return '${localValue.month.toString().padLeft(2, '0')}-'
        '${localValue.day.toString().padLeft(2, '0')} '
        '${localValue.hour.toString().padLeft(2, '0')}:'
        '${localValue.minute.toString().padLeft(2, '0')}:'
        '${localValue.second.toString().padLeft(2, '0')}';
  }
}
