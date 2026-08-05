import 'package:flutter/material.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_brand_colors.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_drag_handle.dart';
import '../../assets/domain/asset_balance.dart';
import '../../assets/presentation/widgets/token_icon.dart';

Future<AssetBalance?> showTransferAssetPickerSheet(
  BuildContext context, {
  required List<AssetBalance> balances,
  required String selectedAssetKey,
  required bool hideZeroBalances,
  required ValueChanged<bool> onHideZeroBalancesChanged,
}) {
  return showModalBottomSheet<AssetBalance>(
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
    builder: (_) => TransferAssetPickerSheet(
      balances: balances,
      selectedAssetKey: selectedAssetKey,
      initialHideZeroBalances: hideZeroBalances,
      onHideZeroBalancesChanged: onHideZeroBalancesChanged,
    ),
  );
}

final class TransferAssetPickerSheet extends StatefulWidget {
  const TransferAssetPickerSheet({
    required this.balances,
    required this.selectedAssetKey,
    required this.initialHideZeroBalances,
    required this.onHideZeroBalancesChanged,
    super.key,
  });

  final List<AssetBalance> balances;
  final String selectedAssetKey;
  final bool initialHideZeroBalances;
  final ValueChanged<bool> onHideZeroBalancesChanged;

  @override
  State<TransferAssetPickerSheet> createState() =>
      _TransferAssetPickerSheetState();
}

final class _TransferAssetPickerSheetState
    extends State<TransferAssetPickerSheet> {
  late bool _hideZeroBalances;

  @override
  void initState() {
    super.initState();
    _hideZeroBalances = widget.initialHideZeroBalances;
  }

  @override
  Widget build(BuildContext context) {
    final balances = [...widget.balances]..sort(_compareBalancesDescending);
    final visibleBalances = _hideZeroBalances
        ? balances.where((balance) => !_isZeroBalance(balance)).toList()
        : balances;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageX,
          0,
          AppSpacing.pageX,
          20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppDragHandle(),
            Text(t.transfer.selectedAsset, style: context.appTextStyles.titleLarge),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              key: const Key('transferHideZeroBalanceSwitch'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                t.transfer.hideZeroBalances,
                style: context.appTextStyles.bodyMedium,
              ),
              value: _hideZeroBalances,
              onChanged: (value) {
                setState(() {
                  _hideZeroBalances = value;
                });
                widget.onHideZeroBalancesChanged(value);
              },
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.62,
              ),
              child: visibleBalances.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          t.transfer.noAssets,
                          style: context.appTextStyles.bodySmall,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        final balance = visibleBalances[index];
                        return _TransferAssetRow(
                          key: ValueKey(
                            'transferAssetOption:${transferAssetKey(balance)}',
                          ),
                          balance: balance,
                          isSelected: transferAssetKey(balance) ==
                              widget.selectedAssetKey,
                          onTap: () => Navigator.of(context).pop(balance),
                        );
                      },
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 4),
                      itemCount: visibleBalances.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _TransferAssetRow extends StatelessWidget {
  const _TransferAssetRow({
    required this.balance,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final AssetBalance balance;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: AnimatedContainer(
        key: ValueKey(
          'transferAssetSelectionSurface:${transferAssetKey(balance)}',
        ),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color:
              isSelected ? context.brandColors.primarySoft : Colors.transparent,
          borderRadius: AppRadius.mediumBorder,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: AppRadius.mediumBorder,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                TokenIcon(
                  symbol: balance.token.symbol,
                  logoUri: balance.token.logoUri,
                  logoKeyPrefix: 'transferAssetLogo',
                  fallbackKeyPrefix: 'transferAssetLogoFallback',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        balance.token.symbol,
                        style: context.appTextStyles.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        balance.token.name,
                        style: context.appTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 152),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        balance.formattedBalance ?? balance.balance ?? '0',
                        style: context.appTextStyles.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        balance.fiatValue ?? '--',
                        style: context.appTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

String transferAssetKey(AssetBalance balance) {
  return '${balance.chainId}:${balance.token.contractAddress ?? 'native'}';
}

int _compareBalancesDescending(AssetBalance left, AssetBalance right) {
  final amountComparison = _compareTokenAmounts(right, left);
  if (amountComparison != 0) {
    return amountComparison;
  }
  return left.token.symbol.compareTo(right.token.symbol);
}

int _compareTokenAmounts(AssetBalance left, AssetBalance right) {
  final leftRaw = BigInt.tryParse(left.balance ?? '');
  final rightRaw = BigInt.tryParse(right.balance ?? '');
  if (leftRaw != null && rightRaw != null) {
    final leftScaled = leftRaw * BigInt.from(10).pow(right.token.decimals);
    final rightScaled = rightRaw * BigInt.from(10).pow(left.token.decimals);
    return leftScaled.compareTo(rightScaled);
  }
  return _formattedAmount(left).compareTo(_formattedAmount(right));
}

double _formattedAmount(AssetBalance balance) {
  return double.tryParse(
        (balance.formattedBalance ?? '').replaceAll(',', ''),
      ) ??
      0;
}

bool _isZeroBalance(AssetBalance balance) {
  final rawBalance = BigInt.tryParse(balance.balance ?? '');
  if (rawBalance != null) {
    return rawBalance == BigInt.zero;
  }
  return _formattedAmount(balance) == 0;
}
