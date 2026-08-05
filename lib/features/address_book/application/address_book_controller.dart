import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solana_sdk/solana_sdk.dart' show PublicKey;
import 'package:wallet/wallet.dart' show isValidTronAddress;

import '../../chains/domain/chain_config.dart';
import '../../../shared/utils/bitcoin_address.dart';
import '../../../shared/utils/evm_address.dart';
import '../../../shared/utils/sui_address.dart';
import '../data/address_book_repository.dart';
import '../domain/address_book_contact.dart';

final addressBookRepositoryProvider = Provider<AddressBookRepository>((ref) {
  throw UnimplementedError('addressBookRepositoryProvider must be overridden');
});

final addressBookNowProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final addressBookIdFactoryProvider = Provider<String Function()>((ref) {
  var sequence = 0;
  return () {
    sequence += 1;
    return 'contact-${DateTime.now().microsecondsSinceEpoch}-$sequence';
  };
});

final addressBookControllerProvider =
    AsyncNotifierProvider<AddressBookController, List<AddressBookContact>>(
      AddressBookController.new,
    );

final addressBookContactsForPickerProvider =
    FutureProvider.family<List<AddressBookContact>, ChainType>((
      ref,
      chainType,
    ) async {
      final contacts = await ref.watch(addressBookControllerProvider.future);
      return List.unmodifiable(
        contacts.where((contact) => contact.chainType == chainType),
      );
    });

final class AddressBookController
    extends AsyncNotifier<List<AddressBookContact>> {
  String? _pendingDeleteContactId;

  String? get pendingDeleteContactId => _pendingDeleteContactId;

  @override
  Future<List<AddressBookContact>> build() {
    return ref.watch(addressBookRepositoryProvider).listContacts();
  }

  Future<AddressBookContact> saveContact({
    String? contactId,
    required String name,
    required String address,
    required ChainType chainType,
    String? note,
  }) async {
    final trimmedName = name.trim();
    final trimmedAddress = address.trim();
    final trimmedNote = _blankToNull(note);
    _validateName(trimmedName);
    _validateAddress(trimmedAddress, chainType);

    final repository = ref.read(addressBookRepositoryProvider);
    final now = ref.read(addressBookNowProvider)();
    final existing = contactId == null
        ? null
        : await _existingContact(repository: repository, contactId: contactId);

    final normalizedAddress = chainType == ChainType.sui
        ? normalizeSuiAddressInput(trimmedAddress)!
        : trimmedAddress;
    final contact = AddressBookContact(
      id: contactId ?? ref.read(addressBookIdFactoryProvider)(),
      name: trimmedName,
      address: normalizedAddress,
      chainType: chainType,
      note: trimmedNote,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    state = const AsyncLoading();
    try {
      final saved = await repository.saveContact(contact);
      state = AsyncData(await repository.listContacts());
      return saved;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void requestDeleteContact(String contactId) {
    _pendingDeleteContactId = contactId;
  }

  void cancelPendingDelete() {
    _pendingDeleteContactId = null;
  }

  Future<void> confirmPendingDelete() async {
    final contactId = _pendingDeleteContactId;
    if (contactId == null) {
      return;
    }

    final repository = ref.read(addressBookRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository.deleteContact(contactId);
      _pendingDeleteContactId = null;
      state = AsyncData(await repository.listContacts());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<List<AddressBookContact>> contactsForPicker(
    ChainType chainType,
  ) async {
    final contacts =
        state.value ??
        await ref.read(addressBookRepositoryProvider).listContacts();
    return List.unmodifiable(
      contacts.where((contact) => contact.chainType == chainType),
    );
  }

  Future<AddressBookContact> _existingContact({
    required AddressBookRepository repository,
    required String contactId,
  }) async {
    final contacts = state.value ?? await repository.listContacts();
    return contacts.firstWhere(
      (contact) => contact.id == contactId,
      orElse: () =>
          throw StateError('Address book contact not found: $contactId'),
    );
  }

  void _validateName(String name) {
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
  }

  void _validateAddress(String address, ChainType chainType) {
    if (!isValidAddressForChainType(address, chainType)) {
      throw ArgumentError.value(address, 'address', 'invalid address');
    }
  }
}

bool isValidAddressForChainType(String address, ChainType chainType) {
  final trimmed = address.trim();
  if (trimmed.isEmpty) {
    return false;
  }

  try {
    switch (chainType) {
      case ChainType.evm:
        return isValidEvmAddressInput(trimmed);
      case ChainType.solana:
        PublicKey.fromBase58(trimmed);
        return true;
      case ChainType.bitcoin:
        return isBitcoinAddress(trimmed);
      case ChainType.tron:
        return isValidTronAddress(trimmed);
      case ChainType.sui:
        return isValidSuiAddressInput(trimmed);
    }
  } catch (_) {
    return false;
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
