import 'package:flutter/widgets.dart';

enum AppLocaleMode {
  system,
  zh,
  en;

  Locale? get locale {
    return switch (this) {
      AppLocaleMode.system => null,
      AppLocaleMode.zh => const Locale('zh'),
      AppLocaleMode.en => const Locale('en'),
    };
  }

  String get persistenceValue => name;
}

extension AppLocaleModePersistence on AppLocaleMode {
  static AppLocaleMode fromValue(String? value) {
    return switch (value) {
      'zh' => AppLocaleMode.zh,
      'en' => AppLocaleMode.en,
      _ => AppLocaleMode.system,
    };
  }
}
