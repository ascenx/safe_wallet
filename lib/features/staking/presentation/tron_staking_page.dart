import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/wallet.dart' show isValidTronAddress;

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_icons.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_action_sheet.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading_state.dart';
import '../../../shared/widgets/app_picker_field.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../../shared/widgets/risk_notice.dart';
import '../../chains/domain/chain_config.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/domain/wallet_account.dart';
import '../../wallet/presentation/signing_password_sheet.dart';
import '../application/tron_staking_action_controller.dart';
import '../application/tron_staking_dashboard_controller.dart';
import '../data/tron_staking_fee_service.dart';
import '../domain/tron_staking_action.dart';
import '../domain/tron_staking_models.dart';

final class TronStakingPage extends ConsumerWidget {
  const TronStakingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(tronStakingDashboardControllerProvider);
    ref.listen(tronStakingActionControllerProvider, (previous, next) {
      if (previous?.status == next.status) {
        return;
      }
      if (next.status == TronStakingActionStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.tronStaking.submitted)),
        );
        ref.read(tronStakingDashboardControllerProvider.notifier).refresh();
      } else if (next.status == TronStakingActionStatus.failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_actionError(context, next.error))),
        );
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.tronStaking.title),
        actions: [
          IconButton(
            key: const Key('refreshTronStaking'),
            tooltip: context.t.tronStaking.refresh,
            onPressed: dashboard.isLoading
                ? null
                : () => ref
                      .read(tronStakingDashboardControllerProvider.notifier)
                      .refresh(),
            icon: const Icon(AppIcons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: dashboard.when(
          skipError: true,
          skipLoadingOnRefresh: dashboard.hasValue,
          loading: () => const AppLoadingState(),
          error: (_, _) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppErrorState(message: context.t.tronStaking.loadFailed),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageX,
                ),
                child: AppButton.secondary(
                  key: const Key('retryTronStakingDashboard'),
                  label: context.t.tronStaking.refresh,
                  onPressed: () =>
                      ref.invalidate(tronStakingDashboardControllerProvider),
                ),
              ),
            ],
          ),
          data: (state) {
            if (state.wallets.isEmpty) {
              return AppEmptyState(
                icon: AppIcons.wallet,
                message: context.t.tronStaking.noWallet,
              );
            }
            if (state.networks.isEmpty) {
              return AppEmptyState(
                icon: AppIcons.network,
                message: context.t.tronStaking.noNetwork,
              );
            }
            final overview = state.overview;
            if (overview == null ||
                state.selectedWallet == null ||
                state.selectedNetwork == null ||
                state.rpcNode == null) {
              return AppErrorState(message: context.t.tronStaking.loadFailed);
            }
            return RefreshIndicator(
              onRefresh: () => ref
                  .read(tronStakingDashboardControllerProvider.notifier)
                  .refresh(),
              child: _DashboardContent(
                state: state,
                overview: overview,
                onSelectWallet: () => _selectWallet(context, ref, state),
                onSelectNetwork: () => _selectNetwork(context, ref, state),
                onStake: () =>
                    _showAmountAction(context, ref, state, isStake: true),
                onUnstake: () =>
                    _showAmountAction(context, ref, state, isStake: false),
                onWithdraw: () => _confirmSimpleAction(
                  context,
                  ref,
                  state,
                  const TronWithdrawUnfreezeAction(),
                ),
                onCancelAll: () => _confirmSimpleAction(
                  context,
                  ref,
                  state,
                  const TronCancelAllUnfreezeAction(),
                ),
                onDelegate: () => _showDelegateAction(context, ref, state),
                onUndelegate: (delegation, resource) => _showUndelegateAction(
                  context,
                  ref,
                  state,
                  delegation,
                  resource,
                ),
                onVote: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _TronVotePage(state: state),
                  ),
                ),
                onClaimReward: () => _confirmSimpleAction(
                  context,
                  ref,
                  state,
                  const TronClaimRewardAction(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _selectWallet(
    BuildContext context,
    WidgetRef ref,
    TronStakingDashboardState state,
  ) async {
    final selected = await showAppActionSheet<WalletAccount>(
      context,
      title: context.t.tronStaking.wallet,
      actions: state.wallets
          .map(
            (wallet) => AppActionSheetAction(
              value: wallet,
              title: wallet.name,
              subtitle: _shortAddress(wallet.tronAddress),
              icon: AppIcons.wallet,
              isSelected: wallet.id == state.selectedWalletId,
            ),
          )
          .toList(growable: false),
    );
    if (selected != null && context.mounted) {
      await ref
          .read(tronStakingDashboardControllerProvider.notifier)
          .selectWallet(selected.id);
    }
  }

  Future<void> _selectNetwork(
    BuildContext context,
    WidgetRef ref,
    TronStakingDashboardState state,
  ) async {
    final selected = await showAppActionSheet<ChainConfig>(
      context,
      title: context.t.tronStaking.network,
      actions: state.networks
          .map(
            (network) => AppActionSheetAction(
              value: network,
              title: network.name,
              subtitle: network.chainId,
              icon: AppIcons.network,
              isSelected: network.id == state.selectedNetworkId,
            ),
          )
          .toList(growable: false),
    );
    if (selected != null && context.mounted) {
      await ref
          .read(tronStakingDashboardControllerProvider.notifier)
          .selectNetwork(selected.id);
    }
  }
}

final class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.state,
    required this.overview,
    required this.onSelectWallet,
    required this.onSelectNetwork,
    required this.onStake,
    required this.onUnstake,
    required this.onWithdraw,
    required this.onCancelAll,
    required this.onDelegate,
    required this.onUndelegate,
    required this.onVote,
    required this.onClaimReward,
  });

  final TronStakingDashboardState state;
  final TronStakingOverview overview;
  final VoidCallback onSelectWallet;
  final VoidCallback onSelectNetwork;
  final VoidCallback onStake;
  final VoidCallback onUnstake;
  final VoidCallback onWithdraw;
  final VoidCallback onCancelAll;
  final VoidCallback onDelegate;
  final void Function(TronDelegation, TronResourceType) onUndelegate;
  final VoidCallback onVote;
  final VoidCallback onClaimReward;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.tronStaking;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageX,
        16,
        AppSpacing.pageX,
        24,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: AppPickerField(
                label: strings.wallet,
                value: state.selectedWallet!.name,
                leading: const Icon(AppIcons.wallet),
                onTap: onSelectWallet,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppPickerField(
                label: strings.network,
                value: state.selectedNetwork!.name,
                leading: const Icon(AppIcons.network),
                onTap: onSelectNetwork,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionY),
        _BalanceCard(overview: overview),
        const SizedBox(height: AppSpacing.sectionY),
        Row(
          children: [
            Expanded(
              child: AppButton.primary(
                key: const Key('tronStakeButton'),
                label: strings.stake,
                icon: const Icon(AppIcons.staking),
                onPressed: onStake,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton.secondary(
                key: const Key('tronUnstakeButton'),
                label: strings.unstake,
                onPressed: onUnstake,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton.secondary(
                key: const Key('tronDelegateButton'),
                label: strings.delegate,
                onPressed: overview.delegateResourceSupported
                    ? onDelegate
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton.secondary(
                key: const Key('tronVoteButton'),
                label: strings.vote,
                onPressed: onVote,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sectionY),
        _ResourceCard(overview: overview),
        const SizedBox(height: AppSpacing.sectionY),
        _PendingCard(
          overview: overview,
          onWithdraw: onWithdraw,
          onCancelAll: onCancelAll,
        ),
        const SizedBox(height: AppSpacing.sectionY),
        _DelegationCard(
          delegations: state.delegations,
          onUndelegate: onUndelegate,
        ),
        const SizedBox(height: AppSpacing.sectionY),
        _RewardCard(
          overview: overview,
          onVote: onVote,
          onClaimReward: onClaimReward,
        ),
      ],
    );
  }
}

final class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.overview});

  final TronStakingOverview overview;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.tronStaking;
    return AppSectionCard(
      borderRadius: AppRadius.largeBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Metric(
            label: strings.availableBalance,
            value: '${sunToTrx(overview.availableBalanceSun)} TRX',
            prominent: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: strings.bandwidthStaked,
                  value: '${sunToTrx(overview.bandwidthStakedSun)} TRX',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: strings.energyStaked,
                  value: '${sunToTrx(overview.energyStakedSun)} TRX',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: strings.tronPower,
                  value: overview.tronPower.toString(),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: strings.availableVotes,
                  value: overview.availableVotes.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.overview});

  final TronStakingOverview overview;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.tronStaking;
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.resourceOverview, style: context.appTextStyles.titleMedium),
          const SizedBox(height: 12),
          _ResourceLine(
            label: strings.bandwidth,
            available: overview.availableBandwidth,
            used: overview.bandwidthUsed,
            limit: overview.bandwidthLimit,
          ),
          const SizedBox(height: 12),
          _ResourceLine(
            label: strings.energy,
            available: overview.availableEnergy,
            used: overview.energyUsed,
            limit: overview.energyLimit,
          ),
        ],
      ),
    );
  }
}

