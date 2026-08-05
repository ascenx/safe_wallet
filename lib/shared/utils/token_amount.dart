String formatTokenAmount(BigInt value, {required int decimals}) {
  if (decimals <= 0) {
    return value.toString();
  }
  final negative = value.isNegative;
  final absolute = value.abs();
  final base = BigInt.from(10).pow(decimals);
  final whole = absolute ~/ base;
  final fraction = (absolute % base)
      .toString()
      .padLeft(decimals, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  final sign = negative ? '-' : '';
  return fraction.isEmpty ? '$sign$whole' : '$sign$whole.$fraction';
}
