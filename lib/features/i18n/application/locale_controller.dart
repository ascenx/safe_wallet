import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_locale_mode.dart';
import 'locale_preference_store.dart';

export 'app_locale_mode.dart';

final localePreferenceStoreProvider = Provider<LocalePreferenceStore>((ref) {
  return InMemoryLocalePreferenceStore();
});

final localeControllerProvider =
    AsyncNotifierProvider<LocaleController, AppLocaleMode>(
  LocaleController.new,
);

final appLocaleProvider = Provider<Locale?>((ref) {
  final localeState = ref.watch(localeControllerProvider);
  final mode = localeState.hasValue ? localeState.value : null;
  return mode?.locale;
});

final class LocaleController extends AsyncNotifier<AppLocaleMode> {
  @override
  Future<AppLocaleMode> build() {
    return ref.watch(localePreferenceStoreProvider).readLocaleMode();
  }

  Future<void> setMode(AppLocaleMode mode) async {
    final store = ref.read(localePreferenceStoreProvider);
    state = const AsyncLoading();
    await store.saveLocaleMode(mode);
    state = AsyncData(mode);
  }
}