final class _ResourceLine extends StatelessWidget {
  const _ResourceLine({
    required this.label,
    required this.available,
    required this.used,
    required this.limit,
  });

  final String label;
  final int available;
  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final progress = limit <= 0 ? 0.0 : (available / limit).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: context.appTextStyles.bodyLarge)),
            Flexible(
              child: Text(
                context.t.tronStaking.availableResource(
                  available: available,
                  used: used,
                  limit: limit,
                ),
                textAlign: TextAlign.end,
                style: context.appTextStyles.caption,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: progress),
      ],
    );
  }
}

final class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.overview,
    required this.onWithdraw,
    required this.onCancelAll,
  });

  final TronStakingOverview overview;
  final VoidCallback onWithdraw;
  final VoidCallback onCancelAll;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.tronStaking;
    final nextExpiry = overview.pendingUnfreezes.fold<DateTime?>(
      null,
      (current, item) => current == null || item.expiresAt.isBefore(current)
          ? item.expiresAt
          : current,
    );
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.pendingUnfreeze, style: context.appTextStyles.titleMedium),
          const SizedBox(height: 10),
          Text(
            strings.pendingTotal(amount: sunToTrx(overview.pendingUnfreezeSun)),
            style: context.appTextStyles.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            strings.withdrawableAmount(
              amount: sunToTrx(overview.withdrawableSun),
            ),
            style: context.appTextStyles.bodySmall,
          ),
          if (nextExpiry != null) ...[
            const SizedBox(height: 4),
            Text(
              strings.nextUnfreezeAt(date: _date(nextExpiry)),
              style: context.appTextStyles.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          if (overview.pendingUnfreezes.isEmpty)
            Text(strings.pendingEmpty, style: context.appTextStyles.bodySmall)
          else
            for (final item in overview.pendingUnfreezes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_resourceLabel(context, item.resource)} · '
                        '${sunToTrx(item.amountSun)} TRX',
                        style: context.appTextStyles.bodyMedium,
                      ),
                    ),
                    Text(
                      strings.expiresAt(date: _date(item.expiresAt)),
                      style: context.appTextStyles.caption,
                    ),
                  ],
                ),
              ),
          if (overview.withdrawableSun > BigInt.zero) ...[
            const SizedBox(height: 8),
            AppButton.primary(
              label: strings.withdraw(
                amount: sunToTrx(overview.withdrawableSun),
              ),
              onPressed: onWithdraw,
            ),
          ],
          if (overview.cancelAllUnfreezeSupported &&
              overview.pendingUnfreezes.isNotEmpty) ...[
            const SizedBox(height: 8),
            AppButton.text(label: strings.cancelAll, onPressed: onCancelAll),
          ],
        ],
      ),
    );
  }
}

