import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chains/domain/chain_config.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../domain/recipient_picker_entry.dart';
import 'address_book_controller.dart';

typedef RecipientPickerRequest = ({
  ChainType chainType,
  String? currentWalletId,
});

final recipientPickerDataProvider = FutureProvider.autoDispose
    .family<RecipientPickerData, RecipientPickerRequest>((ref, request) async {
      final contacts = await ref.watch(addressBookControllerProvider.future);
      final contactEntries = contacts
          .where((contact) => contact.chainType == request.chainType)
          .map(
            (contact) => RecipientPickerEntry(
              id: 'contact:${contact.id}',
              name: contact.name,
              address: contact.address,
              source: RecipientPickerEntrySource.contact,
            ),
          )
          .toList(growable: false);

      final currentWalletId = request.currentWalletId;
      if (currentWalletId == null) {
        return RecipientPickerData(
          wallets: const [],
          contacts: List.unmodifiable(contactEntries),
        );
      }

      final wallets = await ref.watch(walletRepositoryProvider).getWallets();
      final walletEntries = wallets
          .where((wallet) => wallet.id != currentWalletId)
          .map((wallet) {
            final address = wallet
                .addressForChainType(request.chainType)
                .trim();
            if (address.isEmpty) {
              return null;
            }
            return RecipientPickerEntry(
              id: 'wallet:${wallet.id}',
              name: wallet.name,
              address: address,
              source: RecipientPickerEntrySource.wallet,
            );
          })
          .whereType<RecipientPickerEntry>()
          .toList(growable: false);

      return RecipientPickerData(
        wallets: List.unmodifiable(walletEntries),
        contacts: List.unmodifiable(contactEntries),
      );
    });
