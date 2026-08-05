enum RecipientPickerEntrySource { wallet, contact }

final class RecipientPickerEntry {
  const RecipientPickerEntry({
    required this.id,
    required this.name,
    required this.address,
    required this.source,
  });

  final String id;
  final String name;
  final String address;
  final RecipientPickerEntrySource source;
}

final class RecipientPickerData {
  const RecipientPickerData({required this.wallets, required this.contacts});

  final List<RecipientPickerEntry> wallets;
  final List<RecipientPickerEntry> contacts;

  bool get isEmpty => wallets.isEmpty && contacts.isEmpty;
}