final class _DelegationCard extends StatelessWidget {
  const _DelegationCard({
    required this.delegations,
    required this.onUndelegate,
  });

  final List<TronDelegation> delegations;
  final void Function(TronDelegation, TronResourceType) onUndelegate;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.tronStaking;
    final now = DateTime.now().toUtc();
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.delegations, style: context.appTextStyles.titleMedium),
          const SizedBox(height: 10),
          if (delegations.isEmpty)
            Text(strings.delegationsEmpty, style: context.appTextStyles.bodySmall)
          else
            for (final delegation in delegations) ...[
              Text(
                '${delegation.direction == TronDelegationDirection.outgoing ? strings.delegatedTo : strings.receivedFrom} '
                '${_shortAddress(delegation.counterpartyAddress)}',
                style: context.appTextStyles.bodyMedium,
              ),
              if (delegation.bandwidthSun > BigInt.zero)
                _DelegatedResourceRow(
                  label: strings.bandwidth,
                  amountSun: delegation.bandwidthSun,
                  expiresAt: delegation.bandwidthExpiresAt,
                  canUndelegate:
                      delegation.direction ==
                          TronDelegationDirection.outgoing &&
                      delegation.bandwidthExpiresAt?.isAfter(now) != true,
                  onUndelegate: () =>
                      onUndelegate(delegation, TronResourceType.bandwidth),
                ),
              if (delegation.energySun > BigInt.zero)
                _DelegatedResourceRow(
                  label: strings.energy,
                  amountSun: delegation.energySun,
                  expiresAt: delegation.energyExpiresAt,
                  canUndelegate:
                      delegation.direction ==
                          TronDelegationDirection.outgoing &&
                      delegation.energyExpiresAt?.isAfter(now) != true,
                  onUndelegate: () =>
                      onUndelegate(delegation, TronResourceType.energy),
                ),
              const Divider(),
            ],
        ],
      ),
    );
  }
}

