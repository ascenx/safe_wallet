import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/security/background_route_preservation.dart';
import '../../../shared/widgets/app_action_sheet.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_picker_field.dart';
import '../../chains/domain/chain_config.dart';
import '../application/address_book_controller.dart';
import '../domain/address_book_contact.dart';

final class EditContactPage extends ConsumerStatefulWidget {
  const EditContactPage({
    this.contact,
    super.key,
  });

  final AddressBookContact? contact;

  @override
  ConsumerState<EditContactPage> createState() => _EditContactPageState();
}

final class _EditContactPageState extends ConsumerState<EditContactPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _noteController;
  late ChainType _chainType;
  String? _nameError;
  String? _addressError;
  String? _formError;
  bool _isSaving = false;

  bool get _isEditing => widget.contact != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.name);
    _addressController = TextEditingController(text: widget.contact?.address);
    _noteController = TextEditingController(text: widget.contact?.note);
    _chainType = widget.contact?.chainType ?? ChainType.evm;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundRoutePreservationScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing ? t.addressBook.editContact : t.addressBook.addContact,
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageX,
              16,
              AppSpacing.pageX,
              24,
            ),
            children: [
              AppPickerField(
                key: const Key('contactChainTypeSelector'),
                label: t.addressBook.chainTypeLabel,
                value: _chainTypeLabel(_chainType),
                leading: Icon(_chainTypeIcon(_chainType)),
                onTap: _isSaving ? null : _showChainTypeSheet,
              ),
              const SizedBox(height: 14),
              TextField(
                spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                autocorrect: false,
                controller: _nameController,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: t.addressBook.nameLabel,
                  errorText: _nameError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                autocorrect: false,
                controller: _addressController,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: t.addressBook.addressLabel,
                  errorText: _addressError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                autocorrect: false,
                controller: _noteController,
                enabled: !_isSaving,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: t.addressBook.noteLabel),
              ),
              if (_formError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _formError!,
                  style: context.appTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              AppButton.primary(
                label: t.addressBook.save,
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChainTypeSheet() async {
    final chainType = await showAppActionSheet<ChainType>(
      context,
      title: t.addressBook.chainTypeLabel,
      actions: [
        for (final type in const [
          ChainType.evm,
          ChainType.solana,
          ChainType.bitcoin,
          ChainType.tron,
          ChainType.sui,
        ])
          AppActionSheetAction<ChainType>(
            value: type,
            title: _chainTypeLabel(type),
            icon: _chainTypeIcon(type),
            isSelected: type == _chainType,
          ),
      ],
    );
    if (!mounted || chainType == null || chainType == _chainType) {
      return;
    }
    setState(() {
      _chainType = chainType;
      _addressError = null;
    });
  }

  String _chainTypeLabel(ChainType chainType) {
    return switch (chainType) {
      ChainType.evm => t.addressBook.evm,
      ChainType.solana => t.addressBook.solana,
      ChainType.bitcoin => t.addressBook.bitcoin,
      ChainType.tron => t.addressBook.tron,
      ChainType.sui => t.addressBook.sui,
    };
  }

  IconData _chainTypeIcon(ChainType chainType) {
    return switch (chainType) {
      ChainType.evm => AppIcons.network,
      ChainType.solana => AppIcons.solana,
      ChainType.bitcoin => AppIcons.bitcoin,
      ChainType.tron => AppIcons.lightning,
      ChainType.sui => AppIcons.sui,
    };
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    setState(() {
      _nameError = name.isEmpty ? t.addressBook.nameRequired : null;
      _addressError = _addressErrorFor(address);
      _formError = null;
    });
    if (_nameError != null || _addressError != null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(addressBookControllerProvider.notifier).saveContact(
            contactId: widget.contact?.id,
            name: name,
            address: address,
            chainType: _chainType,
            note: _noteController.text,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ArgumentError {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _addressError = t.addressBook.invalidAddress;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _formError = t.errors.unknown;
      });
    }
  }

  String? _addressErrorFor(String address) {
    if (address.isEmpty) {
      return t.addressBook.addressRequired;
    }
    if (!isValidAddressForChainType(address, _chainType)) {
      return t.addressBook.invalidAddress;
    }
    return null;
  }
}
