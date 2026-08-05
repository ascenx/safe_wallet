import 'package:wallet/wallet.dart' show EthereumAddress;

bool isValidEvmAddressInput(String value) {
  final trimmed = value.trim();
  if (!RegExp(r'^0[xX][a-fA-F0-9]{40}$').hasMatch(trimmed)) {
    return false;
  }
  final body = trimmed.substring(2);
  if (body == body.toLowerCase() || body == body.toUpperCase()) {
    return true;
  }
  try {
    final checksummed = EthereumAddress.fromHex(trimmed).eip55With0x;
    return checksummed == '0x$body';
  } catch (_) {
    return false;
  }
}