final class _DelegatedResourceRow extends StatelessWidget {
  const _DelegatedResourceRow({
    required this.label,
    required this.amountSun,
    required this.canUndelegate,
    required this.expiresAt,
    required this.onUndelegate,
  });

  final String label;
  final BigInt amountSun;
  final bool canUndelegate;
  final DateTime? expiresAt;
  final VoidCallback onUndelegate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label · ${sunToTrx(amountSun)} TRX',
                style: context.appTextStyles.bodySmall,
              ),
              if (expiresAt != null)
                Text(
                  context.t.tronStaking.expiresAt(date: _date(expiresAt!)),
                  style: context.appTextStyles.caption,
                ),
            ],
          ),
        ),
        if (canUndelegate)
          TextButton(
            onPressed: onUndelegate,
            child: Text(context.t.tronStaking.undelegate),
          ),
      ],
    );
  }
}

final class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.overview,
    required this.onVote,
    required this.onClaimReward,
  });

  final TronStakingOverview overview;
  final VoidCallback onVote;
  final VoidCallback onClaimReward;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.tronStaking;
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.reward, style: context.appTextStyles.titleMedium),
          const SizedBox(height: 8),
          Text(
            '${sunToTrx(overview.rewardSun)} TRX',
            style: context.appTextStyles.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: strings.vote,
                  onPressed: onVote,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.primary(
                  label: strings.claimReward,
                  onPressed: overview.rewardSun > BigInt.zero
                      ? onClaimReward
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.appTextStyles.caption),
        const SizedBox(height: 4),
        Text(
          value,
          style: prominent
              ? context.appTextStyles.displayAmount
              : context.appTextStyles.titleMedium,
        ),
      ],
    );
  }
}

Future<void> _showAmountAction(
  BuildContext context,
  WidgetRef ref,
  TronStakingDashboardState state, {
  required bool isStake,
}) async {
  final result = await showDialog<TronStakingAction>(
    context: context,
    builder: (_) => _AmountActionDialog(
      state: state,
      isStake: isStake,
      now: ref.read(tronStakingActionClockProvider)(),
    ),
  );
  if (context.mounted && result != null) {
    await _confirmAndSubmit(context, ref, state, result);
  }
}

final class _AmountActionDialog extends StatefulWidget {
  const _AmountActionDialog({
    required this.state,
    required this.isStake,
    required this.now,
  });

  final TronStakingDashboardState state;
  final bool isStake;
  final DateTime now;

  @override
  State<_AmountActionDialog> createState() => _AmountActionDialogState();
}

final class _AmountActionDialogState extends State<_AmountActionDialog> {
  final _amountController = TextEditingController();
  TronResourceType _resource = TronResourceType.bandwidth;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.tronStaking;
    return AppDialog(
      title: widget.isStake ? strings.stakeTitle : strings.unstakeTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<TronResourceType>(
            segments: [
              ButtonSegment(
                value: TronResourceType.bandwidth,
                label: Text(strings.bandwidth),
              ),
              ButtonSegment(
                value: TronResourceType.energy,
                label: Text(strings.energy),
              ),
            ],
            selected: {_resource},
            onSelectionChanged: (value) {
              setState(() {
                _resource = value.single;
                _error = null;
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('tronStakingAmountField'),
            controller: _amountController,
            spellCheckConfiguration: SpellCheckConfiguration.disabled(),
            autocorrect: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: strings.amount,
              hintText: strings.amountHint,
              errorText: _error,
              suffixText: 'TRX',
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('tronStakingMaxButton'),
              onPressed: () {
                final overview = widget.state.overview!;
                final maximum = widget.isStake
                    ? overview.availableBalanceSun
                    : (_resource == TronResourceType.bandwidth
                          ? overview.bandwidthStakedSun
                          : overview.energyStakedSun);
                _amountController.text = sunToTrx(maximum);
                setState(() => _error = null);
              },
              child: Text(strings.maximum),
            ),
          ),
          if (!widget.isStake) ...[
            const SizedBox(height: 12),
            Text(
              strings.unstakeDelay(
                days: widget.state.overview!.unfreezeDelayDays,
              ),
              style: context.appTextStyles.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              strings.unstakeAvailableAt(
                date: _date(
                  widget.now.add(
                    Duration(days: widget.state.overview!.unfreezeDelayDays),
                  ),
                ),
              ),
              style: context.appTextStyles.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              strings.unfreezeSlotsRemaining(
                count: widget.state.overview!.availableUnfreezeCount,
              ),
              style: context.appTextStyles.bodySmall,
            ),
          ],
        ],
      ),
      cancelCallback: () => Navigator.of(context).pop(),
      confirmKey: const Key('tronStakingContinueButton'),
      confirmTitle: strings.continueAction,
      confirmCallback: _continue,
    );
  }

  void _continue() {
    final strings = context.t.tronStaking;
    BigInt amount;
    try {
      amount = trxToSun(_amountController.text);
    } on FormatException {
      setState(() => _error = strings.invalidAmount);
      return;
    }
    final overview = widget.state.overview!;
    final maximum = widget.isStake
        ? overview.availableBalanceSun
        : (_resource == TronResourceType.bandwidth
              ? overview.bandwidthStakedSun
              : overview.energyStakedSun);
    if (amount > maximum) {
      setState(
        () => _error = widget.isStake
            ? strings.insufficientBalance
            : strings.insufficientStaked,
      );
      return;
    }
    if (!widget.isStake && overview.availableUnfreezeCount <= 0) {
      setState(() => _error = strings.noUnfreezeSlots);
      return;
    }
    try {
      Navigator.of(context).pop(
        widget.isStake
            ? TronStakeAction(resource: _resource, amountSun: amount)
            : TronUnstakeAction(resource: _resource, amountSun: amount),
      );
    } on ArgumentError {
      setState(() => _error = strings.invalidAmount);
    }
  }
}

