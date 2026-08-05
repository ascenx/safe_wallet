enum AddressRiskKind { knownRecipient, newRecipient, lookalike }

final class AddressRiskResult {
  const AddressRiskResult(this.kind, {this.similarAddress});

  final AddressRiskKind kind;
  final String? similarAddress;
}

AddressRiskResult detectAddressRisk({
  required String recipient,
  required Iterable<String> historicalRecipients,
}) {
  final normalizedRecipient = _normalizeAddress(recipient);
  final historical = historicalRecipients
      .where((address) => address.trim().isNotEmpty)
      .toList(growable: false);
  for (final address in historical) {
    if (_normalizeAddress(address) == normalizedRecipient) {
      return const AddressRiskResult(AddressRiskKind.knownRecipient);
    }
  }
  for (final address in historical) {
    final candidate = _normalizeAddress(address);
    if (_looksSimilar(normalizedRecipient, candidate)) {
      return AddressRiskResult(
        AddressRiskKind.lookalike,
        similarAddress: address,
      );
    }
  }
  return const AddressRiskResult(AddressRiskKind.newRecipient);
}

String _normalizeAddress(String address) {
  final normalized = address.trim().toLowerCase();
  return normalized.startsWith('0x') ? normalized.substring(2) : normalized;
}

bool _looksSimilar(String left, String right) {
  const edgeLength = 6;
  if (left == right ||
      left.length < edgeLength * 2 ||
      right.length < edgeLength * 2) {
    return false;
  }
  return left.substring(0, edgeLength) == right.substring(0, edgeLength) &&
      left.substring(left.length - edgeLength) ==
          right.substring(right.length - edgeLength);
}
