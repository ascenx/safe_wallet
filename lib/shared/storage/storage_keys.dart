final class StorageKeys {
  const StorageKeys._();

  static const walletsBox = 'walletsBox';
  static const chainsBox = 'chainsBox';
  static const rpcNodesBox = 'rpcNodesBox';
  static const tokensBox = 'tokensBox';
  static const tokenPricesBox = 'tokenPricesBox';
  static const tokenBalancesBox = 'tokenBalancesBox';
  static const transactionsBox = 'transactionsBox';
  static const dappPermissionsBox = 'dappPermissionsBox';
  static const dappCatalogBox = 'dappCatalogBox';
  static const browserStateBox = 'browserStateBox';
  static const addressBookBox = 'addressBookBox';
  static const securityLogsBox = 'securityLogsBox';
  static const settingsBox = 'settingsBox';

  static const schemaVersion = 'schemaVersion';
  static const globalPasswordVerifier = 'globalPasswordVerifier';
  static const pendingWalletMutation = 'pendingWalletMutation';
  static const pendingWalletDeletionCleanup = 'pendingWalletDeletionCleanup';
  static const selectedChainId = 'selectedChainId';
  static const selectedWalletId = 'selectedWalletId';
  static const requirePasswordOnLaunch = 'requirePasswordOnLaunch';
  static const backgroundPrivacyShieldEnabled =
      'backgroundPrivacyShieldEnabled';
  static const walletAutoLockDuration = 'walletAutoLockDuration';
  static const localeModeId = 'localeModeId';
  static const themeModeId = 'themeModeId';
  static const themeColorId = 'themeColorId';
  static const fiatCurrencyCode = 'fiatCurrencyCode';
  static const walletConnectProjectId = 'walletConnectProjectId';
  static const walletConnectErrorResponseOutbox =
      'walletConnectErrorResponseOutbox';
  static const fiatExchangeRatePrefix = 'fiatExchangeRate:';
  static const selectedRpcNodeIdPrefix = 'selectedRpcNodeId';

  static const requiredBoxNames = [
    walletsBox,
    chainsBox,
    rpcNodesBox,
    tokensBox,
    tokenPricesBox,
    tokenBalancesBox,
    transactionsBox,
    dappPermissionsBox,
    dappCatalogBox,
    browserStateBox,
    addressBookBox,
    securityLogsBox,
    settingsBox,
  ];
}