Future<void> _showDelegateAction(
  BuildContext context,
  WidgetRef ref,
  TronStakingDashboardState state,
) async {
  final action = await showDialog<TronDelegateAction>(
    context: context,
    builder: (_) => _DelegateDialog(state: state),
  );
  if (!context.mounted || action == null) {
    return;
  }
  final max = await ref
      .read(tronStakingDashboardControllerProvider.notifier)
      .getMaxDelegatableSun(action.resource);
  if (!context.mounted) {
    return;
  }
  if (action.amountSun > max) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t.tronStaking.insufficientDelegatableBalance),
      ),
    );
    return;
  }
  await _confirmAndSubmit(context, ref, state, action, maxDelegatableSun: max);
}

final class _DelegateDialog extends StatefulWidget {
  const _DelegateDialog({required this.state});

  final TronStakingDashboardState state;

  @override
  State<_DelegateDialog> createState() => _DelegateDialogState();
}

final class _DelegateDialogState extends State<_DelegateDialog> {
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _lockPeriodController = TextEditingController();
  TronResourceType _resource = TronResourceType.bandwidth;
  bool _lock = false;
  String? _error;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _lockPeriodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.tronStaking;
    final supportsLock = widget.state.overview!.maxDelegateLockPeriod > 0;
    return AppDialog(
      title: strings.delegateTitle,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<TronResourceType>(
              segments: [
                ButtonSegment(
                  value: TronResourceType.bandwidth,
                  label: Text(strings.bandwidth),
                ),
                ButtonSegment(
                  value: TronResourceType.energy,
                  label: Text(strings.energy),
                ),
              ],
              selected: {_resource},
              onSelectionChanged: (value) {
                setState(() => _resource = value.single);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('tronDelegateAddressField'),
              controller: _addressController,
              spellCheckConfiguration: SpellCheckConfiguration.disabled(),
              autocorrect: false,
              decoration: InputDecoration(
                labelText: strings.receiver,
                hintText: strings.receiverHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('tronDelegateAmountField'),
              controller: _amountController,
              spellCheckConfiguration: SpellCheckConfiguration.disabled(),
              autocorrect: false,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: strings.amount,
                suffixText: 'TRX',
                errorText: _error,
              ),
            ),
            SwitchListTile.adaptive(
              key: const Key('tronDelegateLockSwitch'),
              contentPadding: EdgeInsets.zero,
              title: Text(strings.lockResource),
              subtitle: supportsLock ? null : Text(strings.lockUnsupported),
              value: _lock,
              onChanged: supportsLock
                  ? (value) => setState(() => _lock = value)
                  : null,
            ),
            if (_lock)
              TextField(
                key: const Key('tronDelegateLockPeriodField'),
                controller: _lockPeriodController,
                spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                autocorrect: false,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: strings.lockPeriod,
                  hintText: strings.lockPeriodHint(
                    max: widget.state.overview!.maxDelegateLockPeriod,
                  ),
                ),
              ),
          ],
        ),
      ),
      cancelCallback: () => Navigator.of(context).pop(),
      confirmKey: const Key('tronDelegateContinueButton'),
      confirmTitle: strings.continueAction,
      confirmCallback: _continue,
    );
  }

  void _continue() {
    final strings = context.t.tronStaking;
    final receiver = _addressController.text.trim();
    if (!isValidTronAddress(receiver) ||
        receiver == widget.state.selectedWallet?.tronAddress) {
      setState(() => _error = strings.invalidReceiver);
      return;
    }
    BigInt amount;
    try {
      amount = trxToSun(_amountController.text);
    } on FormatException {
      setState(() => _error = strings.invalidAmount);
      return;
    }
    final lockPeriod = _lock
        ? int.tryParse(_lockPeriodController.text.trim())
        : null;
    final maxLockPeriod = widget.state.overview!.maxDelegateLockPeriod;
    if (_lock &&
        (lockPeriod == null ||
            lockPeriod <= 0 ||
            maxLockPeriod <= 0 ||
            lockPeriod > maxLockPeriod)) {
      setState(() => _error = strings.operationUnavailable);
      return;
    }
    try {
      Navigator.of(context).pop(
        TronDelegateAction(
          resource: _resource,
          amountSun: amount,
          receiverAddress: receiver,
          lock: _lock,
          lockPeriod: lockPeriod,
        ),
      );
    } on ArgumentError {
      setState(() => _error = strings.invalidAmount);
    }
  }
}

