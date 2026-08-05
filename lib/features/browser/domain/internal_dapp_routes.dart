const solanaDappTestId = 'solana-dapp-test';
const solanaDappTestUrl = 'safewallet://solana-dapp-test';

bool isSolanaDappTestUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      uri.scheme == 'safewallet' &&
      uri.host == 'solana-dapp-test';
}
