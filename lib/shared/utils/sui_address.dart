String? normalizeSuiAddressInput(String value) {
  final trimmed = value.trim().toLowerCase();
  final hex = trimmed.startsWith('0x') ? trimmed.substring(2) : trimmed;
  if (hex.isEmpty || hex.length > 64 || !RegExp(r'^[0-9a-f]+$').hasMatch(hex)) {
    return null;
  }
  return '0x${hex.padLeft(64, '0')}';
}

bool isValidSuiAddressInput(String value) {
  return normalizeSuiAddressInput(value) != null;
}
