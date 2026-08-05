import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_brand_colors.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/utils/address_display.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../chains/domain/chain_config.dart';
import '../application/address_book_controller.dart';
import '../domain/address_book_contact.dart';
import 'edit_contact_page.dart';

final class AddressBookPage extends ConsumerWidget {
  const AddressBookPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsValue = ref.watch(addressBookControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.addressBook.managementTitle),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EditContactPage(),
                ),
              );
            },
            tooltip: t.addressBook.addContact,
            icon: const Icon(AppIcons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: contactsValue.when(
          data: (contacts) {
            if (contacts.isEmpty) {
              return Center(
                child: Text(
                  t.addressBook.empty,
                  style: context.appTextStyles.bodySmall,
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageX,
                16,
                AppSpacing.pageX,
                96,
              ),
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return _ContactRow(
                  contact: contact,
                  onEdit: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EditContactPage(contact: contact),
                      ),
                    );
                  },
                  onDelete: () => _confirmDelete(context, ref, contact),
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sectionY),
              itemCount: contacts.length,
            );
          },
          error: (error, stackTrace) => Center(
            child: Text(
              t.addressBook.loadFailed,
              style: context.appTextStyles.bodySmall,
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AddressBookContact contact,
  ) async {
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: t.addressBook.deleteTitle,
      content: Text(t.addressBook.deleteMessage),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmTitle: t.addressBook.confirmDelete,
      confirmVariant: AppDialogActionVariant.danger,
      confirmCallback: () => Navigator.of(context).pop(true),
    );

    if (confirmed != true) {
      return;
    }

    final controller = ref.read(addressBookControllerProvider.notifier);
    controller.requestDeleteContact(contact.id);
    await controller.confirmPendingDelete();
  }
}

final class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  final AddressBookContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: AppRadius.largeBorder,
        border: Border.all(color: context.appColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: context.brandColors.primarySoft,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(_chainIcon(contact.chainType)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    contact.name,
                    style: context.appTextStyles.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(AppIcons.edit),
                  tooltip: t.addressBook.editContact,
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(AppIcons.delete),
                  tooltip: t.addressBook.delete,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text.rich(
              highlightedAddressTextSpan(
                contact.address,
                style: context.appTextStyles.bodySmall,
                highlightColor: Theme.of(context).colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (contact.note != null) ...[
              const SizedBox(height: 8),
              Text(
                contact.note!,
                style: context.appTextStyles.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            _Badge(label: _chainLabel(contact.chainType)),
          ],
        ),
      ),
    );
  }

  IconData _chainIcon(ChainType chainType) {
    return switch (chainType) {
      ChainType.evm => AppIcons.network,
      ChainType.bitcoin => AppIcons.bitcoin,
      ChainType.tron => AppIcons.lightning,
      ChainType.solana => AppIcons.solana,
      ChainType.sui => AppIcons.sui,
    };
  }

  String _chainLabel(ChainType chainType) {
    return switch (chainType) {
      ChainType.evm => t.addressBook.evm,
      ChainType.bitcoin => t.addressBook.bitcoin,
      ChainType.tron => t.addressBook.tron,
      ChainType.solana => t.addressBook.solana,
      ChainType.sui => t.addressBook.sui,
    };
  }
}

final class _Badge extends StatelessWidget {
  const _Badge({required this.label});

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