Future<void> _showUndelegateAction(
  BuildContext context,
  WidgetRef ref,
  TronStakingDashboardState state,
  TronDelegation delegation,
  TronResourceType resource,
) async {
  final available = resource == TronResourceType.bandwidth
      ? delegation.bandwidthSun
      : delegation.energySun;
  final controller = TextEditingController(text: sunToTrx(available));
  String? error;
  final action = await showDialog<TronUndelegateAction>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AppDialog(
        title: context.t.tronStaking.undelegateTitle,
        content: TextField(
          controller: controller,
          spellCheckConfiguration: SpellCheckConfiguration.disabled(),
          autocorrect: false,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.t.tronStaking.amount,
            suffixText: 'TRX',
            errorText: error,
          ),
        ),
        cancelCallback: () => Navigator.of(context).pop(),
        confirmTitle: context.t.tronStaking.continueAction,
        confirmCallback: () {
          try {
            final amount = trxToSun(controller.text);
            if (amount > available) {
              throw const FormatException();
            }
            Navigator.of(context).pop(
              TronUndelegateAction(
                resource: resource,
                amountSun: amount,
                receiverAddress: delegation.counterpartyAddress,
              ),
            );
          } on FormatException {
            setState(() => error = context.t.tronStaking.invalidAmount);
          }
        },
      ),
    ),
  );
  controller.dispose();
  if (context.mounted && action != null) {
    await _confirmAndSubmit(context, ref, state, action);
  }
}

Future<void> _confirmSimpleAction(
  BuildContext context,
  WidgetRef ref,
  TronStakingDashboardState state,
  TronStakingAction action,
) async {
  await _confirmAndSubmit(context, ref, state, action);
}

