import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/address_book/application/address_book_controller.dart';
import 'package:safe_wallet/features/address_book/data/address_book_repository.dart';
import 'package:safe_wallet/features/address_book/domain/address_book_contact.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';

void main() {
  group('AddressBookController', () {
    late DateTime now;
    late _FakeAddressBookRepository repository;
    late ProviderContainer container;

    setUp(() {
      now = DateTime.utc(2026, 6, 6, 12);
      repository = _FakeAddressBookRepository();
      container = ProviderContainer(
        overrides: [
          addressBookRepositoryProvider.overrideWithValue(repository),
          addressBookNowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
    });

    test('rejects invalid EVM address before saving', () async {
      await expectLater(
        container
            .read(addressBookControllerProvider.notifier)
            .saveContact(
              name: 'Bad EVM',
              address: 'not-an-evm-address',
              chainType: ChainType.evm,
            ),
        throwsArgumentError,
      );

      expect(repository.contacts, isEmpty);
    });

    test('rejects an EVM address with an invalid mixed-case checksum', () {
      expect(
        isValidAddressForChainType(
          '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAED',
          ChainType.evm,
        ),
        isFalse,
      );
      expect(
        isValidAddressForChainType(
          '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
          ChainType.evm,
        ),
        isTrue,
      );
      expect(
        isValidAddressForChainType(
          '0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed',
          ChainType.evm,
        ),
        isTrue,
      );
    });

    test('rejects invalid Solana address before saving', () async {
      await expectLater(
        container
            .read(addressBookControllerProvider.notifier)
            .saveContact(
              name: 'Bad Solana',
              address: 'not-a-solana-address',
              chainType: ChainType.solana,
            ),
        throwsArgumentError,
      );

      expect(repository.contacts, isEmpty);
    });

    test('accepts and normalizes a short Sui address before saving', () async {
      final saved = await container
          .read(addressBookControllerProvider.notifier)
          .saveContact(
            name: 'Sui Friend',
            address: '0X2',
            chainType: ChainType.sui,
          );

      expect(saved.chainType, ChainType.sui);
      expect(
        saved.address,
        '0x0000000000000000000000000000000000000000000000000000000000000002',
      );
    });

    test('rejects malformed Sui addresses before saving', () async {
      await expectLater(
        container
            .read(addressBookControllerProvider.notifier)
            .saveContact(
              name: 'Bad Sui',
              address: '0xgg',
              chainType: ChainType.sui,
            ),
        throwsArgumentError,
      );
    });

    test('accepts valid Bitcoin address formats before saving', () async {
      const addresses = [
        'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
        '1BoatSLRHtKNngkdXEeobR76b53LETtpyT',
        'bc1ph4lmxwklchcvvh2wchzassw86yvahdt902mpe0velxzuz2c70sps70mzj4',
      ];

      for (final address in addresses) {
        final saved = await container
            .read(addressBookControllerProvider.notifier)
            .saveContact(
              name: 'Bitcoin Friend',
              address: address,
              chainType: ChainType.bitcoin,
            );

        expect(saved.chainType, ChainType.bitcoin);
        expect(repository.contacts.last.address, address);
      }

      expect(repository.contacts.map((contact) => contact.address), addresses);
    });

    test(
      'rejects Bitcoin addresses with an invalid checksum before saving',
      () async {
        await expectLater(
          container
              .read(addressBookControllerProvider.notifier)
              .saveContact(
                name: 'Bad Bitcoin',
                address: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyv',
                chainType: ChainType.bitcoin,
              ),
          throwsArgumentError,
        );

        expect(repository.contacts, isEmpty);
      },
    );

    test('deletes only after delete confirmation path is completed', () async {
      final saved = await container
          .read(addressBookControllerProvider.notifier)
          .saveContact(
            name: 'Ethereum Friend',
            address: '0x1111111111111111111111111111111111111111',
            chainType: ChainType.evm,
          );

      container
          .read(addressBookControllerProvider.notifier)
          .requestDeleteContact(saved.id);

      expect(repository.deletedContactIds, isEmpty);

      await container
          .read(addressBookControllerProvider.notifier)
          .confirmPendingDelete();

      expect(repository.deletedContactIds, [saved.id]);
      expect(repository.contacts, isEmpty);
    });

    test('picker contacts are filtered by chain type', () async {
      await container
          .read(addressBookControllerProvider.notifier)
          .saveContact(
            name: 'Ethereum Friend',
            address: '0x2222222222222222222222222222222222222222',
            chainType: ChainType.evm,
          );
      await container
          .read(addressBookControllerProvider.notifier)
          .saveContact(
            name: 'Solana Friend',
            address: 'So11111111111111111111111111111111111111112',
            chainType: ChainType.solana,
          );
      await container
          .read(addressBookControllerProvider.notifier)
          .saveContact(
            name: 'Bitcoin Friend',
            address: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
            chainType: ChainType.bitcoin,
          );

      final evmContacts = await container.read(
        addressBookContactsForPickerProvider(ChainType.evm).future,
      );
      final bitcoinContacts = await container.read(
        addressBookContactsForPickerProvider(ChainType.bitcoin).future,
      );

      expect(evmContacts, hasLength(1));
      expect(evmContacts.single.name, 'Ethereum Friend');
      expect(evmContacts.single.chainType, ChainType.evm);
      expect(bitcoinContacts, hasLength(1));
      expect(bitcoinContacts.single.name, 'Bitcoin Friend');
      expect(bitcoinContacts.single.chainType, ChainType.bitcoin);
    });
  });
}

final class _FakeAddressBookRepository implements AddressBookRepository {
  final contacts = <AddressBookContact>[];
  final deletedContactIds = <String>[];

  @override
  Future<void> deleteContact(String contactId) async {
    deletedContactIds.add(contactId);
    contacts.removeWhere((contact) => contact.id == contactId);
  }

  @override
  Future<List<AddressBookContact>> listContacts() async {
    return List.unmodifiable(contacts);
  }

  @override
  Future<AddressBookContact> saveContact(AddressBookContact contact) async {
    contacts.removeWhere((existing) => existing.id == contact.id);
    contacts.add(contact);
    return contact;
  }
}
