import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/json_codec.dart';
import '../../chains/domain/chain_config.dart';
import '../domain/address_book_contact.dart';
import 'address_book_repository.dart';

final class HiveAddressBookRepository implements AddressBookRepository {
  HiveAddressBookRepository({
    required HiveBoxRegistry registry,
    StorageJsonCodec codec = const StorageJsonCodec(),
  }) : _registry = registry,
       _codec = codec;

  final HiveBoxRegistry _registry;
  final StorageJsonCodec _codec;

  @override
  Future<List<AddressBookContact>> listContacts() async {
    final contacts =
        _registry.addressBookBox.values
            .whereType<String>()
            .map((value) => _codec.tryDecode(value, _contactFromJson))
            .whereType<AddressBookContact>()
            .toList()
          ..sort(_compareContacts);
    return List.unmodifiable(contacts);
  }

  @override
  Future<AddressBookContact> saveContact(AddressBookContact contact) async {
    _validateContact(contact);
    await _registry.addressBookBox.put(
      contact.id,
      _codec.encode(_contactToJson(contact)),
    );
    return contact;
  }

  @override
  Future<void> deleteContact(String contactId) async {
    await _registry.addressBookBox.delete(contactId);
  }

  void _validateContact(AddressBookContact contact) {
    if (contact.id.trim().isEmpty) {
      throw ArgumentError.value(contact.id, 'id', 'must not be empty');
    }
    if (contact.name.trim().isEmpty) {
      throw ArgumentError.value(contact.name, 'name', 'must not be empty');
    }
    if (contact.address.trim().isEmpty) {
      throw ArgumentError.value(
        contact.address,
        'address',
        'must not be empty',
      );
    }
  }

  int _compareContacts(AddressBookContact left, AddressBookContact right) {
    final chainCompare = left.chainType.index.compareTo(right.chainType.index);
    if (chainCompare != 0) {
      return chainCompare;
    }
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }

  Map<String, Object?> _contactToJson(AddressBookContact contact) {
    return {
      'id': contact.id,
      'name': contact.name,
      'address': contact.address,
      'chainType': contact.chainType.name,
      'note': contact.note,
      'createdAt': contact.createdAt.toIso8601String(),
      'updatedAt': contact.updatedAt.toIso8601String(),
    };
  }

  AddressBookContact _contactFromJson(Map<String, Object?> json) {
    return AddressBookContact(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      chainType: ChainType.values.byName(json['chainType'] as String),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