Future<void> _confirmAndSubmit(
  BuildContext context,
  WidgetRef ref,
  TronStakingDashboardState state,
  TronStakingAction action, {
  BigInt? maxDelegatableSun,
}) async {
  TronStakingFeeEstimate feeEstimate;
  try {
    feeEstimate = await ref
        .read(tronStakingFeeServiceProvider)
        .estimateFee(
          apiBaseUrl: state.rpcNode!.endpointUrl,
          ownerAddress: state.selectedWallet!.tronAddress,
          action: action,
          headers: state.rpcNode!.endpointHeaders,
        );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.tronStaking.feeEstimateFailed)),
      );
    }
    return;
  }
  if (!context.mounted) {
    return;
  }
  if (action is TronStakeAction &&
      action.amountSun + feeEstimate.burnedSun >
          state.overview!.availableBalanceSun) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t.tronStaking.insufficientBalance)),
    );
    return;
  }
  final confirmed = await AppDialog.show<bool>(
    context: context,
    title: _confirmTitle(context, action),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (action is TronCancelAllUnfreezeAction)
            RiskNotice(
              level: RiskLevel.warning,
              message: context.t.tronStaking.cancelAllWarning,
            ),
          _ConfirmationLine(
            label: context.t.tronStaking.owner,
            value: state.selectedWallet!.tronAddress,
          ),
          if (_resourceOf(action) != null)
            _ConfirmationLine(
              label: context.t.tronStaking.resourceType,
              value: _resourceLabel(context, _resourceOf(action)!),
            ),
          if (_actionAmount(action, state.overview!) != null)
            _ConfirmationLine(
              label: context.t.tronStaking.amount,
              value: '${sunToTrx(_actionAmount(action, state.overview!)!)} TRX',
            ),
          if (action is TronStakeAction)
            _ConfirmationLine(
              label: context.t.tronStaking.remainingBalance,
              value:
                  '${sunToTrx(state.overview!.availableBalanceSun - action.amountSun - feeEstimate.burnedSun)} TRX',
            ),
          if (action is TronDelegateAction)
            _ConfirmationLine(
              label: context.t.tronStaking.receiver,
              value: action.receiverAddress,
            ),
          if (action is TronDelegateAction)
            _ConfirmationLine(
              label: context.t.tronStaking.lockResource,
              value: action.lock
                  ? context.t.tronStaking.locked
                  : context.t.tronStaking.unlocked,
            ),
          if (action is TronDelegateAction &&
              action.lock &&
              action.lockPeriod != null)
            _ConfirmationLine(
              label: context.t.tronStaking.lockPeriod,
              value: context.t.tronStaking.lockPeriodValue(
                count: action.lockPeriod!,
              ),
            ),
          if (action is TronUndelegateAction)
            _ConfirmationLine(
              label: context.t.tronStaking.receiver,
              value: action.receiverAddress,
            ),
          _ConfirmationLine(
            label: context.t.tronStaking.estimatedFee,
            value:
                '${sunToTrx(feeEstimate.burnedSun)} TRX · '
                '${context.t.tronStaking.feeCalculatedByNetwork}',
          ),
        ],
      ),
    ),
    cancelCallback: () => Navigator.of(context).pop(false),
    confirmKey: const Key('confirmTronStakingAction'),
    confirmTitle: context.t.tronStaking.confirmAndSign,
    confirmCallback: () => Navigator.of(context).pop(true),
    confirmVariant: action is TronCancelAllUnfreezeAction
        ? AppDialogActionVariant.danger
        : AppDialogActionVariant.primary,
  );
  if (!context.mounted || confirmed != true) {
    return;
  }
  SigningPasswordAuthorization? authorization;
  final wallet = state.selectedWallet!;
  if (!ref
      .read(sessionKeyCacheProvider)
      .hasKey(wallet.id, now: DateTime.now().toUtc())) {
    authorization = await showSigningPasswordSheet(context);
    if (!context.mounted || authorization == null) {
      return;
    }
  }
  await ref
      .read(tronStakingActionControllerProvider.notifier)
      .submit(
        TronStakingActionSubmission(
          chain: state.selectedNetwork!,
          rpcNode: state.rpcNode!,
          account: wallet,
          overview: state.overview!,
          action: action,
          delegations: state.delegations,
          maxDelegatableSun: maxDelegatableSun,
          estimatedFeeSun: feeEstimate.burnedSun,
        ),
        signingPassword: authorization?.password,
        rememberSigningPassword: authorization?.rememberPassword ?? true,
      );
}

final class _TronVotePage extends ConsumerStatefulWidget {
  const _TronVotePage({required this.state});

  final TronStakingDashboardState state;

  @override
  ConsumerState<_TronVotePage> createState() => _TronVotePageState();
}

final class _TronVotePageState extends ConsumerState<_TronVotePage> {
  final _searchController = TextEditingController();
  final _votes = <String, int>{};

