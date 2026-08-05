import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_brand_colors.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../application/available_chains_provider.dart';
import '../application/selected_chain_controller.dart';
import '../data/chain_logo_uris.dart';
import '../domain/chain_config.dart';
import '../../assets/presentation/widgets/token_icon.dart';

Future<ChainConfig?> showChainSelectorSheet(
  BuildContext context, {
  bool selectCurrentChain = true,
  bool Function(ChainConfig chain)? filter,
  String? title,
  String? allOptionTitle,
  bool allOptionSelected = false,
  VoidCallback? onSelectAll,
}) {
  return showModalBottomSheet<ChainConfig>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: context.appColors.surface,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.xLarge),
      ),
    ),
    builder: (_) => ChainSelectorSheet(
      selectCurrentChain: selectCurrentChain,
      showCurrentSelection: selectCurrentChain,
      filter: filter,
      title: title,
      allOptionTitle: allOptionTitle,
      allOptionSelected: allOptionSelected,
      onSelectAll: onSelectAll,
    ),
  );
}

final class ChainSelectorPage extends ConsumerWidget {
  const ChainSelectorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(t.chains.selectorTitle)),
      body: const SafeArea(
        child: _ChainSelectorContent(
          selectCurrentChain: true,
          showCurrentSelection: true,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            16,
            AppSpacing.pageX,
            24,
          ),
        ),
      ),
    );
  }
}

final class ChainSelectorSheet extends ConsumerWidget {
  const ChainSelectorSheet({
    this.selectCurrentChain = true,
    this.showCurrentSelection = true,
    this.filter,
    this.title,
    this.allOptionTitle,
    this.allOptionSelected = false,
    this.onSelectAll,
    super.key,
  });

  final bool selectCurrentChain;
  final bool showCurrentSelection;
  final bool Function(ChainConfig chain)? filter;
  final String? title;
  final String? allOptionTitle;
  final bool allOptionSelected;
  final VoidCallback? onSelectAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageX,
              0,
              AppSpacing.pageX,
              0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ChainSelectorDragHandle(),
                Text(title ?? t.chains.selectorTitle,
                    style: context.appTextStyles.titleLarge),
                const SizedBox(height: AppSpacing.sectionY),
                Flexible(
                  child: _ChainSelectorContent(
                    selectCurrentChain: selectCurrentChain,
                    showCurrentSelection: showCurrentSelection,
                    filter: filter,
                    allOptionTitle: allOptionTitle,
                    allOptionSelected: allOptionSelected,
                    onSelectAll: onSelectAll,
                    padding: EdgeInsets.only(
                      bottom: AppSpacing.cardPaddingLarge + safeBottom,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _ChainSelectorContent extends ConsumerWidget {
  const _ChainSelectorContent({
    required this.selectCurrentChain,
    required this.showCurrentSelection,
    required this.padding,
    this.filter,
    this.allOptionTitle,
    this.allOptionSelected = false,
    this.onSelectAll,
  });

  final bool selectCurrentChain;
  final bool showCurrentSelection;
  final EdgeInsetsGeometry padding;
  final bool Function(ChainConfig chain)? filter;
  final String? allOptionTitle;
  final bool allOptionSelected;
  final VoidCallback? onSelectAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chainsValue = ref.watch(availableChainsProvider);
    final selectedChainId = showCurrentSelection
        ? ref.watch(selectedChainControllerProvider).value?.id
        : null;

    return chainsValue.when(
      data: (chains) {
        final filterPredicate = filter;
        final filteredChains = filterPredicate == null
            ? chains
            : chains.where(filterPredicate).toList();
        final hasAllOption = allOptionTitle != null && onSelectAll != null;
        return ListView.separated(
          key: const Key('chainSelectorList'),
          shrinkWrap: true,
          padding: padding,
          itemBuilder: (context, index) {
            if (hasAllOption && index == 0) {
              return _AllChainsRow(
                title: allOptionTitle!,
                isSelected: allOptionSelected,
                onTap: () {
                  onSelectAll!();
                  Navigator.of(context).maybePop();
                },
              );
            }
            final chain = filteredChains[index - (hasAllOption ? 1 : 0)];
            return _ChainRow(
              chain: chain,
              isSelected: chain.id == selectedChainId,
              onTap: () async {
                if (selectCurrentChain) {
                  await ref
                      .read(selectedChainControllerProvider.notifier)
                      .selectChain(chain.id);
                }
                if (context.mounted) {
                  Navigator.of(context).maybePop(chain);
                }
              },
            );
          },
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.sectionY),
          itemCount: filteredChains.length + (hasAllOption ? 1 : 0),
        );
      },
      error: (error, stackTrace) => Center(
        child: Text(t.chains.loadFailed, style: context.appTextStyles.bodySmall),
      ),
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(t.chains.loading, style: context.appTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

final class _AllChainsRow extends StatelessWidget {
  const _AllChainsRow({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.largeBorder,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: AppRadius.largeBorder,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : context.appColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.brandColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    AppIcons.globe,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: context.appTextStyles.bodyLarge)),
              if (isSelected) ...[
                const SizedBox(width: 12),
                Icon(
                  AppIcons.checkCircleFilled,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _ChainSelectorDragHandle extends StatelessWidget {
  const _ChainSelectorDragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        key: const Key('chainSelectorSheetDragHandle'),
        padding: const EdgeInsets.only(top: 12, bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.appColors.border,
            borderRadius: AppRadius.pillBorder,
          ),
          child: const SizedBox(width: 36, height: 4),
        ),
      ),
    );
  }
}

final class _ChainRow extends StatelessWidget {
  const _ChainRow({
    required this.chain,
    required this.isSelected,
    required this.onTap,
  });

  final ChainConfig chain;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.largeBorder,
      onTap: isSelected ? null : onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: AppRadius.largeBorder,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : context.appColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Row(
            children: [
              TokenIcon(
                symbol: chain.symbol,
                logoUri: chainLogoUri(chain),
                size: 44,
                muted: !isSelected,
                logoKeyPrefix: 'chainLogo',
                fallbackKeyPrefix: 'chainLogoFallback',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chain.name, style: context.appTextStyles.bodyLarge),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _NetworkBadge(
                          label: chain.isTestnet
                              ? t.chains.testnet
                              : t.chains.mainnet,
                        ),
                        _NetworkBadge(label: chain.symbol),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 12),
                Icon(
                  AppIcons.checkCircleFilled,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _NetworkBadge extends StatelessWidget {
  const _NetworkBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surfaceSoft,
        borderRadius: AppRadius.smallBorder,
        border: Border.all(color: context.appColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: context.appTextStyles.caption),
      ),
    );
  }
}
