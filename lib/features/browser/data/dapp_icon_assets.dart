import '../domain/dapp_entry.dart';

const _svgDappIconIds = {
  'ankr-staking',
  'benqi-staked-avax',
  'camelot',
  'cow-swap',
  'curve',
  'exsat-bridge',
  'lido-impact-staking',
  'myriad-markets',
  'polymarket',
  'sorare-bridge',
  'sport-fun',
  'stakee',
  'stakestone',
  'treasure-bridge',
};

String? dappIconAssetPath(DappEntry entry) {
  final scheme = Uri.tryParse(entry.url)?.scheme;
  if (!entry.isDefault || (scheme != 'http' && scheme != 'https')) {
    return null;
  }
  final extension = _svgDappIconIds.contains(entry.id) ? 'svg' : 'png';
  return 'assets/dapp_icons/${entry.id}.$extension';
}
