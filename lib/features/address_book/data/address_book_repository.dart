import '../domain/address_book_contact.dart';

abstract interface class AddressBookRepository {
  Future<List<AddressBookContact>> listContacts();

  Future<AddressBookContact> saveContact(AddressBookContact contact);

  Future<void> deleteContact(String contactId);
}
