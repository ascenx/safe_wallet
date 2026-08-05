import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/storage_keys.dart';

enum AppFiatCurrency {
  usd(code: 'USD', symbol: r'$'),
  cny(code: 'CNY', symbol: '¥'),
  eur(code: 'EUR', symbol: '€'),
  jpy(code: 'JPY', symbol: '¥');

  const AppFiatCurrency({required this.code, required this.symbol});

  final String code;
  final String symbol;
}

String formatFiatValue(double value, AppFiatCurrency currency) {
  final sign = value < 0 ? '-' : '';
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = _withThousandsSeparators(parts.first);
  return '$sign${currency.symbol}$whole.${parts[1]}';
}

String _withThousandsSeparators(String value) {
  final buffer = StringBuffer();
  for (var index = 0; index < value.length; index += 1) {
    final remaining = value.length - index;
    buffer.write(value[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

final fiatCurrencySettingStoreProvider = Provider<FiatCurrencySettingStore>(
  (ref) => InMemoryFiatCurrencySettingStore(),
);

final fiatCurrencySettingProvider =
    AsyncNotifierProvider<FiatCurrencySettingController, AppFiatCurrency>(
  FiatCurrencySettingController.new,
);

abstract interface class FiatCurrencySettingStore {
  Future<String?> readCurrencyCode();

  Future<void> saveCurrencyCode(String value);
}

final class InMemoryFiatCurrencySettingStore
    implements FiatCurrencySettingStore {
  InMemoryFiatCurrencySettingStore({String? currencyCode})
      : _currencyCode = currencyCode;

  String? _currencyCode;

  @override
  Future<String?> readCurrencyCode() async => _currencyCode;

  @override
  Future<void> saveCurrencyCode(String value) async {
    _currencyCode = value;
  }
}

final class HiveFiatCurrencySettingStore implements FiatCurrencySettingStore {
  HiveFiatCurrencySettingStore({required HiveBoxRegistry registry})
      : _registry = registry;

  final HiveBoxRegistry _registry;

  @override
  Future<String?> readCurrencyCode() async {
    final value = _registry.settingsBox.get(StorageKeys.fiatCurrencyCode);
    return value is String ? value : null;
  }

  @override
  Future<void> saveCurrencyCode(String value) {
    return _registry.settingsBox.put(StorageKeys.fiatCurrencyCode, value);
  }
}

final class FiatCurrencySettingController
    extends AsyncNotifier<AppFiatCurrency> {
  @override
  Future<AppFiatCurrency> build() async {
    final storedCode =
        await ref.read(fiatCurrencySettingStoreProvider).readCurrencyCode();
    return AppFiatCurrency.values
            .where((currency) => currency.code == storedCode)
            .firstOrNull ??
        AppFiatCurrency.usd;
  }

  Future<void> setCurrency(AppFiatCurrency value) async {
    state = AsyncData(value);
    await ref
        .read(fiatCurrencySettingStoreProvider)
        .saveCurrencyCode(value.code);
  }
}
