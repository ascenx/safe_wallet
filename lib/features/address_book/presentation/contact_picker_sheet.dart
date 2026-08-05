import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/utils/address_display.dart';
import '../../../shared/widgets/app_drag_handle.dart';
import '../../chains/domain/chain_config.dart';
import '../application/recipient_picker_provider.dart';
import '../domain/recipient_picker_entry.dart';

Future<RecipientPickerEntry?> showContactPickerSheet(
  BuildContext context, {
  required ChainType chainType,
  required String currentWalletId,
}) {
  return showModalBottomSheet<RecipientPickerEntry>(
    context: context,
    showDragHandle: false,
    builder: (_) => ContactPickerSheet(
      chainType: chainType,
      currentWalletId: currentWalletId,
    ),
  );
}

final class ContactPickerSheet extends ConsumerWidget {
  const ContactPickerSheet({
    required this.chainType,
    this.currentWalletId,
    this.onSelected,
    super.key,
  });

  final ChainType chainType;
  final String? currentWalletId;
  final ValueChanged<RecipientPickerEntry>? onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickerValue = ref.watch(
      recipientPickerDataProvider((
        chainType: chainType,
        currentWalletId: currentWalletId,
      )),
    );

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
            Text(
              t.addressBook.pickTitle,
              style: context.appTextStyles.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sectionY),
            pickerValue.when(
              data: (data) {
                if (data.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        t.addressBook.noContactsForChain,
                        style: context.appTextStyles.bodySmall,
                      ),
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (data.wallets.isNotEmpty)
                        _PickerSection(
                          title: t.addressBook.otherWallets,
                          entries: data.wallets,
                          onSelected: (entry) => _select(context, entry),
                        ),
                      if (data.wallets.isNotEmpty && data.contacts.isNotEmpty)
                        const SizedBox(height: AppSpacing.sectionY),
                      if (data.contacts.isNotEmpty)
                        _PickerSection(
                          title: t.addressBook.contacts,
                          entries: data.contacts,
                          onSelected: (entry) => _select(context, entry),
                        ),
                    ],
                  ),
                );
              },
              error: (error, stackTrace) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    t.addressBook.loadFailed,
                    style: context.appTextStyles.bodySmall,
                  ),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _select(BuildContext context, RecipientPickerEntry entry) {
    onSelected?.call(entry);
    Navigator.of(context).pop(entry);
  }
}

final class _PickerSection extends StatelessWidget {
  const _PickerSection({
    required this.title,
    required this.entries,
    required this.onSelected,
  });

  final String title;
  final List<RecipientPickerEntry> entries;
  final ValueChanged<RecipientPickerEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.appTextStyles.caption),
        const SizedBox(height: 8),
        for (var index = 0; index < entries.length; index++) ...[
          _PickerRecipientRow(
            entry: entries[index],
            onTap: () => onSelected(entries[index]),
          ),
          if (index != entries.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

final class _PickerRecipientRow extends StatelessWidget {
  const _PickerRecipientRow({required this.entry, required this.onTap});

  final RecipientPickerEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.mediumBorder,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: AppRadius.mediumBorder,
          border: Border.all(color: context.appColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Row(
            children: [
              Icon(
                entry.source == RecipientPickerEntrySource.wallet
                    ? AppIcons.wallet
                    : AppIcons.person,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: context.appTextStyles.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      highlightedAddressTextSpan(
                        middleEllipsizedAddress(entry.address),
                        style: context.appTextStyles.caption,
                        highlightColor: Theme.of(context).colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.chevronRight, color: context.appColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
