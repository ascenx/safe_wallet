abstract interface class AppError implements Exception {
  String get code;

  String get safeMessageKey;

  String get debugMessage;
}