  @override
  void initState() {
    super.initState();
    for (final vote in widget.state.overview!.votes) {
      _votes[vote.witnessAddress] = vote.voteCount;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.tronStaking;
    final query = _searchController.text.trim().toLowerCase();
    final witnesses = widget.state.witnesses
        .where(
          (witness) =>
              query.isEmpty ||
              witness.address.toLowerCase().contains(query) ||
              witness.url.toLowerCase().contains(query),
        )
        .toList(growable: false);
    final used = _votes.values.fold(0, (total, value) => total + value);
    final power = widget.state.overview!.tronPower;
    return Scaffold(
      appBar: AppBar(title: Text(strings.witnesses)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pageX),
          children: [
            TextField(
              controller: _searchController,
              spellCheckConfiguration: SpellCheckConfiguration.disabled(),
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: strings.witnessSearch,
                prefixIcon: const Icon(AppIcons.search),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              strings.voteSummary(used: used, total: power),
              style: context.appTextStyles.bodyLarge,
            ),
            const SizedBox(height: 12),
            for (final witness in witnesses)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        witness.url.isEmpty ? witness.address : witness.url,
                        style: context.appTextStyles.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        witness.address,
                        style: context.appTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        key: Key('tronWitnessVote-${witness.address}'),
                        initialValue: (_votes[witness.address] ?? 0).toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            _votes[witness.address] = int.tryParse(value) ?? 0;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: strings.myVotes,
                          helperText: strings.witnessVotes(
                            count: witness.voteCount,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.pageX),
        child: Row(
          children: [
            Expanded(
              child: AppButton.text(
                label: strings.clearVotes,
                onPressed: () => setState(_votes.clear),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton.primary(
                label: strings.continueAction,
                onPressed: used <= power ? _confirm : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final votes = _votes.entries
        .where((entry) => entry.value > 0)
        .map(
          (entry) =>
              TronVote(witnessAddress: entry.key, voteCount: entry.value),
        )
        .toList(growable: false);
    await _confirmAndSubmit(
      context,
      ref,
      widget.state,
      TronVoteAction(votes: votes),
    );
  }
}

final class _ConfirmationLine extends StatelessWidget {
  const _ConfirmationLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.appTextStyles.caption),
          const SizedBox(height: 2),
          Text(value, style: context.appTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

String _confirmTitle(BuildContext context, TronStakingAction action) {
  final strings = context.t.tronStaking;
  return switch (action) {
    TronStakeAction() => strings.confirmStake,
    TronUnstakeAction() => strings.confirmUnstake,
    TronWithdrawUnfreezeAction() => strings.confirmWithdraw,
    TronCancelAllUnfreezeAction() => strings.confirmCancel,
    TronDelegateAction() => strings.confirmDelegate,
    TronUndelegateAction() => strings.confirmUndelegate,
    TronVoteAction() => strings.confirmVote,
    TronClaimRewardAction() => strings.confirmClaimReward,
  };
}

BigInt? _actionAmount(TronStakingAction action, TronStakingOverview overview) {
  return switch (action) {
    TronStakeAction() => action.amountSun,
    TronUnstakeAction() => action.amountSun,
    TronWithdrawUnfreezeAction() => overview.withdrawableSun,
    TronCancelAllUnfreezeAction() => overview.pendingUnfreezeSun,
    TronDelegateAction() => action.amountSun,
    TronUndelegateAction() => action.amountSun,
    TronClaimRewardAction() => overview.rewardSun,
    TronVoteAction() => null,
  };
}

TronResourceType? _resourceOf(TronStakingAction action) => switch (action) {
  TronStakeAction() => action.resource,
  TronUnstakeAction() => action.resource,
  TronDelegateAction() => action.resource,
  TronUndelegateAction() => action.resource,
  _ => null,
};

String _resourceLabel(BuildContext context, TronResourceType resource) {
  return switch (resource) {
    TronResourceType.bandwidth => context.t.tronStaking.bandwidth,
    TronResourceType.energy => context.t.tronStaking.energy,
  };
}

String _actionError(BuildContext context, TronStakingActionError? error) {
  final strings = context.t.tronStaking;
  return switch (error) {
    TronStakingActionError.walletLocked => strings.walletLocked,
    TronStakingActionError.signingKeyUnavailable =>
      strings.signingKeyUnavailable,
    TronStakingActionError.insufficientBalance => strings.insufficientBalance,
    TronStakingActionError.insufficientStakedBalance =>
      strings.insufficientStaked,
    TronStakingActionError.noUnfreezeSlots => strings.noUnfreezeSlots,
    TronStakingActionError.nothingToWithdraw => strings.nothingToWithdraw,
    TronStakingActionError.cancelUnsupported => strings.cancelUnsupported,
    TronStakingActionError.nothingToCancel => strings.nothingToCancel,
    TronStakingActionError.delegationUnsupported =>
      strings.delegationUnsupported,
    TronStakingActionError.invalidDelegation => strings.invalidDelegation,
    TronStakingActionError.insufficientDelegatableBalance =>
      strings.insufficientDelegatableBalance,
    TronStakingActionError.delegationLocked => strings.delegationLocked,
    TronStakingActionError.insufficientDelegatedBalance =>
      strings.insufficientDelegatedBalance,
    TronStakingActionError.excessiveVotes => strings.excessiveVotes,
    TronStakingActionError.nothingToClaim => strings.nothingToClaim,
    TronStakingActionError.transactionValidationFailed =>
      strings.transactionValidationFailed,
    TronStakingActionError.broadcastFailed => strings.broadcastFailed,
    _ => strings.operationUnavailable,
  };
}

String _shortAddress(String value) {
  if (value.length <= 12) {
    return value;
  }
  return '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
