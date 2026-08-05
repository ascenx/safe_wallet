import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../chains/domain/block_explorer_url_builder.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/errors/error_localizer.dart';
import '../../../shared/network/external_url_launcher.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../application/transaction_broadcast_controller.dart';

final class TransactionResultPage extends ConsumerWidget {
  const TransactionResultPage({required this.request, super.key});

  final TransactionBroadcastRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transactionBroadcastControllerProvider);
    final transactionHash = state.transactionHash;
    final explorerUrl = transactionHash == null
        ? null
        : buildBlockExplorerTransactionUrl(
            chainType: request.chain.chainType,
            chainId: request.chain.chainId,
            transactionHash: transactionHash,
            blockExplorerUrl: request.chain.blockExplorerUrl,
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _popToRoot(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => _popToRoot(context)),
          title: Text(t.transfer.resultTitle),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageX,
              24,
              AppSpacing.pageX,
              24,
            ),
            child: _ResultBody(
              state: state,
              onOpenExplorer: explorerUrl == null
                  ? null
                  : () {
                      ref
                          .read(externalUrlLauncherProvider)
                          .openExternal(explorerUrl);
                    },
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pageX),
            child: AppButton.primary(
              key: const Key('finishTransactionButton'),
              label: t.actions.done,
              onPressed: () => _popToRoot(context),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.state, required this.onOpenExplorer});

  final TransactionBroadcastState state;
  final VoidCallback? onOpenExplorer;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      TransactionBroadcastStatus.success => _ResultCard(
        icon: AppIcons.checkCircle,
        iconColor: AppColors.success,
        title: t.transactions.submitted,
        child: _SuccessResultContent(
          transactionHash: state.transactionHash ?? '',
          onOpenExplorer: onOpenExplorer,
        ),
      ),
      TransactionBroadcastStatus.failure => _ResultCard(
        icon: AppIcons.error,
        iconColor: Theme.of(context).colorScheme.error,
        title: t.transactions.failed,
        child: Text(
          const ErrorLocalizer().messageFor(state.error!, t),
          style: context.appTextStyles.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
      TransactionBroadcastStatus.idle ||
      TransactionBroadcastStatus.submitting => _ResultCard(
        icon: AppIcons.pending,
        iconColor: Theme.of(context).colorScheme.primary,
        title: t.transactions.submitting,
        child: const SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    };
  }
}

final class _SuccessResultContent extends StatelessWidget {
  const _SuccessResultContent({
    required this.transactionHash,
    required this.onOpenExplorer,
  });

  final String transactionHash;
  final VoidCallback? onOpenExplorer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(
          transactionHash,
          style: context.appTextStyles.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton.secondary(
                key: const Key('copyTransactionHashButton'),
                label: t.transfer.copyTransactionHash,
                icon: const Icon(AppIcons.copy),
                onPressed: transactionHash.isEmpty
                    ? null
                    : () => _copyTransactionHash(context),
              ),
            ),
            if (onOpenExplorer != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.secondary(
                  key: const Key('viewTransactionExplorerButton'),
                  label: t.transfer.viewTransactionExplorer,
                  icon: const Icon(AppIcons.externalLink),
                  onPressed: onOpenExplorer,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _copyTransactionHash(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: transactionHash));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.transfer.transactionHashCopied)));
  }
}

void _popToRoot(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
}

final class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: AppRadius.largeBorder,
          border: Border.all(color: context.appColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 40),
              const SizedBox(height: 12),
              Text(title, style: context.appTextStyles.titleMedium),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
