import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/address_book/application/address_book_controller.dart';
import 'package:safe_wallet/features/address_book/data/address_book_repository.dart';
import 'package:safe_wallet/features/address_book/domain/address_book_contact.dart';
import 'package:safe_wallet/features/address_book/presentation/address_book_page.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/widgets/app_action_sheet.dart';
import 'package:safe_wallet/shared/widgets/app_picker_field.dart';

void main() {
  testWidgets('add contact action is shown in the app bar', (tester) async {
    final repository = _FakeAddressBookRepository(const []);

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    final addContactButton = find.byTooltip('新增联系人');
    expect(addContactButton, findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: addContactButton,
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: addContactButton,
        matching: find.byIcon(AppIcons.add),
      ),
      findsOneWidget,
    );
  });

  testWidgets('contact chain type uses a picker and action sheet', (
    tester,
  ) async {
    final repository = _FakeAddressBookRepository(const []);

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('新增联系人'));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<ChainType>), findsNothing);
    final selector = find.byKey(const Key('contactChainTypeSelector'));
    expect(selector, findsOneWidget);
    expect(tester.widget<AppPickerField>(selector).value, 'EVM');

    await tester.tap(selector);
    await tester.pumpAndSettle();

    expect(find.byType(AppActionSheet<ChainType>), findsOneWidget);
    expect(find.text('EVM'), findsWidgets);
    expect(find.text('Solana'), findsOneWidget);
    expect(find.text('Bitcoin'), findsOneWidget);
    expect(find.text('Tron'), findsOneWidget);

    await tester.tap(find.text('Solana'));
    await tester.pumpAndSettle();

    expect(find.byType(AppActionSheet<ChainType>), findsNothing);
    expect(tester.widget<AppPickerField>(selector).value, 'Solana');
  });

  testWidgets('editing a contact updates the visible address book entry', (
    tester,
  ) async {
    final repository = _FakeAddressBookRepository([
      AddressBookContact(
        id: 'contact-1',
        name: 'Alice',
        address: _aliceAddress,
        chainType: ChainType.evm,
        note: 'Old note',
        createdAt: _createdAt,
        updatedAt: _createdAt,
      ),
    ]);

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Old note'), findsOneWidget);

    await tester.tap(find.byTooltip('编辑联系人'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '联系人名称'), 'Bob');
    await tester.enterText(
      find.widgetWithText(TextField, '备注'),
      'Updated note',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repository.contacts, hasLength(1));
    expect(repository.contacts.single.id, 'contact-1');
    expect(repository.contacts.single.name, 'Bob');
    expect(repository.contacts.single.address, _aliceAddress);
    expect(repository.contacts.single.note, 'Updated note');
    expect(repository.contacts.single.createdAt, _createdAt);
    expect(repository.contacts.single.updatedAt, _updatedAt);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Updated note'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
    expect(find.text('Old note'), findsNothing);
  });

  testWidgets('editing a contact rejects an invalid address before saving', (
    tester,
  ) async {
    final repository = _FakeAddressBookRepository([
      AddressBookContact(
        id: 'contact-1',
        name: 'Alice',
        address: _aliceAddress,
        chainType: ChainType.evm,
        note: 'Friend',
        createdAt: _createdAt,
        updatedAt: _createdAt,
      ),
    ]);

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('编辑联系人'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '钱包地址'),
      'not-an-address',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('地址格式与链类型不匹配'), findsOneWidget);
    expect(find.text('编辑联系人'), findsWidgets);
    expect(repository.saveContactCalls, 0);
    expect(repository.contacts.single.address, _aliceAddress);
  });

  testWidgets('adding a Bitcoin contact saves the selected chain type', (
    tester,
  ) async {
    final repository = _FakeAddressBookRepository(const []);

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('新增联系人'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contactChainTypeSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bitcoin'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '联系人名称'), 'Sats');
    await tester.enterText(
      find.widgetWithText(TextField, '钱包地址'),
      _bitcoinAddress,
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repository.contacts, hasLength(1));
    expect(repository.contacts.single.name, 'Sats');
    expect(repository.contacts.single.address, _bitcoinAddress);
    expect(repository.contacts.single.chainType, ChainType.bitcoin);
    expect(find.text('Bitcoin'), findsOneWidget);
  });

  testWidgets('Bitcoin contacts reject non Bitcoin addresses before saving', (
    tester,
  ) async {
    final repository = _FakeAddressBookRepository(const []);

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('新增联系人'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contactChainTypeSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bitcoin'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '联系人名称'), 'Bad');
    await tester.enterText(
      find.widgetWithText(TextField, '钱包地址'),
      _aliceAddress,
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('地址格式与链类型不匹配'), findsOneWidget);
    expect(repository.saveContactCalls, 0);
  });

  testWidgets('deleting a contact requires confirmation', (tester) async {
    final repository = _FakeAddressBookRepository([
      AddressBookContact(
        id: 'contact-1',
        name: 'Alice',
        address: _aliceAddress,
        chainType: ChainType.evm,
        note: 'Friend',
        createdAt: _createdAt,
        updatedAt: _createdAt,
      ),
    ]);

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除联系人'), findsOneWidget);
    expect(repository.deletedContactIds, isEmpty);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(repository.deletedContactIds, isEmpty);

    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(repository.deletedContactIds, ['contact-1']);
    expect(find.text('Alice'), findsNothing);
    expect(find.text('暂无联系人'), findsOneWidget);
  });
}

Widget _app(_FakeAddressBookRepository repository) {
  return ProviderScope(
    overrides: [
      addressBookRepositoryProvider.overrideWithValue(repository),
      addressBookNowProvider.overrideWithValue(() => _updatedAt),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const AddressBookPage(),
      ),
    ),
  );
}

final class _FakeAddressBookRepository implements AddressBookRepository {
  _FakeAddressBookRepository(List<AddressBookContact> initialContacts)
      : contacts = [...initialContacts];

  final List<AddressBookContact> contacts;
  final deletedContactIds = <String>[];
  int saveContactCalls = 0;

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
    saveContactCalls += 1;
    contacts.removeWhere((existing) => existing.id == contact.id);
    contacts.add(contact);
    return contact;
  }
}

final _createdAt = DateTime.utc(2026, 6, 6, 10);
final _updatedAt = DateTime.utc(2026, 6, 6, 11);
const _aliceAddress = '0x1111111111111111111111111111111111111111';
const _bitcoinAddress = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';
