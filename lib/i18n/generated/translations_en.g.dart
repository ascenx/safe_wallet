///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'translations.g.dart';

// Path: <root>
class TranslationsEn extends Translations
    with BaseTranslations<AppLocale, Translations> {
  /// You can call this constructor and build your own translation instance of this locale.
  /// Constructing via the enum [AppLocale.build] is preferred.
  TranslationsEn({
    Map<String, Node>? overrides,
    PluralResolver? cardinalResolver,
    PluralResolver? ordinalResolver,
    TranslationMetadata<AppLocale, Translations>? meta,
  }) : assert(
         overrides == null,
         'Set "translation_overrides: true" in order to enable this feature.',
       ),
       $meta =
           meta ??
           TranslationMetadata(
             locale: AppLocale.en,
             overrides: overrides ?? {},
             cardinalResolver: cardinalResolver,
             ordinalResolver: ordinalResolver,
           ),
       super(
         cardinalResolver: cardinalResolver,
         ordinalResolver: ordinalResolver,
       ) {
    super.$meta.setFlatMapFunction(
      $meta.getTranslation,
    ); // copy base translations to super.$meta
    $meta.setFlatMapFunction(_flatMapFunction);
  }

  /// Metadata for the translations of <en>.
  @override
  final TranslationMetadata<AppLocale, Translations> $meta;

  /// Access flat map
  @override
  dynamic operator [](String key) =>
      $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

  late final TranslationsEn _root = this; // ignore: unused_field

  @override
  TranslationsEn $copyWith({
    TranslationMetadata<AppLocale, Translations>? meta,
  }) => TranslationsEn(meta: meta ?? this.$meta);

  // Translations
  @override
  late final _Translations$app$en app = _Translations$app$en._(_root);
  @override
  late final _Translations$tabs$en tabs = _Translations$tabs$en._(_root);
  @override
  late final _Translations$actions$en actions = _Translations$actions$en._(
    _root,
  );
  @override
  late final _Translations$onboarding$en onboarding =
      _Translations$onboarding$en._(_root);
  @override
  late final _Translations$home$en home = _Translations$home$en._(_root);
  @override
  late final _Translations$browser$en browser = _Translations$browser$en._(
    _root,
  );
  @override
  late final _Translations$dapp$en dapp = _Translations$dapp$en._(_root);
  @override
  late final _Translations$chains$en chains = _Translations$chains$en._(_root);
  @override
  late final _Translations$nodes$en nodes = _Translations$nodes$en._(_root);
  @override
  late final _Translations$tokens$en tokens = _Translations$tokens$en._(_root);
  @override
  late final _Translations$assets$en assets = _Translations$assets$en._(_root);
  @override
  late final _Translations$transactions$en transactions =
      _Translations$transactions$en._(_root);
  @override
  late final _Translations$transfer$en transfer = _Translations$transfer$en._(
    _root,
  );
  @override
  late final _Translations$addressBook$en addressBook =
      _Translations$addressBook$en._(_root);
  @override
  late final _Translations$wallet$en wallet = _Translations$wallet$en._(_root);
  @override
  late final _Translations$settings$en settings = _Translations$settings$en._(
    _root,
  );
  @override
  late final _Translations$tronStaking$en tronStaking =
      _Translations$tronStaking$en._(_root);
  @override
  late final _Translations$advanced$en advanced = _Translations$advanced$en._(
    _root,
  );
  @override
  late final _Translations$about$en about = _Translations$about$en._(_root);
  @override
  late final _Translations$errors$en errors = _Translations$errors$en._(_root);
}

// Path: app
class _Translations$app$en extends Translations$app$zh {
  _Translations$app$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get name => 'Safe Wallet';
}

// Path: tabs
class _Translations$tabs$en extends Translations$tabs$zh {
  _Translations$tabs$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get home => 'Home';
  @override
  String get browser => 'Browser';
  @override
  String get settings => 'Settings';
}

// Path: actions
class _Translations$actions$en extends Translations$actions$zh {
  _Translations$actions$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get receive => 'Receive';
  @override
  String get send => 'Send';
  @override
  String get scan => 'Scan';
  @override
  String get confirm => 'Confirm';
  @override
  String get submit => 'Submit';
  @override
  String get cancel => 'Cancel';
  @override
  String get kContinue => 'Continue';
  @override
  String get done => 'Done';
  @override
  String get back => 'Back';
  @override
  String get close => 'Close';
  @override
  String get paste => 'Paste';
  @override
  String get exitAppHint => 'Go back again to exit the app';
  @override
  String get showPassword => 'Show password';
  @override
  String get hidePassword => 'Hide password';
}

// Path: onboarding
class _Translations$onboarding$en extends Translations$onboarding$zh {
  _Translations$onboarding$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get entryTitle => 'Start with a secure wallet';
  @override
  String get entrySubtitle =>
      'Create a new wallet or import an existing one. Private keys and mnemonics stay encrypted on this device.';
  @override
  String get createWallet => 'Create Wallet';
  @override
  String get importWallet => 'Import Wallet';
  @override
  String get createTitle => 'Create New Wallet';
  @override
  String get createBody =>
      'The app will generate a new mnemonic and derive default EVM, Bitcoin, Tron, Solana, and Sui addresses.';
  @override
  String get riskTitle => 'Mnemonic Risk Notice';
  @override
  String get riskLoss => 'A lost mnemonic means the wallet cannot be recovered';
  @override
  String get riskResponsibility =>
      'Keep your mnemonic yourself. Anyone with it can control your assets, and the app cannot restore or freeze the wallet for you.';
  @override
  String get riskNoBackupGate =>
      'The MVP does not require backup verification, but you must understand the risk before entering the wallet.';
  @override
  String get riskAccepted => 'I understand the risk';
  @override
  String get importTitle => 'Import Wallet';
  @override
  String get importBody =>
      'Import with a mnemonic, EVM private key, Bitcoin private key, Tron private key, Solana private key, or Sui suiprivkey. The material is encrypted after you set a password.';
  @override
  String get importMnemonic => 'Mnemonic';
  @override
  String get importPrivateKey => 'Private Key';
  @override
  String get importMnemonicWallet => 'Mnemonic Wallet';
  @override
  String get importPrivateKeyWallet => 'Private Key Wallet';
  @override
  String get importMnemonicWalletDescription => 'Multi-chain wallet';
  @override
  String get importPrivateKeyWalletDescription =>
      'EVM, Bitcoin, Tron, Solana, or Sui wallet';
  @override
  String get selectImportType => 'Choose Import Type';
  @override
  String get selectPrivateKeyChain => 'Choose Private Key Network';
  @override
  String get importEvm => 'EVM';
  @override
  String get importBitcoin => 'Bitcoin';
  @override
  String get importTron => 'Tron';
  @override
  String get importSolana => 'Solana';
  @override
  String get importSui => 'Sui';
  @override
  String get mnemonicHint =>
      'Enter your mnemonic, 12 or 24 words separated by spaces';
  @override
  String get mnemonicWordHint => 'Enter word';
  @override
  String get mnemonicWordCount12 => '12 English words';
  @override
  String get mnemonicWordCount24 => '24 English words';
  @override
  String get mnemonicHelp => 'How to get it?';
  @override
  String get mnemonicImportHint =>
      'Enter a mnemonic to import an existing wallet';
  @override
  String get privateKeyHint =>
      'EVM hex, Bitcoin WIF/hex, Solana private key, or Sui suiprivkey';
  @override
  String get setPasswordTitle => 'Set Wallet Password';
  @override
  String get setPasswordBody =>
      'This password unlocks the local wallet and encrypts wallet data. If you forget it, you must re-import your mnemonic or private key.';
  @override
  String get passwordLabel => 'Wallet Password';
  @override
  String get confirmPasswordLabel => 'Confirm Password';
  @override
  String get passwordRequired => 'Enter a wallet password';
  @override
  String get passwordMismatch => 'The passwords do not match';
  @override
  String get importMaterialRequired => 'Enter import material';
  @override
  String get loadingWallet => 'Loading wallet';
  @override
  String get creatingWallet => 'Creating wallet';
  @override
  String get importingWallet => 'Importing wallet';
}

// Path: home
class _Translations$home$en extends Translations$home$zh {
  _Translations$home$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get defaultWalletName => 'My Wallet';
  @override
  String get totalValue => 'Total Value';
  @override
  String get hideAmounts => 'Hide Amounts';
  @override
  String get showAmounts => 'Show Amounts';
  @override
  String get recentTransactions => 'Recent Transactions';
  @override
  String get viewAll => 'View All';
  @override
  String get assetList => 'Assets';
  @override
  String get manageTokens => 'Manage Tokens';
  @override
  String get refreshAssets => 'Refresh Assets';
  @override
  String get emptyTransactions => 'No transactions';
  @override
  String get noWallet => 'No wallet yet';
  @override
  String get walletLocked => 'Wallet locked';
  @override
  String get loadingAssets => 'Loading assets';
  @override
  String get emptyAssets => 'No assets';
  @override
  String get assetLoadError => 'Failed to load assets';
}

// Path: browser
class _Translations$browser$en extends Translations$browser$zh {
  _Translations$browser$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get commonDapps => 'Common dApps';
  @override
  String get urlHint => 'Search dApps or enter a URL';
  @override
  String get invalidUrl => 'Enter a valid URL';
  @override
  String get loadFailed =>
      'Unable to open dApp. Check the URL or network and try again.';
  @override
  String get confirmExternalTitle => 'Open Website?';
  @override
  String get confirmExternalBody =>
      'Confirm the website domain before opening to avoid disguised sites.';
  @override
  String get openExternal => 'Open';
  @override
  String get swap => 'Swap';
  @override
  String get predictions => 'Predictions';
  @override
  String get staking => 'Staking';
  @override
  String get bridge => 'Bridge';
  @override
  String get swapAggregator => 'Aggregator';
  @override
  String get swapDex => 'DEX';
  @override
  String get swapMeme => 'Meme';
  @override
  String get swapCrossChain => 'Cross-chain';
  @override
  String get riskHigh => 'High risk';
  @override
  String get all => 'All';
  @override
  String get networkFilter => 'Network';
  @override
  String get typeFilter => 'Type';
  @override
  String get allNetworks => 'All networks';
  @override
  String get allTypes => 'All types';
  @override
  String get selectNetwork => 'Select network';
  @override
  String get selectType => 'Select type';
  @override
  String get defi => 'DeFi';
  @override
  String get nft => 'NFT';
  @override
  String get tools => 'Tools';
  @override
  String get favorites => 'Favorites';
  @override
  String get recent => 'Recent';
  @override
  String get emptyFavorites => 'No favorites';
  @override
  String get emptyRecent => 'No recent visits';
  @override
  String get noResults => 'No matching dApps';
  @override
  String get favorite => 'Favorite';
  @override
  String get unfavorite => 'Unfavorite';
  @override
  String get forward => 'Forward';
  @override
  String get refresh => 'Refresh';
}

// Path: dapp
class _Translations$dapp$en extends Translations$dapp$zh {
  _Translations$dapp$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get authorizationTitle => 'Connect dApp';
  @override
  String get authorizationBody =>
      'After approval, this site can read the current account address and request signature or transaction confirmations.';
  @override
  String get rememberAuthorization => 'Remember this site for 30 days';
  @override
  String get signatureTitle => 'Confirm Signature';
  @override
  String get transactionTitle => 'Confirm Transaction';
  @override
  String get chainSwitchTitle => 'Switch Network';
  @override
  String get chainSwitchBody =>
      'This site requests switching the active EVM network. Review before continuing.';
  @override
  String get domain => 'Domain';
  @override
  String get chain => 'Network';
  @override
  String get requestedChain => 'Target Network';
  @override
  String get account => 'Account';
  @override
  String get from => 'From';
  @override
  String get to => 'To';
  @override
  String get value => 'Value';
  @override
  String get contract => 'Contract';
  @override
  String get feeEstimate => 'Fee Estimate';
  @override
  String get decodedInfo => 'Decoded Info';
  @override
  String get rawTransactionData => 'Raw Transaction Data';
  @override
  String get message => 'Message';
  @override
  String get approve => 'Approve';
  @override
  String get reject => 'Reject';
  @override
  String get signatureRiskWarning =>
      'Review the content and site before signing. A signature can represent login, authorization, or another off-chain statement.';
  @override
  String get unreadableSignatureWarning =>
      'This signature content is unreadable. Continue only if you fully trust this site.';
  @override
  String get unparsedTransactionWarning =>
      'This transaction includes an unparsed contract call. Check the site and contract address carefully.';
  @override
  String simulationFailedWarning({required Object reason}) =>
      'Transaction simulation failed: ${reason}';
  @override
  String get solanaTestTitle => 'Solana dApp Test';
  @override
  String get solanaTestBody =>
      'This internal page validates the Solana dApp interface boundary. Full external support will ship in a later version.';
  @override
  String get solanaBoundaryReserved => 'Solana dApp Interface Reserved';
  @override
  String get solanaConnectCheck => 'Connection request boundary is reserved';
  @override
  String get solanaSignCheck => 'Message signing boundary is reserved';
  @override
  String get solanaTransactionCheck =>
      'Transaction request boundary is reserved';
  @override
  String get solanaNonSolanaChain => 'No Solana network is selected';
  @override
  String get solanaUnavailable => 'No Solana address';
}

// Path: chains
class _Translations$chains$en extends Translations$chains$zh {
  _Translations$chains$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get network => 'Network';
  @override
  String get selectorTitle => 'Select Network';
  @override
  String get addNetwork => 'Add Network';
  @override
  String get addCustom => 'Add Custom';
  @override
  String get addCustomEvm => 'Add EVM Network';
  @override
  String get searchNetworkHint => 'Search networks';
  @override
  String get emptySearch => 'No networks to add';
  @override
  String get removeNetwork => 'Remove Network';
  @override
  String get removeNetworkTitle => 'Remove Network';
  @override
  String get removeNetworkMessage =>
      'After removal, this network will no longer be shown and its custom configuration will not be used.';
  @override
  String get confirmRemoveNetwork => 'Remove';
  @override
  String get nameLabel => 'Network Name';
  @override
  String get chainIdLabel => 'Chain ID';
  @override
  String get rpcUrlLabel => 'RPC URL';
  @override
  String get symbolLabel => 'Native Symbol';
  @override
  String get blockExplorerLabel => 'Block Explorer URL';
  @override
  String get testnetLabel => 'Testnet';
  @override
  String get nameRequired => 'Enter the network name';
  @override
  String get chainIdRequired => 'Enter the Chain ID';
  @override
  String get invalidChainId => 'Enter a valid Chain ID';
  @override
  String get rpcUrlRequired => 'Enter the RPC URL';
  @override
  String get invalidRpcUrl => 'Enter a valid RPC URL';
  @override
  String get symbolRequired => 'Enter the native token symbol';
  @override
  String get invalidBlockExplorerUrl => 'Enter a valid block explorer URL';
  @override
  String get duplicateChainId => 'This Chain ID already exists';
  @override
  String get current => 'Current';
  @override
  String get mainnet => 'Mainnet';
  @override
  String get testnet => 'Testnet';
  @override
  String get loading => 'Loading networks';
  @override
  String get loadFailed => 'Failed to load networks';
}

// Path: nodes
class _Translations$nodes$en extends Translations$nodes$zh {
  _Translations$nodes$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get managementTitle => 'RPC Nodes';
  @override
  String get addNode => 'Add Node';
  @override
  String get editNode => 'Edit Node';
  @override
  String get defaultNode => 'Default';
  @override
  String get chainlistNode => 'Chainlist';
  @override
  String get customNode => 'Custom';
  @override
  String get selected => 'Selected';
  @override
  String get select => 'Select';
  @override
  String get test => 'Test';
  @override
  String get delete => 'Delete';
  @override
  String get deleteTitle => 'Delete Node';
  @override
  String get deleteMessage =>
      'This custom RPC node will no longer be available.';
  @override
  String get confirmDelete => 'Delete';
  @override
  String get save => 'Save';
  @override
  String get nameLabel => 'Node Name';
  @override
  String get urlLabel => 'URL';
  @override
  String get providerLabel => 'Provider';
  @override
  String get customProvider => 'Custom';
  @override
  String get apiKeyLabel => 'API Key';
  @override
  String get authModeLabel => 'Authentication';
  @override
  String get authNone => 'No extra parameters';
  @override
  String get authQuery => 'Query parameter';
  @override
  String get authPath => 'Path segment';
  @override
  String get authHeader => 'HTTP header';
  @override
  String get credentialParameterLabel => 'Credential parameter';
  @override
  String get credentialRequired => 'Enter the node credential';
  @override
  String get credentialKeepHint =>
      'Leave blank to keep the existing credential';
  @override
  String get urlKeepHint => 'Leave blank to keep the existing URL';
  @override
  String get providerUnsupported =>
      'This provider does not support the current network';
  @override
  String get noteLabel => 'Note';
  @override
  String get nameRequired => 'Enter a node name';
  @override
  String get urlRequired => 'Enter a URL';
  @override
  String get statusUntested => 'Untested';
  @override
  String get statusTesting => 'Testing';
  @override
  String get statusAvailable => 'Available';
  @override
  String get statusUnavailable => 'Unavailable';
  @override
  String get blockHeightPrefix => 'Block';
  @override
  String get latencyMsSuffix => 'ms';
  @override
  String get trackingNone => 'No tracking';
  @override
  String get trackingYes => 'Tracking';
  @override
  String get trackingUnknown => 'Tracking unknown';
  @override
  String get loadFailed => 'Failed to load nodes';
  @override
  String get empty => 'No nodes';
}

// Path: tokens
class _Translations$tokens$en extends Translations$tokens$zh {
  _Translations$tokens$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get managementTitle => 'Token Management';
  @override
  String get addToken => 'Add Token';
  @override
  String get addCustomToken => 'Add Custom';
  @override
  String get searchTokenHint => 'Search by name, symbol, or contract address';
  @override
  String get emptySearch => 'No matching tokens';
  @override
  String get runDiscovery => 'Discover Tokens';
  @override
  String get discovering => 'Discovering';
  @override
  String discoverySuccess({required Object count}) =>
      'Discovered ${count} tokens';
  @override
  String get discoveryEmpty => 'No held tokens found';
  @override
  String get discoveryFailed => 'Token discovery failed. Check the RPC node.';
  @override
  String get contractAddressLabel => 'Contract Address';
  @override
  String get symbolLabel => 'Token Symbol';
  @override
  String get nameLabel => 'Token Name';
  @override
  String get decimalsLabel => 'Decimals';
  @override
  String get contractAddressRequired => 'Enter the contract address';
  @override
  String get invalidContractAddress => 'Enter a valid contract address';
  @override
  String get metadataRequired => 'Enter the token name and symbol';
  @override
  String get invalidDecimals => 'Enter valid decimals';
  @override
  String get hide => 'Hide';
  @override
  String get unhide => 'Unhide';
  @override
  String get builtIn => 'Built-in';
  @override
  String get userAdded => 'Manual';
  @override
  String get discovered => 'Discovered';
  @override
  String get hidden => 'Hidden';
  @override
  String get empty => 'No tokens';
  @override
  String get loadFailed => 'Failed to load tokens';
}

// Path: assets
class _Translations$assets$en extends Translations$assets$zh {
  _Translations$assets$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get detailTitle => 'Asset Details';
  @override
  String get network => 'Network';
  @override
  String get balance => 'Balance';
  @override
  String get fiatValue => 'Estimated Value';
  @override
  String get contractAddress => 'Contract Address';
  @override
  String get nativeAsset => 'Native asset';
  @override
  String get currentPrice => 'Current Price';
  @override
  String get change24h => '24h Change';
  @override
  String get marketOverview => 'Market Overview';
  @override
  String get volume24h => '24h Volume';
  @override
  String get liquidity => 'Liquidity';
  @override
  String get marketCap => 'Market Cap';
  @override
  String get fdv => 'FDV';
  @override
  String get transactions24h => '24h Buys / Sells';
  @override
  String get primaryPair => 'Primary Pair';
  @override
  String get viewOnDexScreener => 'View on DexScreener';
  @override
  String get marketDataUnavailable => 'Market data unavailable';
  @override
  String get marketDataSource => 'Source: DexScreener';
  @override
  String get updatedAt => 'Updated';
  @override
  String get pairCreatedAt => 'Pool created';
  @override
  String get lowLiquidityWarning =>
      'This pool has low liquidity and its market price may be volatile.';
  @override
  String get priceDivergenceWarning =>
      'The wallet valuation price differs significantly from the DEX market price.';
}

// Path: transactions
class _Translations$transactions$en extends Translations$transactions$zh {
  _Translations$transactions$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get historyTitle => 'Transaction History';
  @override
  String get empty => 'No transactions';
  @override
  String get loadFailed => 'Failed to load transactions';
  @override
  String get submitting => 'Submitting';
  @override
  String get submitted => 'Submitted';
  @override
  String get success => 'Success';
  @override
  String get failed => 'Failed';
  @override
  String get incoming => 'Receive';
  @override
  String get outgoing => 'Send';
  @override
  String get operationWrap => 'Wrap Native Coin';
  @override
  String get operationUnwrap => 'Unwrap Native Coin';
  @override
  String get operationStake => 'Stake TRX';
  @override
  String get operationUnstake => 'Unstake TRX';
  @override
  String get operationWithdrawUnfreeze => 'Withdraw Unstaked TRX';
  @override
  String get operationCancelUnfreeze => 'Cancel All Unstakes';
  @override
  String get operationDelegateResource => 'Delegate TRON Resources';
  @override
  String get operationUndelegateResource => 'Undelegate TRON Resources';
  @override
  String get operationVote => 'Vote for Representatives';
  @override
  String get operationClaimReward => 'Claim Voting Reward';
  @override
  String get viewMoreOnExplorer => 'View More on Explorer';
}

// Path: transfer
class _Translations$transfer$en extends Translations$transfer$zh {
  _Translations$transfer$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get title => 'Send';
  @override
  String get confirmTitle => 'Confirm Transfer';
  @override
  String get resultTitle => 'Transfer Result';
  @override
  String get copyTransactionHash => 'Copy Transaction Hash';
  @override
  String get viewTransactionExplorer => 'View Explorer';
  @override
  String get transactionHashCopied => 'Transaction hash copied';
  @override
  String get selectedAsset => 'Select Asset';
  @override
  String get hideZeroBalances => 'Hide zero-balance assets';
  @override
  String get recipientLabel => 'Recipient Address';
  @override
  String get amountLabel => 'Amount';
  @override
  String get memoLabel => 'Memo / Tag';
  @override
  String get memoOptionalHelper =>
      'Optional. Fill this only if the recipient requires it.';
  @override
  String get memoRequiredLabel => 'Memo / Tag';
  @override
  String get memoRequiredHelper => 'Required for this asset.';
  @override
  String get selectContact => 'Select Contact';
  @override
  String get max => 'Max';
  @override
  String get next => 'Next';
  @override
  String get balance => 'Balance';
  @override
  String get noAssets => 'No transferable assets';
  @override
  String get walletLocked => 'Wallet locked';
  @override
  String get invalidAddress => 'Invalid recipient address';
  @override
  String get invalidAmount => 'Enter an amount greater than 0';
  @override
  String get insufficientBalance => 'Insufficient balance';
  @override
  String get unavailableBalance => 'Asset balance is unavailable';
  @override
  String get memoRequired => 'Enter the required Memo / Tag';
  @override
  String get feeFailed => 'Fee estimation failed. You cannot continue yet.';
  @override
  String get chain => 'Network';
  @override
  String get from => 'From';
  @override
  String get to => 'To';
  @override
  String get token => 'Asset';
  @override
  String get amount => 'Amount';
  @override
  String get fee => 'Fee';
  @override
  String get estimatedFee => 'Estimated fee';
  @override
  String get maximumFee => 'Maximum fee';
  @override
  String get feeSettings => 'Fee settings';
  @override
  String get feeEconomy => 'Economy';
  @override
  String get feeEconomyHint => 'Lower fee, confirmation may take longer';
  @override
  String get feeStandard => 'Standard';
  @override
  String get feeStandardHint => 'Balanced fee and confirmation speed';
  @override
  String get feeFast => 'Fast';
  @override
  String get feeFastHint => 'Higher fee for priority confirmation';
  @override
  String get feeCustom => 'Custom';
  @override
  String get feeCustomHint => 'Set chain fee parameters manually';
  @override
  String get maxFeeGwei => 'Max fee (Gwei)';
  @override
  String get priorityFeeGwei => 'Priority fee (Gwei)';
  @override
  String get gasPriceGwei => 'Gas price (Gwei)';
  @override
  String get priorityFeeSol => 'Total priority fee (SOL)';
  @override
  String get bitcoinFeeRate => 'Fee rate (sat/vB)';
  @override
  String get estimatedConfirmation => 'Estimated confirmation';
  @override
  String get approximately => 'Approx.';
  @override
  String get blocks => 'blocks';
  @override
  String get tronFeeLimit => 'Maximum TRX burn';
  @override
  String get applyFee => 'Apply fee';
  @override
  String get invalidFee => 'Enter a valid fee';
  @override
  String get maxFeeBelowPriority => 'Max fee cannot be lower than priority fee';
  @override
  String get feeLimitBelowEstimate =>
      'Maximum TRX burn cannot be below the estimated fee';
  @override
  String get feeTooLow =>
      'This fee is below the network base fee and may not confirm';
  @override
  String get feeVeryHigh =>
      'This fee is much higher than the network suggestion';
  @override
  String get feeModel => 'Fee Model';
  @override
  String get feeModelEip1559 => 'EIP-1559';
  @override
  String get feeModelLegacy => 'Legacy Gas Price';
  @override
  String get feeModelBitcoin => 'Bitcoin Fee';
  @override
  String get feeModelTron => 'Tron Fee';
  @override
  String get feeModelSolana => 'Solana Fee';
  @override
  String get feeModelSui => 'Sui Gas';
  @override
  String get maxFeePerGas => 'Max Fee Per Gas';
  @override
  String get maxPriorityFeePerGas => 'Priority Fee Per Gas';
  @override
  String get gasPrice => 'Gas Price';
  @override
  String get totalDeduction => 'Total Deduction';
  @override
  String get newRecipientWarning =>
      'This is a new recipient. Verify the full address and destination network.';
  @override
  String lookalikeRecipientWarning({required Object address}) =>
      'This address closely resembles a previous recipient but is different. It may be address poisoning. Similar address: ${address}';
  @override
  String get contractAddress => 'Contract Address';
  @override
  String get riskWarnings => 'Risk Warnings';
  @override
  String get riskLegacy =>
      'This network is using the legacy gas price model. Review the fee before signing.';
  @override
  String get riskErc20 =>
      'This is a contract token transfer. Check the contract and recipient addresses.';
  @override
  String get scanTitle => 'Scan';
  @override
  String get scanInstruction =>
      'Scan a wallet address QR code. The address will be filled into the transfer recipient field.';
  @override
  String get scanInvalid => 'The QR code is not a valid address.';
  @override
  String get scanSuccess => 'Address detected';
  @override
  String get scanCameraPermissionDenied =>
      'Camera permission is required to scan QR codes.';
  @override
  String get scanCameraUnsupported =>
      'Scanning is not supported on this device.';
  @override
  String get scanCameraError => 'Unable to start the camera. Try again later.';
}

// Path: addressBook
class _Translations$addressBook$en extends Translations$addressBook$zh {
  _Translations$addressBook$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get managementTitle => 'Address Book';
  @override
  String get addContact => 'Add Contact';
  @override
  String get editContact => 'Edit Contact';
  @override
  String get delete => 'Delete';
  @override
  String get save => 'Save';
  @override
  String get nameLabel => 'Contact Name';
  @override
  String get addressLabel => 'Wallet Address';
  @override
  String get noteLabel => 'Note';
  @override
  String get chainTypeLabel => 'Chain Type';
  @override
  String get evm => 'EVM';
  @override
  String get bitcoin => 'Bitcoin';
  @override
  String get tron => 'Tron';
  @override
  String get solana => 'Solana';
  @override
  String get sui => 'Sui';
  @override
  String get nameRequired => 'Enter a contact name';
  @override
  String get addressRequired => 'Enter a wallet address';
  @override
  String get invalidAddress => 'Address does not match the selected chain type';
  @override
  String get deleteTitle => 'Delete Contact';
  @override
  String get deleteMessage =>
      'This contact will no longer be available from the address book.';
  @override
  String get confirmDelete => 'Delete';
  @override
  String get empty => 'No contacts';
  @override
  String get loadFailed => 'Failed to load contacts';
  @override
  String get pickTitle => 'Select Contact';
  @override
  String get otherWallets => 'Other Wallets';
  @override
  String get contacts => 'Address Book Contacts';
  @override
  String get noContactsForChain => 'No contacts for the current chain';
}

// Path: wallet
class _Translations$wallet$en extends Translations$wallet$zh {
  _Translations$wallet$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get create => 'Create Wallet';
  @override
  String get import => 'Import Wallet';
  @override
  String get view => 'View';
  @override
  String get mnemonicWallet => 'Mnemonic';
  @override
  String get privateKeyWallet => 'Private Key';
  @override
  String get moreActions => 'More actions';
  @override
  String get copyEvm => 'Copy EVM Address';
  @override
  String get copyBtc => 'Copy BTC Address';
  @override
  String get copySolana => 'Copy Solana Address';
  @override
  String get copySui => 'Copy Sui Address';
  @override
  String get receiveQr => 'Receive QR';
  @override
  String receiveQrTitle({
    required Object walletName,
    required Object chainName,
  }) => '${walletName} - ${chainName}';
  @override
  String get copyAddress => 'Copy Address';
  @override
  String get copy => 'Copy';
  @override
  String get saveQrImage => 'Save';
  @override
  String get amount => 'Amount';
  @override
  String get enterAmountTitle => 'Enter Amount';
  @override
  String get amountConfirm => 'OK';
  @override
  String get amountApproxPrefix => '≈';
  @override
  String get usdCode => 'USD';
  @override
  String get noAddressForChain =>
      'This wallet does not have an address for the current chain';
  @override
  String get qrImageSaved => 'QR image saved to gallery';
  @override
  String get qrImagePhotoPermissionRequired =>
      'Photo access is required to save the QR image';
  @override
  String get qrImageSaveFailed => 'Failed to save QR image. Please try again.';
  @override
  String get rename => 'Rename';
  @override
  String get changePassword => 'Change Password';
  @override
  String get currentPasswordLabel => 'Current Wallet Password';
  @override
  String get newPasswordLabel => 'New Wallet Password';
  @override
  String get confirmNewPasswordLabel => 'Confirm New Password';
  @override
  String get newPasswordRequired => 'Enter a new wallet password';
  @override
  String get passwordChanged => 'Password changed';
  @override
  String get nameLabel => 'Wallet Name';
  @override
  String get switchWallet => 'Switch Wallet';
  @override
  String get selected => 'Current';
  @override
  String get delete => 'Delete';
  @override
  String get deleteTitle => 'Delete Wallet';
  @override
  String get deleteMessage =>
      'Confirm your password before deleting. You must re-import the mnemonic or private key to recover this wallet.';
  @override
  String get deleteAcknowledge =>
      'I confirm I have backed up this wallet\'s mnemonic or private key';
  @override
  String get deleteRequiresConfirmation =>
      'Confirm that the wallet is backed up first';
  @override
  String get exportSecret => 'Export';
  @override
  String get exportMnemonic => 'Export Mnemonic';
  @override
  String get exportPrivateKey => 'Export Private Key';
  @override
  String get exportBtcPrivateKey => 'Export BTC Private Key';
  @override
  String get exportSecretWarning =>
      'High-risk operation. Make sure your surroundings are private. Do not screenshot or send the exported content to anyone.';
  @override
  String get exportPasswordTitle => 'Verify Wallet Password';
  @override
  String get exportPasswordBody =>
      'Enter the wallet password to view the exported content.';
  @override
  String get mnemonicRiskWarning =>
      'A mnemonic can restore the wallet and control all of its assets. Do not take screenshots, upload it to the cloud, or send it to anyone. Clear the clipboard after copying.';
  @override
  String get privateKeyRiskWarning =>
      'A private key directly controls assets on its network. Do not take screenshots, paste it into untrusted apps, or send it to anyone. Clear the clipboard after copying.';
  @override
  String get mnemonicCopied => 'Mnemonic copied';
  @override
  String get privateKeyCopied => 'Private key copied';
  @override
  String get addressCopied => 'Address copied';
  @override
  String get evmAddress => 'EVM Address';
  @override
  String get btcAddress => 'BTC Address';
  @override
  String get tronAddress => 'Tron Address';
  @override
  String get solanaAddress => 'Solana Address';
  @override
  String get suiAddress => 'Sui Address';
  @override
  String get unlockTitle => 'Unlock Wallet';
  @override
  String get unlockBody =>
      'Enter the local wallet password to restore the current session.';
  @override
  String get unlockButton => 'Unlock';
  @override
  String get unlocking => 'Unlocking';
  @override
  String get signingPasswordTitle => 'Verify Signing Identity';
  @override
  String get signingPasswordBody =>
      'Verify your identity to continue this signing request.';
  @override
  String get rememberSigningPassword => 'Remember password for 15 minutes';
  @override
  String get biometricSetupTitle => 'Set Up Biometric Password';
  @override
  String get biometricSetupBody =>
      'Use fingerprint or face authentication first when the wallet password is needed.';
  @override
  String get biometricSetupConfirm => 'Set Up';
  @override
  String get biometricReason => 'Authenticate to use the wallet password';
  @override
  String get biometricUseButton => 'Use Biometrics';
  @override
  String get biometricEnabled => 'Biometric password enabled';
}

// Path: settings
class _Translations$settings$en extends Translations$settings$zh {
  _Translations$settings$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get walletManagement => 'Wallet Management';
  @override
  String get networkManagement => 'Network Management';
  @override
  String get addressBook => 'Address Book';
  @override
  String get advanced => 'Advanced';
  @override
  String get preferences => 'Preferences';
  @override
  String get language => 'Language';
  @override
  String get fiatCurrency => 'Currency';
  @override
  String get fiatCurrencyUsd => 'US Dollar (USD)';
  @override
  String get fiatCurrencyCny => 'Chinese Yuan (CNY)';
  @override
  String get fiatCurrencyEur => 'Euro (EUR)';
  @override
  String get fiatCurrencyJpy => 'Japanese Yen (JPY)';
  @override
  String get themeMode => 'Theme Mode';
  @override
  String get themeModeSystem => 'Follow System';
  @override
  String get themeModeLight => 'Light Mode';
  @override
  String get themeModeDark => 'Dark Mode';
  @override
  String get themeColor => 'Theme Color';
  @override
  String get themeColorIndigo => 'Indigo';
  @override
  String get themeColorBlue => 'Blue';
  @override
  String get themeColorPurple => 'Purple';
  @override
  String get themeColorGreen => 'Green';
  @override
  String get themeColorOrange => 'Orange';
  @override
  String get themeColorRose => 'Rose';
  @override
  String get themeColorNavy => 'Navy';
  @override
  String get security => 'Security';
  @override
  String get about => 'About';
  @override
  String get languageSystem => 'Follow System';
  @override
  String get languageZh => 'Simplified Chinese';
  @override
  String get languageEn => 'English';
  @override
  String get requirePasswordOnLaunch => 'Require Password on Launch';
  @override
  String get requirePasswordOnLaunchSubtitle =>
      'Ask for the wallet password every time the app starts';
  @override
  String get backgroundPrivacyShield => 'Background Privacy Shield';
  @override
  String get backgroundPrivacyShieldSubtitle =>
      'Blur app content when it enters the background';
  @override
  String get autoLock => 'Auto-Lock';
  @override
  String get autoLockSubtitle => 'Lock the wallet after leaving the app';
  @override
  String get autoLockImmediately => 'Immediately';
  @override
  String get autoLockOneMinute => '1 minute';
  @override
  String get autoLockFiveMinutes => '5 minutes';
  @override
  String get autoLockFifteenMinutes => '15 minutes';
  @override
  String get autoLockOneHour => '1 hour';
  @override
  String get biometricPassword => 'Biometric Password';
  @override
  String get biometricPasswordSubtitle =>
      'Use biometrics when the wallet password is needed';
  @override
  String get biometricPasswordUnavailable =>
      'Biometric authentication is unavailable on this device';
  @override
  String get biometricPasswordSetupPrompt =>
      'Enter the current wallet password to enable biometric password use.';
  @override
  String get changePasswordSubtitle => 'Update the global wallet password';
  @override
  String get securityLog => 'Security Log';
  @override
  String get securityLogSubtitle =>
      'Automatically record and review sensitive security actions on this device';
  @override
  String get securityLogPasswordTitle => 'Verify Wallet Password';
  @override
  String get securityLogPasswordBody =>
      'Verify the wallet password before viewing the security log.';
  @override
  String get securityLogEmpty => 'No security log entries';
  @override
  String get securityLogSafetyNotice =>
      'The security log stores only the action type, wallet name, chain, public address, asset, amount, and time on this device. It never stores private keys, mnemonics, passwords, or signature contents.';
  @override
  String get securityLogWalletLabel => 'Wallet: ';
  @override
  String get securityLogChainLabel => 'Chain: ';
  @override
  String get securityLogAmountLabel => 'Amount: ';
  @override
  String get securityLogAddressLabel => 'Public address: ';
  @override
  String get securityLogViewMnemonic => 'Viewed Mnemonic';
  @override
  String get securityLogViewPrivateKey => 'Viewed Private Key';
  @override
  String get securityLogCopyMnemonic => 'Copied Mnemonic';
  @override
  String get securityLogCopyPrivateKey => 'Copied Private Key';
  @override
  String get securityLogCreateWallet => 'Created Wallet';
  @override
  String get securityLogImportWallet => 'Imported Wallet';
  @override
  String get securityLogDeleteWallet => 'Deleted Wallet';
  @override
  String get securityLogChangePassword => 'Changed Password';
  @override
  String get securityLogSignMessage => 'Signed Message';
  @override
  String get securityLogSignTransaction => 'Signed Transaction';
  @override
  String get securityLogWrapNative => 'Wrapped Native Token';
  @override
  String get securityLogUnwrapNative => 'Unwrapped Native Token';
  @override
  String get securityLogSolanaRentRecovery => 'Solana Rent Recovery';
  @override
  String get securityLogTronStake => 'TRX Stake';
  @override
  String get securityLogTronUnstake => 'TRX Unstake';
  @override
  String get securityLogTronWithdrawUnfreeze => 'Withdraw Unstaked TRX';
  @override
  String get securityLogTronCancelUnfreeze => 'Cancel TRX Unstake';
  @override
  String get securityLogTronDelegateResource => 'Delegate TRON Resources';
  @override
  String get securityLogTronUndelegateResource => 'Undelegate TRON Resources';
  @override
  String get securityLogTronVote => 'TRON Super Representative Vote';
  @override
  String get securityLogTronClaimReward => 'Claim TRON Voting Reward';
  @override
  String get clearDappPermissions => 'Clear dApp Permissions';
  @override
  String get clearDappPermissionsSubtitle =>
      'Remove site connection permissions';
  @override
  String get connectedDapps => 'Authorized dApps';
  @override
  String get noConnectedDapps => 'No authorized dApps';
  @override
  String get revoke => 'Revoke';
  @override
  String get revokeDappPermission => 'Revoke dApp Permission';
  @override
  String get revokeDappPermissionSubtitle =>
      'After revoking, this site must request approval again before reading the account address.';
  @override
  String get evmNetworks => 'EVM Networks';
  @override
  String get bitcoinNetworks => 'Bitcoin Networks';
  @override
  String get solanaNetworks => 'Solana Networks';
  @override
  String get tronNetworks => 'Tron Networks';
  @override
  String get suiNetworks => 'Sui Networks';
  @override
  String get currentRpcUnknown => 'Loading current RPC';
}

// Path: tronStaking
class _Translations$tronStaking$en extends Translations$tronStaking$zh {
  _Translations$tronStaking$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get title => 'TRX Staking';
  @override
  String get advancedSubtitle =>
      'Manage Stake 2.0, resource delegation, votes, and rewards';
  @override
  String get wallet => 'Wallet';
  @override
  String get network => 'Network';
  @override
  String get refresh => 'Refresh staking state';
  @override
  String get noWallet => 'No wallet with a TRON address';
  @override
  String get noNetwork => 'No TRON network is available';
  @override
  String get loadFailed =>
      'Could not load staking data. Check the TRON node and retry.';
  @override
  String get availableBalance => 'Available balance';
  @override
  String get bandwidthStaked => 'Bandwidth staked';
  @override
  String get energyStaked => 'Energy staked';
  @override
  String get tronPower => 'TRON Power';
  @override
  String get availableVotes => 'Available votes';
  @override
  String get resourceOverview => 'Resources';
  @override
  String get bandwidth => 'Bandwidth';
  @override
  String get energy => 'Energy';
  @override
  String availableResource({
    required Object available,
    required Object limit,
    required Object used,
  }) => '${available} available / ${limit} · ${used} used';
  @override
  String get stake => 'Stake';
  @override
  String get unstake => 'Unstake';
  @override
  String get delegate => 'Delegate resources';
  @override
  String get vote => 'Vote for representatives';
  @override
  String get stakeTitle => 'Stake TRX';
  @override
  String get unstakeTitle => 'Unstake TRX';
  @override
  String get delegateTitle => 'Delegate resources';
  @override
  String get undelegateTitle => 'Undelegate resources';
  @override
  String get resourceType => 'Resource type';
  @override
  String get amount => 'Amount';
  @override
  String get amountHint => 'Enter a TRX amount';
  @override
  String get maximum => 'Max';
  @override
  String get continueAction => 'Continue';
  @override
  String get invalidAmount =>
      'Enter a valid TRX amount with no more than 6 decimals';
  @override
  String get insufficientBalance => 'Available TRX balance is insufficient';
  @override
  String get insufficientStaked =>
      'The selected resource has insufficient stake';
  @override
  String get noUnfreezeSlots => 'No unstake slots are currently available';
  @override
  String get confirmStake => 'Confirm stake';
  @override
  String get confirmUnstake => 'Confirm unstake';
  @override
  String get confirmDelegate => 'Confirm resource delegation';
  @override
  String get confirmUndelegate => 'Confirm resource undelegation';
  @override
  String get confirmWithdraw => 'Confirm unstaked TRX withdrawal';
  @override
  String get confirmCancel => 'Confirm cancel all unstakes';
  @override
  String get confirmVote => 'Confirm vote allocation';
  @override
  String get confirmClaimReward => 'Confirm reward claim';
  @override
  String get confirmAndSign => 'Confirm and sign';
  @override
  String get owner => 'Wallet address';
  @override
  String get receiver => 'Receiver address';
  @override
  String get receiverHint => 'Enter a TRON address';
  @override
  String get invalidReceiver =>
      'Enter a valid TRON address different from this wallet';
  @override
  String get lockResource => 'Lock delegation';
  @override
  String get lockUnsupported =>
      'Locked delegation is not supported on this network';
  @override
  String get locked => 'Locked';
  @override
  String get unlocked => 'Unlocked';
  @override
  String get lockPeriod => 'Lock period (blocks)';
  @override
  String lockPeriodHint({required Object max}) => 'Enter up to ${max} blocks';
  @override
  String lockPeriodValue({required Object count}) => '${count} blocks';
  @override
  String get estimatedFee => 'Estimated network fee';
  @override
  String get remainingBalance => 'Available balance after staking';
  @override
  String get feeCalculatedByNetwork =>
      'Calculated dynamically from Bandwidth usage';
  @override
  String get feeEstimateFailed =>
      'Network fee estimation failed. You cannot continue yet.';
  @override
  String unstakeDelay({required Object days}) =>
      'Unstaking takes ${days} days and must be withdrawn after expiry';
  @override
  String unstakeAvailableAt({required Object date}) =>
      'Estimated withdrawal date: ${date}';
  @override
  String unfreezeSlotsRemaining({required Object count}) =>
      '${count} unstake slots remaining';
  @override
  String get pendingUnfreeze => 'Pending unstake';
  @override
  String pendingTotal({required Object amount}) =>
      'Pending total: ${amount} TRX';
  @override
  String withdrawableAmount({required Object amount}) =>
      'Currently withdrawable: ${amount} TRX';
  @override
  String nextUnfreezeAt({required Object date}) => 'Next expiry: ${date}';
  @override
  String get pendingEmpty => 'There is no pending unstake';
  @override
  String expiresAt({required Object date}) => 'Expires ${date}';
  @override
  String get withdrawable => 'Withdrawable';
  @override
  String withdraw({required Object amount}) => 'Withdraw ${amount} TRX';
  @override
  String get cancelAll => 'Cancel all unstakes';
  @override
  String get cancelAllWarning =>
      'This cancels every unexpired unstake. The protocol does not support cancelling only one entry.';
  @override
  String get delegations => 'Resource delegations';
  @override
  String get delegationsEmpty => 'There are no resource delegations';
  @override
  String get delegatedTo => 'Delegated to';
  @override
  String get receivedFrom => 'Received from';
  @override
  String get undelegate => 'Undelegate';
  @override
  String get witnesses => 'Super Representatives';
  @override
  String get witnessSearch => 'Search address or URL';
  @override
  String witnessVotes({required Object count}) => '${count} votes';
  @override
  String get myVotes => 'My votes';
  @override
  String voteSummary({required Object used, required Object total}) =>
      '${used} / ${total} votes allocated';
  @override
  String get clearVotes => 'Clear votes';
  @override
  String get reward => 'Claimable reward';
  @override
  String get claimReward => 'Claim reward';
  @override
  String get noReward => 'There is no reward to claim';
  @override
  String get submitting => 'Submitting TRON transaction…';
  @override
  String get submitted => 'TRON transaction submitted';
  @override
  String get walletLocked => 'Unlock the wallet to sign';
  @override
  String get signingKeyUnavailable =>
      'This wallet has no available TRON private key';
  @override
  String get nothingToWithdraw =>
      'There is no expired TRX available to withdraw';
  @override
  String get cancelUnsupported =>
      'This network does not support cancelling all unstakes';
  @override
  String get nothingToCancel => 'There is no pending unstake to cancel';
  @override
  String get delegationUnsupported =>
      'Resource delegation is not enabled on this network';
  @override
  String get invalidDelegation =>
      'The delegation address or lock settings are invalid';
  @override
  String get insufficientDelegatableBalance =>
      'There is no staked resource available to delegate';
  @override
  String get delegationLocked =>
      'This delegation is locked and cannot be removed before expiry';
  @override
  String get insufficientDelegatedBalance =>
      'The undelegatable resource balance is insufficient';
  @override
  String get excessiveVotes =>
      'The vote allocation exceeds available TRON Power';
  @override
  String get nothingToClaim => 'There is no reward to claim';
  @override
  String get transactionValidationFailed =>
      'The transaction returned by the node failed local security validation';
  @override
  String get broadcastFailed =>
      'Could not submit the TRON transaction. Refresh the on-chain state and retry.';
  @override
  String get operationUnavailable =>
      'The current on-chain state does not allow this operation';
}

// Path: advanced
class _Translations$advanced$en extends Translations$advanced$zh {
  _Translations$advanced$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get title => 'Advanced';
  @override
  String get contractCall => 'Contract Call';
  @override
  String get contractCallSubtitle =>
      'Read contracts or sign and submit write calls';
  @override
  String get wrappedNative => 'Wrap Native Token';
  @override
  String get wrappedNativeSubtitle =>
      'Convert 1:1 between the native token and its wrapped token';
  @override
  String get wrappedNativeWallet => 'Wallet';
  @override
  String get wrappedNativeNetwork => 'Network';
  @override
  String get wrappedNativeWrap => 'Wrap';
  @override
  String get wrappedNativeUnwrap => 'Unwrap';
  @override
  String get wrappedNativeBalance => 'Native Balance';
  @override
  String get wrappedNativeTokenBalance => 'Wrapped Token Balance';
  @override
  String get wrappedNativeAmount => 'Amount';
  @override
  String get wrappedNativeAmountHint => 'Enter amount to convert';
  @override
  String get wrappedNativeMax => 'Max';
  @override
  String get wrappedNativeReview => 'Review Transaction';
  @override
  String get wrappedNativePreparing => 'Simulating and estimating fees…';
  @override
  String get wrappedNativeRefresh => 'Refresh Balances';
  @override
  String get wrappedNativeRisk =>
      'The conversion uses this network\'s standard wrapped-token contract at a 1:1 rate. Verify the network, amount, fee, and destination token before signing.';
  @override
  String get wrappedNativeConfirmTitle => 'Confirm Native Token Conversion';
  @override
  String get wrappedNativeFrom => 'Pay';
  @override
  String get wrappedNativeTo => 'Receive';
  @override
  String get wrappedNativeNetworkFee => 'Maximum Network Fee';
  @override
  String get wrappedNativeRent => 'Account Rent';
  @override
  String get wrappedNativeConfirmWrap => 'Confirm Wrap';
  @override
  String get wrappedNativeConfirmUnwrap => 'Confirm Unwrap';
  @override
  String get wrappedNativeSubmitting => 'Signing and submitting…';
  @override
  String get wrappedNativeSuccessWrap => 'Wrap transaction submitted';
  @override
  String get wrappedNativeSuccessUnwrap => 'Unwrap transaction submitted';
  @override
  String get wrappedNativeTransactionHash => 'Transaction Hash';
  @override
  String get wrappedNativeViewExplorer => 'View in Explorer';
  @override
  String get wrappedNativeNoWallet =>
      'No wallet is available for the selected network';
  @override
  String get wrappedNativeNoNetwork =>
      'No network supports native token wrapping';
  @override
  String get wrappedNativeInvalidAmount =>
      'Enter a valid amount greater than zero';
  @override
  String get wrappedNativeInsufficientNative =>
      'Insufficient native balance after reserving network fees and possible account rent';
  @override
  String get wrappedNativeInsufficientWrapped =>
      'Insufficient wrapped-token balance';
  @override
  String get wrappedNativeBalanceFailed =>
      'Unable to load balances. Check the RPC node and try again';
  @override
  String get wrappedNativePreparationFailed =>
      'Transaction simulation or fee estimation failed. Check the balance and RPC node';
  @override
  String get wrappedNativeWalletLocked => 'Unlock the wallet before signing';
  @override
  String get wrappedNativeSigningKeyUnavailable =>
      'The selected wallet has no signing key for this network';
  @override
  String get wrappedNativeSubmissionFailed =>
      'Transaction submission failed. Refresh balances and verify the on-chain result';
  @override
  String get solanaRentRecovery => 'Solana Rent Recovery';
  @override
  String get solanaRentRecoverySubtitle =>
      'Close safe empty token accounts and reclaim their rent';
  @override
  String get solanaRentWallet => 'Wallet';
  @override
  String get solanaRentNetwork => 'Solana Network';
  @override
  String get solanaRentRefresh => 'Refresh Recoverable Rent';
  @override
  String get solanaRentRecoverableAccounts => 'Recoverable Accounts';
  @override
  String get solanaRentSelectedSummary => 'Selected Accounts';
  @override
  String get solanaRentTotalRecoverable => 'Total Recoverable';
  @override
  String get solanaRentNetRecoverable => 'Estimated Net Amount';
  @override
  String get solanaRentNoAccounts =>
      'There are no empty token accounts that can be safely closed';
  @override
  String get solanaRentStartRecovery => 'Start Recovery';
  @override
  String get solanaRentRisk =>
      'Recovery closes the selected zero-balance token accounts and returns their rent to this wallet. A token account may be created again and charge rent if you hold that token later.';
  @override
  String get solanaRentConfirmTitle => 'Confirm Rent Recovery';
  @override
  String get solanaRentSelectedAccounts => 'Accounts';
  @override
  String get solanaRentReceivingWallet => 'Receiving Wallet';
  @override
  String get solanaRentConfirmAndSign => 'Confirm and Sign';
  @override
  String get solanaRentScanning => 'Scanning recoverable accounts…';
  @override
  String get solanaRentSubmitting =>
      'Submitting recovery transactions in batches…';
  @override
  String get solanaRentRecovering => 'Recovering…';
  @override
  String get solanaRentSuccess => 'Rent Recovery Successful';
  @override
  String get solanaRentPartialSuccess => 'Rent Partially Recovered';
  @override
  String get solanaRentFailed => 'Rent Recovery Failed';
  @override
  String get solanaRentRecoveredAccounts => 'Completed Accounts';
  @override
  String get solanaRentRecoveredAmount => 'Recovered Amount';
  @override
  String get solanaRentSignatures => 'Transaction Signatures';
  @override
  String get solanaRentCopySignature => 'Copy Signature';
  @override
  String get solanaRentSignatureCopied => 'Transaction signature copied';
  @override
  String get solanaRentOpenSolscan => 'View on Solscan';
  @override
  String get solanaRentSplToken => 'SPL Token';
  @override
  String get solanaRentToken2022 => 'Token-2022';
  @override
  String get solanaRentNoWallet =>
      'No wallet with a Solana address is available';
  @override
  String get solanaRentNoNetwork => 'No Solana network is available';
  @override
  String get solanaRentScanFailed =>
      'Unable to scan recoverable accounts. Check the RPC node and try again';
  @override
  String get solanaRentSimulationFailed =>
      'Transaction simulation failed. The selected accounts may have changed';
  @override
  String get solanaRentInsufficientFee =>
      'The wallet does not have enough SOL to pay the estimated network fee';
  @override
  String get solanaRentSelectAccount =>
      'Select at least one token account to recover';
  @override
  String get solanaRentWalletLocked => 'Unlock the wallet before signing';
  @override
  String get solanaRentSigningKeyUnavailable =>
      'The selected wallet has no Solana signing key';
  @override
  String get solanaRentAccountsChanged =>
      'Recoverable accounts changed. Refresh and try again';
  @override
  String get solanaRentRecoveryFailed =>
      'Some or all recovery transactions failed. Refresh to verify the on-chain result';
  @override
  String get walletConnect => 'WalletConnect';
  @override
  String get walletConnectSubtitle =>
      'Connect external dApps and manage active sessions';
  @override
  String get walletConnectScan => 'Scan QR Code';
  @override
  String get walletConnectPaste => 'Paste Connection URI';
  @override
  String get walletConnectUriHint => 'wc: URI';
  @override
  String get walletConnectConnect => 'Connect';
  @override
  String get walletConnectActiveSessions => 'Active Sessions';
  @override
  String get walletConnectNoSessions => 'No active WalletConnect sessions';
  @override
  String get walletConnectMissingConfig =>
      'REOWN_PROJECT_ID was not provided at build time. You can set your WalletConnect Dashboard Project ID in the app.';
  @override
  String get walletConnectProjectId => 'Project ID';
  @override
  String get walletConnectProjectIdDescription =>
      'A Project ID is a public project identifier, not a wallet private key.';
  @override
  String get walletConnectProjectIdSourceCustom => 'Set in App';
  @override
  String get walletConnectProjectIdSourceBuild => 'Build Configuration';
  @override
  String get walletConnectProjectIdSourceMissing => 'Not Configured';
  @override
  String get walletConnectProjectIdSet => 'Set';
  @override
  String get walletConnectProjectIdReplace => 'Replace';
  @override
  String get walletConnectProjectIdDelete => 'Delete';
  @override
  String get walletConnectProjectIdInputTitle => 'Set Project ID';
  @override
  String get walletConnectProjectIdInputHint =>
      '32-character hexadecimal Project ID';
  @override
  String get walletConnectProjectIdInvalid =>
      'Enter a 32-character hexadecimal Project ID.';
  @override
  String get walletConnectProjectIdSaved => 'Project ID saved and applied.';
  @override
  String get walletConnectProjectIdDeleted =>
      'Custom Project ID deleted. The build configuration is now active.';
  @override
  String get walletConnectProjectIdDeletedWithoutBuild =>
      'Custom Project ID deleted. WalletConnect is now disabled.';
  @override
  String get walletConnectProjectIdApplyFailed =>
      'Project ID was saved, but WalletConnect could not be initialized. Check the value and try again.';
  @override
  String get walletConnectProjectIdDeleteTitle => 'Delete Custom Project ID';
  @override
  String get walletConnectProjectIdDeleteWithBuild =>
      'After deletion, WalletConnect will fall back to the Project ID provided at build time.';
  @override
  String get walletConnectProjectIdDeleteWithoutBuild =>
      'No build-time Project ID is available. WalletConnect will be unavailable after deletion.';
  @override
  String get walletConnectProjectIdDisconnectTitle =>
      'Disconnect Active Sessions';
  @override
  String get walletConnectProjectIdDisconnectBody =>
      'Changing the Project ID requires disconnecting all active WalletConnect sessions first.';
  @override
  String get walletConnectProjectIdDisconnectFailed =>
      'Unable to disconnect all sessions. The Project ID was not changed.';
  @override
  String get walletConnectInitializeFailed =>
      'Unable to initialize WalletConnect.';
  @override
  String get walletConnectInvalidUri => 'Invalid WalletConnect URI';
  @override
  String get walletConnectDuplicateUri =>
      'This WalletConnect URI was already handled';
  @override
  String get walletConnectPairFailed =>
      'Unable to start the WalletConnect pairing';
  @override
  String get walletConnectPairStarted => 'Pairing request received';
  @override
  String get walletConnectDisconnect => 'Disconnect';
  @override
  String get walletConnectDisconnectTitle => 'Disconnect Session';
  @override
  String get walletConnectDisconnectBody =>
      'This dApp will no longer be able to request signatures from this wallet.';
  @override
  String get walletConnectDisconnectAll => 'Disconnect All';
  @override
  String get walletConnectDisconnectAllTitle => 'Disconnect All Sessions';
  @override
  String get walletConnectDisconnectAllBody =>
      'Disconnect every active WalletConnect session?';
  @override
  String walletConnectExpires({required Object date}) => 'Expires: ${date}';
  @override
  String get walletConnectAccounts => 'Accounts';
  @override
  String get walletConnectNetworks => 'Networks';
  @override
  String get walletConnectMethods => 'Permissions';
  @override
  String get walletConnectProposalTitle => 'Connection Request';
  @override
  String get walletConnectProposalAccounts => 'Wallet accounts';
  @override
  String get walletConnectProposalNetworks => 'Requested networks';
  @override
  String get walletConnectProposalMethods => 'Requested permissions';
  @override
  String get walletConnectProposalEvents => 'Requested events';
  @override
  String get walletConnectVerifyValid =>
      'Domain verified by WalletConnect Verify.';
  @override
  String get walletConnectVerifyInvalid =>
      'Domain mismatch: the verified request origin does not match the sender.';
  @override
  String get walletConnectVerifyScam =>
      'Security risk: this domain is flagged as malicious.';
  @override
  String get walletConnectVerifyUnknown =>
      'The request origin could not be verified. Check it carefully before connecting.';
  @override
  String get walletConnectUnsupportedProposal =>
      'This request includes unsupported required networks or permissions.';
  @override
  String get walletConnectApprove => 'Connect';
  @override
  String get walletConnectReject => 'Reject';
  @override
  String get walletConnectCameraTitle => 'Scan WalletConnect QR';
  @override
  String get walletRequired =>
      'The current wallet has no available EVM address.';
  @override
  String get contractAddress => 'Contract Address';
  @override
  String get callMode => 'Call Mode';
  @override
  String get modeStandard => 'Standard ABI';
  @override
  String get modeCustomAbi => 'Paste ABI';
  @override
  String get modeManual => 'Manual Function';
  @override
  String get modeRaw => 'Raw Calldata';
  @override
  String get standardTemplate => 'Standard Contract Template';
  @override
  String get erc20 => 'ERC-20';
  @override
  String get erc721 => 'ERC-721';
  @override
  String get erc1155 => 'ERC-1155';
  @override
  String get abiJson => 'ABI JSON';
  @override
  String get parseAbi => 'Parse ABI';
  @override
  String get manualSignature => 'Function signature, e.g. balanceOf(address)';
  @override
  String get outputTypes => 'Return types separated by commas';
  @override
  String get readFunction => 'Read-only function';
  @override
  String get payableFunction => 'Allow native value';
  @override
  String get buildFunction => 'Build Function';
  @override
  String get function => 'Function';
  @override
  String get readBadge => 'Read';
  @override
  String get writeBadge => 'Write';
  @override
  String argument({
    required Object index,
    required Object name,
    required Object type,
  }) => 'Argument ${index}: ${name} (${type})';
  @override
  String get arrayArgumentHint => 'Enter arrays and tuples as JSON';
  @override
  String get rawCalldata => 'Calldata (0x-prefixed)';
  @override
  String get rawWrite => 'Submit raw calldata as a write transaction';
  @override
  String get nativeValue => 'Native Value';
  @override
  String get executeRead => 'Read Contract';
  @override
  String get prepareWrite => 'Check and Prepare Write';
  @override
  String get result => 'Call Result';
  @override
  String get copyResult => 'Copy Call Result';
  @override
  String get resultCopied => 'Call result copied';
  @override
  String get rawResult => 'Raw Result';
  @override
  String get transactionHash => 'Transaction Hash';
  @override
  String get writeRisk =>
      'Contract writes can transfer assets or authorize third parties. Verify the contract, method, arguments, and calldata before signing.';
  @override
  String get confirmWriteTitle => 'Confirm Contract Write';
  @override
  String get chain => 'Network';
  @override
  String get method => 'Method';
  @override
  String get value => 'Native Value';
  @override
  String get gasLimit => 'Gas Limit';
  @override
  String get gasPrice => 'Gas Price';
  @override
  String get estimatedFee => 'Estimated Fee';
  @override
  String get confirmAndSign => 'Confirm and Sign';
  @override
  String get invalidAbi => 'Invalid ABI JSON';
  @override
  String get invalidInput =>
      'Check the contract address, arguments, and calldata';
  @override
  String get notContract => 'No contract code was found at this address';
  @override
  String get callFailed => 'Contract call failed';
  @override
  String get walletLocked => 'Unlock the wallet before signing';
  @override
  String get submitted => 'Contract transaction submitted';
}

// Path: about
class _Translations$about$en extends Translations$about$zh {
  _Translations$about$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get title => 'About';
  @override
  String get tagline => 'A self-custody multichain wallet';
  @override
  String version({required Object version, required Object buildNumber}) =>
      'Version ${version} (Build ${buildNumber})';
  @override
  String get versionAndUpdates => 'Version & Updates';
  @override
  String get checkUpdate => 'Check for Updates';
  @override
  String get checkingUpdate => 'Checking…';
  @override
  String get releaseNotes => 'Release Notes';
  @override
  String get github => 'GitHub';
  @override
  String get transparencyAndSecurity => 'Transparency & Security';
  @override
  String get dataAndNetwork => 'Data & Network Information';
  @override
  String get openSourceLicenses => 'Open Source Licenses';
  @override
  String get helpAndLegal => 'Help & Legal';
  @override
  String get feedback => 'Report an Issue';
  @override
  String get privacyPolicy => 'Privacy Policy';
  @override
  String get termsOfUse => 'Terms of Use';
  @override
  String get openLinkFailed => 'Unable to open the link. Please try again.';
  @override
  String get checkUpdateFailed =>
      'Unable to check for updates. Please try again.';
  @override
  String updateAvailableTitle({required Object version}) =>
      'Version ${version} is available';
  @override
  String get latestVersionTitle => 'You\'re Up to Date';
  @override
  String get latestVersionBody =>
      'The installed version is already the latest version.';
  @override
  String get noReleaseTitle => 'No Update Available';
  @override
  String get noReleaseBody =>
      'There is no public stable release available on GitHub yet.';
  @override
  String currentVersion({required Object version}) =>
      'Current version: ${version}';
  @override
  String publishedAt({required Object date}) => 'Published: ${date}';
  @override
  String get releaseNotesEmpty =>
      'No release notes were provided for this version.';
  @override
  String get goToUpdate => 'View Update';
  @override
  String get close => 'Close';
  @override
  String get dataLocalTitle => 'Local Keys and Data';
  @override
  String get dataLocalBody =>
      'Mnemonics and private keys are encrypted and stored on this device. Safe Wallet cannot recover your mnemonic, private key, or wallet password.';
  @override
  String get backendTitle => 'No Proprietary Backend Required';
  @override
  String get backendBody =>
      'Safe Wallet does not depend on a proprietary account system or private backend. Assets, transactions, and on-chain operations are requested directly through your selected RPC nodes.';
  @override
  String get servicesTitle => 'External Network Services';
  @override
  String get servicesBody =>
      'Depending on the feature, the app may access RPC nodes, Chainlist, CoinGecko, DefiLlama, Jupiter, DexScreener, Frankfurter, and GitHub. Third-party dApps and services are governed by their own privacy policies.';
  @override
  String get analyticsTitle => 'No Ads or Behavioral Tracking';
  @override
  String get analyticsBody =>
      'This version does not include advertising, behavioral analytics, or crash-reporting SDKs. dApps, RPC nodes, and third-party data services may independently log network requests.';
  @override
  String get privacyLocalBody =>
      'Wallet keys, wallet accounts, and address book data are stored on this device. Sensitive key material is encrypted.';
  @override
  String get privacyNetworkBody =>
      'The app sends necessary requests to selected RPC nodes and public data services to retrieve balances, prices, transaction status, network configuration, and update information.';
  @override
  String get privacyNoAnalyticsBody =>
      'This version does not include advertising or behavioral analytics SDKs and does not upload mnemonics, private keys, or wallet passwords to a Safe Wallet server.';
  @override
  String get privacyThirdPartyBody =>
      'When using dApps, RPC nodes, or third-party data services, those providers may process IP addresses, wallet addresses, and request content under their own privacy policies.';
  @override
  String get privacyChangeBody =>
      'This notice will be updated if data handling changes in a future release.';
  @override
  String get termsSelfCustodyBody =>
      'Safe Wallet is a self-custody wallet. You are responsible for protecting your mnemonic, private keys, and wallet password. The developer cannot recover them.';
  @override
  String get termsTransactionBody =>
      'Blockchain transactions are generally irreversible. Verify the address, network, amount, and fee before submitting.';
  @override
  String get termsRiskBody =>
      'Digital assets and on-chain applications involve risk. Information in the app is not investment, legal, or tax advice.';
  @override
  String get termsThirdPartyBody =>
      'RPC nodes, dApps, tokens, and third-party services are operated by their respective providers. Safe Wallet does not control their availability or content.';
  @override
  String get termsWarrantyBody =>
      'The software is provided as-is. To the extent permitted by applicable law, you assume the risks of using it.';
}

// Path: errors
class _Translations$errors$en extends Translations$errors$zh {
  _Translations$errors$en._(TranslationsEn root)
    : this._root = root,
      super.internal(root);

  final TranslationsEn _root; // ignore: unused_field

  // Translations
  @override
  String get unknown => 'Operation failed. Please try again later.';
  @override
  String get walletLocked => 'Wallet is locked. Please unlock it first.';
  @override
  String get invalidMnemonic => 'Invalid mnemonic format or checksum.';
  @override
  String get invalidPrivateKey => 'Invalid private key format.';
  @override
  String get passwordAttemptLocked =>
      'Too many password attempts. Please try again later.';
  @override
  String get walletPasswordTooShort =>
      'Wallet password must contain at least 8 characters.';
  @override
  String get walletPasswordTooWeak =>
      'This password is too common. Use a harder-to-guess password.';
  @override
  String get invalidRpcUrl => 'Invalid RPC URL.';
  @override
  String get rpcUnavailable =>
      'RPC node is unavailable. Check the address or network.';
  @override
  String get rpcMissingCredential =>
      'RPC credentials are missing. Reconfigure the node.';
  @override
  String get rpcInvalidCredential => 'RPC credentials are invalid or expired.';
  @override
  String get rpcAccessDenied =>
      'RPC access was denied. Check node permissions, IP restrictions, or VPN settings.';
  @override
  String get rpcRateLimited =>
      'RPC requests are rate limited or the quota is exhausted.';
  @override
  String get rpcChainMismatch => 'RPC node does not match the current chain.';
  @override
  String get balanceQueryFailed =>
      'Balance query failed. Please check the RPC node.';
  @override
  String get feeEstimateFailed =>
      'Fee estimation failed. The transaction cannot be sent yet.';
  @override
  String get transactionBroadcastFailed =>
      'Transaction submission failed. Please try again later.';
  @override
  String get suiInsufficientBalance => 'Insufficient Sui Coin balance.';
  @override
  String get suiInsufficientGas => 'Insufficient SUI balance for gas.';
  @override
  String get suiObjectConflict =>
      'A Sui Coin object is in use or stale. Refresh and try again.';
  @override
  String get suiSimulationFailed =>
      'Sui transaction simulation failed. Refresh balances and try again.';
  @override
  String get dappRejected => 'The dApp request was rejected.';
  @override
  String get dappUnsupportedMethod => 'This dApp method is not supported yet.';
  @override
  String get dappUnauthorized => 'This dApp is not authorized.';
  @override
  String get unsupportedChain => 'This chain is not supported yet.';
  @override
  String get securityCheckFailed => 'Security check failed. Please try again.';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEn {
  dynamic _flatMapFunction(String path) {
    return switch (path) {
          'app.name' => 'Safe Wallet',
          'tabs.home' => 'Home',
          'tabs.browser' => 'Browser',
          'tabs.settings' => 'Settings',
          'actions.receive' => 'Receive',
          'actions.send' => 'Send',
          'actions.scan' => 'Scan',
          'actions.confirm' => 'Confirm',
          'actions.submit' => 'Submit',
          'actions.cancel' => 'Cancel',
          'actions.kContinue' => 'Continue',
          'actions.done' => 'Done',
          'actions.back' => 'Back',
          'actions.close' => 'Close',
          'actions.paste' => 'Paste',
          'actions.exitAppHint' => 'Go back again to exit the app',
          'actions.showPassword' => 'Show password',
          'actions.hidePassword' => 'Hide password',
          'onboarding.entryTitle' => 'Start with a secure wallet',
          'onboarding.entrySubtitle' =>
            'Create a new wallet or import an existing one. Private keys and mnemonics stay encrypted on this device.',
          'onboarding.createWallet' => 'Create Wallet',
          'onboarding.importWallet' => 'Import Wallet',
          'onboarding.createTitle' => 'Create New Wallet',
          'onboarding.createBody' =>
            'The app will generate a new mnemonic and derive default EVM, Bitcoin, Tron, Solana, and Sui addresses.',
          'onboarding.riskTitle' => 'Mnemonic Risk Notice',
          'onboarding.riskLoss' =>
            'A lost mnemonic means the wallet cannot be recovered',
          'onboarding.riskResponsibility' =>
            'Keep your mnemonic yourself. Anyone with it can control your assets, and the app cannot restore or freeze the wallet for you.',
          'onboarding.riskNoBackupGate' =>
            'The MVP does not require backup verification, but you must understand the risk before entering the wallet.',
          'onboarding.riskAccepted' => 'I understand the risk',
          'onboarding.importTitle' => 'Import Wallet',
          'onboarding.importBody' =>
            'Import with a mnemonic, EVM private key, Bitcoin private key, Tron private key, Solana private key, or Sui suiprivkey. The material is encrypted after you set a password.',
          'onboarding.importMnemonic' => 'Mnemonic',
          'onboarding.importPrivateKey' => 'Private Key',
          'onboarding.importMnemonicWallet' => 'Mnemonic Wallet',
          'onboarding.importPrivateKeyWallet' => 'Private Key Wallet',
          'onboarding.importMnemonicWalletDescription' => 'Multi-chain wallet',
          'onboarding.importPrivateKeyWalletDescription' =>
            'EVM, Bitcoin, Tron, Solana, or Sui wallet',
          'onboarding.selectImportType' => 'Choose Import Type',
          'onboarding.selectPrivateKeyChain' => 'Choose Private Key Network',
          'onboarding.importEvm' => 'EVM',
          'onboarding.importBitcoin' => 'Bitcoin',
          'onboarding.importTron' => 'Tron',
          'onboarding.importSolana' => 'Solana',
          'onboarding.importSui' => 'Sui',
          'onboarding.mnemonicHint' =>
            'Enter your mnemonic, 12 or 24 words separated by spaces',
          'onboarding.mnemonicWordHint' => 'Enter word',
          'onboarding.mnemonicWordCount12' => '12 English words',
          'onboarding.mnemonicWordCount24' => '24 English words',
          'onboarding.mnemonicHelp' => 'How to get it?',
          'onboarding.mnemonicImportHint' =>
            'Enter a mnemonic to import an existing wallet',
          'onboarding.privateKeyHint' =>
            'EVM hex, Bitcoin WIF/hex, Solana private key, or Sui suiprivkey',
          'onboarding.setPasswordTitle' => 'Set Wallet Password',
          'onboarding.setPasswordBody' =>
            'This password unlocks the local wallet and encrypts wallet data. If you forget it, you must re-import your mnemonic or private key.',
          'onboarding.passwordLabel' => 'Wallet Password',
          'onboarding.confirmPasswordLabel' => 'Confirm Password',
          'onboarding.passwordRequired' => 'Enter a wallet password',
          'onboarding.passwordMismatch' => 'The passwords do not match',
          'onboarding.importMaterialRequired' => 'Enter import material',
          'onboarding.loadingWallet' => 'Loading wallet',
          'onboarding.creatingWallet' => 'Creating wallet',
          'onboarding.importingWallet' => 'Importing wallet',
          'home.defaultWalletName' => 'My Wallet',
          'home.totalValue' => 'Total Value',
          'home.hideAmounts' => 'Hide Amounts',
          'home.showAmounts' => 'Show Amounts',
          'home.recentTransactions' => 'Recent Transactions',
          'home.viewAll' => 'View All',
          'home.assetList' => 'Assets',
          'home.manageTokens' => 'Manage Tokens',
          'home.refreshAssets' => 'Refresh Assets',
          'home.emptyTransactions' => 'No transactions',
          'home.noWallet' => 'No wallet yet',
          'home.walletLocked' => 'Wallet locked',
          'home.loadingAssets' => 'Loading assets',
          'home.emptyAssets' => 'No assets',
          'home.assetLoadError' => 'Failed to load assets',
          'browser.commonDapps' => 'Common dApps',
          'browser.urlHint' => 'Search dApps or enter a URL',
          'browser.invalidUrl' => 'Enter a valid URL',
          'browser.loadFailed' =>
            'Unable to open dApp. Check the URL or network and try again.',
          'browser.confirmExternalTitle' => 'Open Website?',
          'browser.confirmExternalBody' =>
            'Confirm the website domain before opening to avoid disguised sites.',
          'browser.openExternal' => 'Open',
          'browser.swap' => 'Swap',
          'browser.predictions' => 'Predictions',
          'browser.staking' => 'Staking',
          'browser.bridge' => 'Bridge',
          'browser.swapAggregator' => 'Aggregator',
          'browser.swapDex' => 'DEX',
          'browser.swapMeme' => 'Meme',
          'browser.swapCrossChain' => 'Cross-chain',
          'browser.riskHigh' => 'High risk',
          'browser.all' => 'All',
          'browser.networkFilter' => 'Network',
          'browser.typeFilter' => 'Type',
          'browser.allNetworks' => 'All networks',
          'browser.allTypes' => 'All types',
          'browser.selectNetwork' => 'Select network',
          'browser.selectType' => 'Select type',
          'browser.defi' => 'DeFi',
          'browser.nft' => 'NFT',
          'browser.tools' => 'Tools',
          'browser.favorites' => 'Favorites',
          'browser.recent' => 'Recent',
          'browser.emptyFavorites' => 'No favorites',
          'browser.emptyRecent' => 'No recent visits',
          'browser.noResults' => 'No matching dApps',
          'browser.favorite' => 'Favorite',
          'browser.unfavorite' => 'Unfavorite',
          'browser.forward' => 'Forward',
          'browser.refresh' => 'Refresh',
          'dapp.authorizationTitle' => 'Connect dApp',
          'dapp.authorizationBody' =>
            'After approval, this site can read the current account address and request signature or transaction confirmations.',
          'dapp.rememberAuthorization' => 'Remember this site for 30 days',
          'dapp.signatureTitle' => 'Confirm Signature',
          'dapp.transactionTitle' => 'Confirm Transaction',
          'dapp.chainSwitchTitle' => 'Switch Network',
          'dapp.chainSwitchBody' =>
            'This site requests switching the active EVM network. Review before continuing.',
          'dapp.domain' => 'Domain',
          'dapp.chain' => 'Network',
          'dapp.requestedChain' => 'Target Network',
          'dapp.account' => 'Account',
          'dapp.from' => 'From',
          'dapp.to' => 'To',
          'dapp.value' => 'Value',
          'dapp.contract' => 'Contract',
          'dapp.feeEstimate' => 'Fee Estimate',
          'dapp.decodedInfo' => 'Decoded Info',
          'dapp.rawTransactionData' => 'Raw Transaction Data',
          'dapp.message' => 'Message',
          'dapp.approve' => 'Approve',
          'dapp.reject' => 'Reject',
          'dapp.signatureRiskWarning' =>
            'Review the content and site before signing. A signature can represent login, authorization, or another off-chain statement.',
          'dapp.unreadableSignatureWarning' =>
            'This signature content is unreadable. Continue only if you fully trust this site.',
          'dapp.unparsedTransactionWarning' =>
            'This transaction includes an unparsed contract call. Check the site and contract address carefully.',
          'dapp.simulationFailedWarning' =>
            ({required Object reason}) =>
                'Transaction simulation failed: ${reason}',
          'dapp.solanaTestTitle' => 'Solana dApp Test',
          'dapp.solanaTestBody' =>
            'This internal page validates the Solana dApp interface boundary. Full external support will ship in a later version.',
          'dapp.solanaBoundaryReserved' => 'Solana dApp Interface Reserved',
          'dapp.solanaConnectCheck' =>
            'Connection request boundary is reserved',
          'dapp.solanaSignCheck' => 'Message signing boundary is reserved',
          'dapp.solanaTransactionCheck' =>
            'Transaction request boundary is reserved',
          'dapp.solanaNonSolanaChain' => 'No Solana network is selected',
          'dapp.solanaUnavailable' => 'No Solana address',
          'chains.network' => 'Network',
          'chains.selectorTitle' => 'Select Network',
          'chains.addNetwork' => 'Add Network',
          'chains.addCustom' => 'Add Custom',
          'chains.addCustomEvm' => 'Add EVM Network',
          'chains.searchNetworkHint' => 'Search networks',
          'chains.emptySearch' => 'No networks to add',
          'chains.removeNetwork' => 'Remove Network',
          'chains.removeNetworkTitle' => 'Remove Network',
          'chains.removeNetworkMessage' =>
            'After removal, this network will no longer be shown and its custom configuration will not be used.',
          'chains.confirmRemoveNetwork' => 'Remove',
          'chains.nameLabel' => 'Network Name',
          'chains.chainIdLabel' => 'Chain ID',
          'chains.rpcUrlLabel' => 'RPC URL',
          'chains.symbolLabel' => 'Native Symbol',
          'chains.blockExplorerLabel' => 'Block Explorer URL',
          'chains.testnetLabel' => 'Testnet',
          'chains.nameRequired' => 'Enter the network name',
          'chains.chainIdRequired' => 'Enter the Chain ID',
          'chains.invalidChainId' => 'Enter a valid Chain ID',
          'chains.rpcUrlRequired' => 'Enter the RPC URL',
          'chains.invalidRpcUrl' => 'Enter a valid RPC URL',
          'chains.symbolRequired' => 'Enter the native token symbol',
          'chains.invalidBlockExplorerUrl' =>
            'Enter a valid block explorer URL',
          'chains.duplicateChainId' => 'This Chain ID already exists',
          'chains.current' => 'Current',
          'chains.mainnet' => 'Mainnet',
          'chains.testnet' => 'Testnet',
          'chains.loading' => 'Loading networks',
          'chains.loadFailed' => 'Failed to load networks',
          'nodes.managementTitle' => 'RPC Nodes',
          'nodes.addNode' => 'Add Node',
          'nodes.editNode' => 'Edit Node',
          'nodes.defaultNode' => 'Default',
          'nodes.chainlistNode' => 'Chainlist',
          'nodes.customNode' => 'Custom',
          'nodes.selected' => 'Selected',
          'nodes.select' => 'Select',
          'nodes.test' => 'Test',
          'nodes.delete' => 'Delete',
          'nodes.deleteTitle' => 'Delete Node',
          'nodes.deleteMessage' =>
            'This custom RPC node will no longer be available.',
          'nodes.confirmDelete' => 'Delete',
          'nodes.save' => 'Save',
          'nodes.nameLabel' => 'Node Name',
          'nodes.urlLabel' => 'URL',
          'nodes.providerLabel' => 'Provider',
          'nodes.customProvider' => 'Custom',
          'nodes.apiKeyLabel' => 'API Key',
          'nodes.authModeLabel' => 'Authentication',
          'nodes.authNone' => 'No extra parameters',
          'nodes.authQuery' => 'Query parameter',
          'nodes.authPath' => 'Path segment',
          'nodes.authHeader' => 'HTTP header',
          'nodes.credentialParameterLabel' => 'Credential parameter',
          'nodes.credentialRequired' => 'Enter the node credential',
          'nodes.credentialKeepHint' =>
            'Leave blank to keep the existing credential',
          'nodes.urlKeepHint' => 'Leave blank to keep the existing URL',
          'nodes.providerUnsupported' =>
            'This provider does not support the current network',
          'nodes.noteLabel' => 'Note',
          'nodes.nameRequired' => 'Enter a node name',
          'nodes.urlRequired' => 'Enter a URL',
          'nodes.statusUntested' => 'Untested',
          'nodes.statusTesting' => 'Testing',
          'nodes.statusAvailable' => 'Available',
          'nodes.statusUnavailable' => 'Unavailable',
          'nodes.blockHeightPrefix' => 'Block',
          'nodes.latencyMsSuffix' => 'ms',
          'nodes.trackingNone' => 'No tracking',
          'nodes.trackingYes' => 'Tracking',
          'nodes.trackingUnknown' => 'Tracking unknown',
          'nodes.loadFailed' => 'Failed to load nodes',
          'nodes.empty' => 'No nodes',
          'tokens.managementTitle' => 'Token Management',
          'tokens.addToken' => 'Add Token',
          'tokens.addCustomToken' => 'Add Custom',
          'tokens.searchTokenHint' =>
            'Search by name, symbol, or contract address',
          'tokens.emptySearch' => 'No matching tokens',
          'tokens.runDiscovery' => 'Discover Tokens',
          'tokens.discovering' => 'Discovering',
          'tokens.discoverySuccess' =>
            ({required Object count}) => 'Discovered ${count} tokens',
          'tokens.discoveryEmpty' => 'No held tokens found',
          'tokens.discoveryFailed' =>
            'Token discovery failed. Check the RPC node.',
          'tokens.contractAddressLabel' => 'Contract Address',
          'tokens.symbolLabel' => 'Token Symbol',
          'tokens.nameLabel' => 'Token Name',
          'tokens.decimalsLabel' => 'Decimals',
          'tokens.contractAddressRequired' => 'Enter the contract address',
          'tokens.invalidContractAddress' => 'Enter a valid contract address',
          'tokens.metadataRequired' => 'Enter the token name and symbol',
          'tokens.invalidDecimals' => 'Enter valid decimals',
          'tokens.hide' => 'Hide',
          'tokens.unhide' => 'Unhide',
          'tokens.builtIn' => 'Built-in',
          'tokens.userAdded' => 'Manual',
          'tokens.discovered' => 'Discovered',
          'tokens.hidden' => 'Hidden',
          'tokens.empty' => 'No tokens',
          'tokens.loadFailed' => 'Failed to load tokens',
          'assets.detailTitle' => 'Asset Details',
          'assets.network' => 'Network',
          'assets.balance' => 'Balance',
          'assets.fiatValue' => 'Estimated Value',
          'assets.contractAddress' => 'Contract Address',
          'assets.nativeAsset' => 'Native asset',
          'assets.currentPrice' => 'Current Price',
          'assets.change24h' => '24h Change',
          'assets.marketOverview' => 'Market Overview',
          'assets.volume24h' => '24h Volume',
          'assets.liquidity' => 'Liquidity',
          'assets.marketCap' => 'Market Cap',
          'assets.fdv' => 'FDV',
          'assets.transactions24h' => '24h Buys / Sells',
          'assets.primaryPair' => 'Primary Pair',
          'assets.viewOnDexScreener' => 'View on DexScreener',
          'assets.marketDataUnavailable' => 'Market data unavailable',
          'assets.marketDataSource' => 'Source: DexScreener',
          'assets.updatedAt' => 'Updated',
          'assets.pairCreatedAt' => 'Pool created',
          'assets.lowLiquidityWarning' =>
            'This pool has low liquidity and its market price may be volatile.',
          'assets.priceDivergenceWarning' =>
            'The wallet valuation price differs significantly from the DEX market price.',
          'transactions.historyTitle' => 'Transaction History',
          'transactions.empty' => 'No transactions',
          'transactions.loadFailed' => 'Failed to load transactions',
          'transactions.submitting' => 'Submitting',
          'transactions.submitted' => 'Submitted',
          'transactions.success' => 'Success',
          'transactions.failed' => 'Failed',
          'transactions.incoming' => 'Receive',
          'transactions.outgoing' => 'Send',
          'transactions.operationWrap' => 'Wrap Native Coin',
          'transactions.operationUnwrap' => 'Unwrap Native Coin',
          'transactions.operationStake' => 'Stake TRX',
          'transactions.operationUnstake' => 'Unstake TRX',
          'transactions.operationWithdrawUnfreeze' => 'Withdraw Unstaked TRX',
          'transactions.operationCancelUnfreeze' => 'Cancel All Unstakes',
          'transactions.operationDelegateResource' => 'Delegate TRON Resources',
          'transactions.operationUndelegateResource' =>
            'Undelegate TRON Resources',
          'transactions.operationVote' => 'Vote for Representatives',
          'transactions.operationClaimReward' => 'Claim Voting Reward',
          'transactions.viewMoreOnExplorer' => 'View More on Explorer',
          'transfer.title' => 'Send',
          'transfer.confirmTitle' => 'Confirm Transfer',
          'transfer.resultTitle' => 'Transfer Result',
          'transfer.copyTransactionHash' => 'Copy Transaction Hash',
          'transfer.viewTransactionExplorer' => 'View Explorer',
          'transfer.transactionHashCopied' => 'Transaction hash copied',
          'transfer.selectedAsset' => 'Select Asset',
          'transfer.hideZeroBalances' => 'Hide zero-balance assets',
          'transfer.recipientLabel' => 'Recipient Address',
          'transfer.amountLabel' => 'Amount',
          'transfer.memoLabel' => 'Memo / Tag',
          'transfer.memoOptionalHelper' =>
            'Optional. Fill this only if the recipient requires it.',
          'transfer.memoRequiredLabel' => 'Memo / Tag',
          'transfer.memoRequiredHelper' => 'Required for this asset.',
          'transfer.selectContact' => 'Select Contact',
          'transfer.max' => 'Max',
          'transfer.next' => 'Next',
          'transfer.balance' => 'Balance',
          'transfer.noAssets' => 'No transferable assets',
          'transfer.walletLocked' => 'Wallet locked',
          'transfer.invalidAddress' => 'Invalid recipient address',
          'transfer.invalidAmount' => 'Enter an amount greater than 0',
          'transfer.insufficientBalance' => 'Insufficient balance',
          'transfer.unavailableBalance' => 'Asset balance is unavailable',
          'transfer.memoRequired' => 'Enter the required Memo / Tag',
          'transfer.feeFailed' =>
            'Fee estimation failed. You cannot continue yet.',
          'transfer.chain' => 'Network',
          'transfer.from' => 'From',
          'transfer.to' => 'To',
          'transfer.token' => 'Asset',
          'transfer.amount' => 'Amount',
          'transfer.fee' => 'Fee',
          'transfer.estimatedFee' => 'Estimated fee',
          'transfer.maximumFee' => 'Maximum fee',
          'transfer.feeSettings' => 'Fee settings',
          'transfer.feeEconomy' => 'Economy',
          'transfer.feeEconomyHint' =>
            'Lower fee, confirmation may take longer',
          'transfer.feeStandard' => 'Standard',
          'transfer.feeStandardHint' => 'Balanced fee and confirmation speed',
          'transfer.feeFast' => 'Fast',
          'transfer.feeFastHint' => 'Higher fee for priority confirmation',
          'transfer.feeCustom' => 'Custom',
          'transfer.feeCustomHint' => 'Set chain fee parameters manually',
          'transfer.maxFeeGwei' => 'Max fee (Gwei)',
          'transfer.priorityFeeGwei' => 'Priority fee (Gwei)',
          'transfer.gasPriceGwei' => 'Gas price (Gwei)',
          'transfer.priorityFeeSol' => 'Total priority fee (SOL)',
          'transfer.bitcoinFeeRate' => 'Fee rate (sat/vB)',
          'transfer.estimatedConfirmation' => 'Estimated confirmation',
          'transfer.approximately' => 'Approx.',
          'transfer.blocks' => 'blocks',
          'transfer.tronFeeLimit' => 'Maximum TRX burn',
          'transfer.applyFee' => 'Apply fee',
          'transfer.invalidFee' => 'Enter a valid fee',
          'transfer.maxFeeBelowPriority' =>
            'Max fee cannot be lower than priority fee',
          'transfer.feeLimitBelowEstimate' =>
            'Maximum TRX burn cannot be below the estimated fee',
          'transfer.feeTooLow' =>
            'This fee is below the network base fee and may not confirm',
          'transfer.feeVeryHigh' =>
            'This fee is much higher than the network suggestion',
          'transfer.feeModel' => 'Fee Model',
          'transfer.feeModelEip1559' => 'EIP-1559',
          'transfer.feeModelLegacy' => 'Legacy Gas Price',
          'transfer.feeModelBitcoin' => 'Bitcoin Fee',
          'transfer.feeModelTron' => 'Tron Fee',
          'transfer.feeModelSolana' => 'Solana Fee',
          'transfer.feeModelSui' => 'Sui Gas',
          'transfer.maxFeePerGas' => 'Max Fee Per Gas',
          'transfer.maxPriorityFeePerGas' => 'Priority Fee Per Gas',
          'transfer.gasPrice' => 'Gas Price',
          'transfer.totalDeduction' => 'Total Deduction',
          'transfer.newRecipientWarning' =>
            'This is a new recipient. Verify the full address and destination network.',
          'transfer.lookalikeRecipientWarning' =>
            ({required Object address}) =>
                'This address closely resembles a previous recipient but is different. It may be address poisoning. Similar address: ${address}',
          'transfer.contractAddress' => 'Contract Address',
          'transfer.riskWarnings' => 'Risk Warnings',
          'transfer.riskLegacy' =>
            'This network is using the legacy gas price model. Review the fee before signing.',
          'transfer.riskErc20' =>
            'This is a contract token transfer. Check the contract and recipient addresses.',
          'transfer.scanTitle' => 'Scan',
          'transfer.scanInstruction' =>
            'Scan a wallet address QR code. The address will be filled into the transfer recipient field.',
          'transfer.scanInvalid' => 'The QR code is not a valid address.',
          'transfer.scanSuccess' => 'Address detected',
          'transfer.scanCameraPermissionDenied' =>
            'Camera permission is required to scan QR codes.',
          'transfer.scanCameraUnsupported' =>
            'Scanning is not supported on this device.',
          'transfer.scanCameraError' =>
            'Unable to start the camera. Try again later.',
          'addressBook.managementTitle' => 'Address Book',
          'addressBook.addContact' => 'Add Contact',
          'addressBook.editContact' => 'Edit Contact',
          'addressBook.delete' => 'Delete',
          'addressBook.save' => 'Save',
          'addressBook.nameLabel' => 'Contact Name',
          'addressBook.addressLabel' => 'Wallet Address',
          'addressBook.noteLabel' => 'Note',
          'addressBook.chainTypeLabel' => 'Chain Type',
          'addressBook.evm' => 'EVM',
          'addressBook.bitcoin' => 'Bitcoin',
          'addressBook.tron' => 'Tron',
          'addressBook.solana' => 'Solana',
          'addressBook.sui' => 'Sui',
          'addressBook.nameRequired' => 'Enter a contact name',
          'addressBook.addressRequired' => 'Enter a wallet address',
          'addressBook.invalidAddress' =>
            'Address does not match the selected chain type',
          'addressBook.deleteTitle' => 'Delete Contact',
          'addressBook.deleteMessage' =>
            'This contact will no longer be available from the address book.',
          'addressBook.confirmDelete' => 'Delete',
          'addressBook.empty' => 'No contacts',
          'addressBook.loadFailed' => 'Failed to load contacts',
          'addressBook.pickTitle' => 'Select Contact',
          'addressBook.otherWallets' => 'Other Wallets',
          'addressBook.contacts' => 'Address Book Contacts',
          'addressBook.noContactsForChain' =>
            'No contacts for the current chain',
          'wallet.create' => 'Create Wallet',
          'wallet.import' => 'Import Wallet',
          'wallet.view' => 'View',
          'wallet.mnemonicWallet' => 'Mnemonic',
          'wallet.privateKeyWallet' => 'Private Key',
          'wallet.moreActions' => 'More actions',
          'wallet.copyEvm' => 'Copy EVM Address',
          'wallet.copyBtc' => 'Copy BTC Address',
          'wallet.copySolana' => 'Copy Solana Address',
          'wallet.copySui' => 'Copy Sui Address',
          'wallet.receiveQr' => 'Receive QR',
          'wallet.receiveQrTitle' =>
            ({required Object walletName, required Object chainName}) =>
                '${walletName} - ${chainName}',
          'wallet.copyAddress' => 'Copy Address',
          'wallet.copy' => 'Copy',
          'wallet.saveQrImage' => 'Save',
          'wallet.amount' => 'Amount',
          'wallet.enterAmountTitle' => 'Enter Amount',
          'wallet.amountConfirm' => 'OK',
          'wallet.amountApproxPrefix' => '≈',
          'wallet.usdCode' => 'USD',
          'wallet.noAddressForChain' =>
            'This wallet does not have an address for the current chain',
          'wallet.qrImageSaved' => 'QR image saved to gallery',
          'wallet.qrImagePhotoPermissionRequired' =>
            'Photo access is required to save the QR image',
          'wallet.qrImageSaveFailed' =>
            'Failed to save QR image. Please try again.',
          'wallet.rename' => 'Rename',
          'wallet.changePassword' => 'Change Password',
          'wallet.currentPasswordLabel' => 'Current Wallet Password',
          'wallet.newPasswordLabel' => 'New Wallet Password',
          'wallet.confirmNewPasswordLabel' => 'Confirm New Password',
          'wallet.newPasswordRequired' => 'Enter a new wallet password',
          'wallet.passwordChanged' => 'Password changed',
          'wallet.nameLabel' => 'Wallet Name',
          'wallet.switchWallet' => 'Switch Wallet',
          'wallet.selected' => 'Current',
          'wallet.delete' => 'Delete',
          'wallet.deleteTitle' => 'Delete Wallet',
          'wallet.deleteMessage' =>
            'Confirm your password before deleting. You must re-import the mnemonic or private key to recover this wallet.',
          'wallet.deleteAcknowledge' =>
            'I confirm I have backed up this wallet\'s mnemonic or private key',
          'wallet.deleteRequiresConfirmation' =>
            'Confirm that the wallet is backed up first',
          'wallet.exportSecret' => 'Export',
          'wallet.exportMnemonic' => 'Export Mnemonic',
          'wallet.exportPrivateKey' => 'Export Private Key',
          'wallet.exportBtcPrivateKey' => 'Export BTC Private Key',
          'wallet.exportSecretWarning' =>
            'High-risk operation. Make sure your surroundings are private. Do not screenshot or send the exported content to anyone.',
          'wallet.exportPasswordTitle' => 'Verify Wallet Password',
          'wallet.exportPasswordBody' =>
            'Enter the wallet password to view the exported content.',
          'wallet.mnemonicRiskWarning' =>
            'A mnemonic can restore the wallet and control all of its assets. Do not take screenshots, upload it to the cloud, or send it to anyone. Clear the clipboard after copying.',
          'wallet.privateKeyRiskWarning' =>
            'A private key directly controls assets on its network. Do not take screenshots, paste it into untrusted apps, or send it to anyone. Clear the clipboard after copying.',
          'wallet.mnemonicCopied' => 'Mnemonic copied',
          'wallet.privateKeyCopied' => 'Private key copied',
          'wallet.addressCopied' => 'Address copied',
          'wallet.evmAddress' => 'EVM Address',
          'wallet.btcAddress' => 'BTC Address',
          'wallet.tronAddress' => 'Tron Address',
          'wallet.solanaAddress' => 'Solana Address',
          'wallet.suiAddress' => 'Sui Address',
          'wallet.unlockTitle' => 'Unlock Wallet',
          'wallet.unlockBody' =>
            'Enter the local wallet password to restore the current session.',
          'wallet.unlockButton' => 'Unlock',
          'wallet.unlocking' => 'Unlocking',
          'wallet.signingPasswordTitle' => 'Verify Signing Identity',
          'wallet.signingPasswordBody' =>
            'Verify your identity to continue this signing request.',
          'wallet.rememberSigningPassword' =>
            'Remember password for 15 minutes',
          'wallet.biometricSetupTitle' => 'Set Up Biometric Password',
          'wallet.biometricSetupBody' =>
            'Use fingerprint or face authentication first when the wallet password is needed.',
          'wallet.biometricSetupConfirm' => 'Set Up',
          'wallet.biometricReason' => 'Authenticate to use the wallet password',
          'wallet.biometricUseButton' => 'Use Biometrics',
          'wallet.biometricEnabled' => 'Biometric password enabled',
          'settings.walletManagement' => 'Wallet Management',
          'settings.networkManagement' => 'Network Management',
          'settings.addressBook' => 'Address Book',
          'settings.advanced' => 'Advanced',
          'settings.preferences' => 'Preferences',
          'settings.language' => 'Language',
          'settings.fiatCurrency' => 'Currency',
          'settings.fiatCurrencyUsd' => 'US Dollar (USD)',
          'settings.fiatCurrencyCny' => 'Chinese Yuan (CNY)',
          'settings.fiatCurrencyEur' => 'Euro (EUR)',
          'settings.fiatCurrencyJpy' => 'Japanese Yen (JPY)',
          'settings.themeMode' => 'Theme Mode',
          'settings.themeModeSystem' => 'Follow System',
          'settings.themeModeLight' => 'Light Mode',
          'settings.themeModeDark' => 'Dark Mode',
          'settings.themeColor' => 'Theme Color',
          'settings.themeColorIndigo' => 'Indigo',
          'settings.themeColorBlue' => 'Blue',
          'settings.themeColorPurple' => 'Purple',
          'settings.themeColorGreen' => 'Green',
          'settings.themeColorOrange' => 'Orange',
          'settings.themeColorRose' => 'Rose',
          'settings.themeColorNavy' => 'Navy',
          'settings.security' => 'Security',
          'settings.about' => 'About',
          'settings.languageSystem' => 'Follow System',
          'settings.languageZh' => 'Simplified Chinese',
          'settings.languageEn' => 'English',
          'settings.requirePasswordOnLaunch' => 'Require Password on Launch',
          'settings.requirePasswordOnLaunchSubtitle' =>
            'Ask for the wallet password every time the app starts',
          'settings.backgroundPrivacyShield' => 'Background Privacy Shield',
          'settings.backgroundPrivacyShieldSubtitle' =>
            'Blur app content when it enters the background',
          'settings.autoLock' => 'Auto-Lock',
          'settings.autoLockSubtitle' =>
            'Lock the wallet after leaving the app',
          'settings.autoLockImmediately' => 'Immediately',
          'settings.autoLockOneMinute' => '1 minute',
          'settings.autoLockFiveMinutes' => '5 minutes',
          'settings.autoLockFifteenMinutes' => '15 minutes',
          'settings.autoLockOneHour' => '1 hour',
          'settings.biometricPassword' => 'Biometric Password',
          'settings.biometricPasswordSubtitle' =>
            'Use biometrics when the wallet password is needed',
          'settings.biometricPasswordUnavailable' =>
            'Biometric authentication is unavailable on this device',
          'settings.biometricPasswordSetupPrompt' =>
            'Enter the current wallet password to enable biometric password use.',
          'settings.changePasswordSubtitle' =>
            'Update the global wallet password',
          'settings.securityLog' => 'Security Log',
          'settings.securityLogSubtitle' =>
            'Automatically record and review sensitive security actions on this device',
          'settings.securityLogPasswordTitle' => 'Verify Wallet Password',
          'settings.securityLogPasswordBody' =>
            'Verify the wallet password before viewing the security log.',
          'settings.securityLogEmpty' => 'No security log entries',
          'settings.securityLogSafetyNotice' =>
            'The security log stores only the action type, wallet name, chain, public address, asset, amount, and time on this device. It never stores private keys, mnemonics, passwords, or signature contents.',
          _ => null,
        } ??
        switch (path) {
          'settings.securityLogWalletLabel' => 'Wallet: ',
          'settings.securityLogChainLabel' => 'Chain: ',
          'settings.securityLogAmountLabel' => 'Amount: ',
          'settings.securityLogAddressLabel' => 'Public address: ',
          'settings.securityLogViewMnemonic' => 'Viewed Mnemonic',
          'settings.securityLogViewPrivateKey' => 'Viewed Private Key',
          'settings.securityLogCopyMnemonic' => 'Copied Mnemonic',
          'settings.securityLogCopyPrivateKey' => 'Copied Private Key',
          'settings.securityLogCreateWallet' => 'Created Wallet',
          'settings.securityLogImportWallet' => 'Imported Wallet',
          'settings.securityLogDeleteWallet' => 'Deleted Wallet',
          'settings.securityLogChangePassword' => 'Changed Password',
          'settings.securityLogSignMessage' => 'Signed Message',
          'settings.securityLogSignTransaction' => 'Signed Transaction',
          'settings.securityLogWrapNative' => 'Wrapped Native Token',
          'settings.securityLogUnwrapNative' => 'Unwrapped Native Token',
          'settings.securityLogSolanaRentRecovery' => 'Solana Rent Recovery',
          'settings.securityLogTronStake' => 'TRX Stake',
          'settings.securityLogTronUnstake' => 'TRX Unstake',
          'settings.securityLogTronWithdrawUnfreeze' => 'Withdraw Unstaked TRX',
          'settings.securityLogTronCancelUnfreeze' => 'Cancel TRX Unstake',
          'settings.securityLogTronDelegateResource' =>
            'Delegate TRON Resources',
          'settings.securityLogTronUndelegateResource' =>
            'Undelegate TRON Resources',
          'settings.securityLogTronVote' => 'TRON Super Representative Vote',
          'settings.securityLogTronClaimReward' => 'Claim TRON Voting Reward',
          'settings.clearDappPermissions' => 'Clear dApp Permissions',
          'settings.clearDappPermissionsSubtitle' =>
            'Remove site connection permissions',
          'settings.connectedDapps' => 'Authorized dApps',
          'settings.noConnectedDapps' => 'No authorized dApps',
          'settings.revoke' => 'Revoke',
          'settings.revokeDappPermission' => 'Revoke dApp Permission',
          'settings.revokeDappPermissionSubtitle' =>
            'After revoking, this site must request approval again before reading the account address.',
          'settings.evmNetworks' => 'EVM Networks',
          'settings.bitcoinNetworks' => 'Bitcoin Networks',
          'settings.solanaNetworks' => 'Solana Networks',
          'settings.tronNetworks' => 'Tron Networks',
          'settings.suiNetworks' => 'Sui Networks',
          'settings.currentRpcUnknown' => 'Loading current RPC',
          'tronStaking.title' => 'TRX Staking',
          'tronStaking.advancedSubtitle' =>
            'Manage Stake 2.0, resource delegation, votes, and rewards',
          'tronStaking.wallet' => 'Wallet',
          'tronStaking.network' => 'Network',
          'tronStaking.refresh' => 'Refresh staking state',
          'tronStaking.noWallet' => 'No wallet with a TRON address',
          'tronStaking.noNetwork' => 'No TRON network is available',
          'tronStaking.loadFailed' =>
            'Could not load staking data. Check the TRON node and retry.',
          'tronStaking.availableBalance' => 'Available balance',
          'tronStaking.bandwidthStaked' => 'Bandwidth staked',
          'tronStaking.energyStaked' => 'Energy staked',
          'tronStaking.tronPower' => 'TRON Power',
          'tronStaking.availableVotes' => 'Available votes',
          'tronStaking.resourceOverview' => 'Resources',
          'tronStaking.bandwidth' => 'Bandwidth',
          'tronStaking.energy' => 'Energy',
          'tronStaking.availableResource' =>
            ({
              required Object available,
              required Object limit,
              required Object used,
            }) => '${available} available / ${limit} · ${used} used',
          'tronStaking.stake' => 'Stake',
          'tronStaking.unstake' => 'Unstake',
          'tronStaking.delegate' => 'Delegate resources',
          'tronStaking.vote' => 'Vote for representatives',
          'tronStaking.stakeTitle' => 'Stake TRX',
          'tronStaking.unstakeTitle' => 'Unstake TRX',
          'tronStaking.delegateTitle' => 'Delegate resources',
          'tronStaking.undelegateTitle' => 'Undelegate resources',
          'tronStaking.resourceType' => 'Resource type',
          'tronStaking.amount' => 'Amount',
          'tronStaking.amountHint' => 'Enter a TRX amount',
          'tronStaking.maximum' => 'Max',
          'tronStaking.continueAction' => 'Continue',
          'tronStaking.invalidAmount' =>
            'Enter a valid TRX amount with no more than 6 decimals',
          'tronStaking.insufficientBalance' =>
            'Available TRX balance is insufficient',
          'tronStaking.insufficientStaked' =>
            'The selected resource has insufficient stake',
          'tronStaking.noUnfreezeSlots' =>
            'No unstake slots are currently available',
          'tronStaking.confirmStake' => 'Confirm stake',
          'tronStaking.confirmUnstake' => 'Confirm unstake',
          'tronStaking.confirmDelegate' => 'Confirm resource delegation',
          'tronStaking.confirmUndelegate' => 'Confirm resource undelegation',
          'tronStaking.confirmWithdraw' => 'Confirm unstaked TRX withdrawal',
          'tronStaking.confirmCancel' => 'Confirm cancel all unstakes',
          'tronStaking.confirmVote' => 'Confirm vote allocation',
          'tronStaking.confirmClaimReward' => 'Confirm reward claim',
          'tronStaking.confirmAndSign' => 'Confirm and sign',
          'tronStaking.owner' => 'Wallet address',
          'tronStaking.receiver' => 'Receiver address',
          'tronStaking.receiverHint' => 'Enter a TRON address',
          'tronStaking.invalidReceiver' =>
            'Enter a valid TRON address different from this wallet',
          'tronStaking.lockResource' => 'Lock delegation',
          'tronStaking.lockUnsupported' =>
            'Locked delegation is not supported on this network',
          'tronStaking.locked' => 'Locked',
          'tronStaking.unlocked' => 'Unlocked',
          'tronStaking.lockPeriod' => 'Lock period (blocks)',
          'tronStaking.lockPeriodHint' =>
            ({required Object max}) => 'Enter up to ${max} blocks',
          'tronStaking.lockPeriodValue' =>
            ({required Object count}) => '${count} blocks',
          'tronStaking.estimatedFee' => 'Estimated network fee',
          'tronStaking.remainingBalance' => 'Available balance after staking',
          'tronStaking.feeCalculatedByNetwork' =>
            'Calculated dynamically from Bandwidth usage',
          'tronStaking.feeEstimateFailed' =>
            'Network fee estimation failed. You cannot continue yet.',
          'tronStaking.unstakeDelay' =>
            ({required Object days}) =>
                'Unstaking takes ${days} days and must be withdrawn after expiry',
          'tronStaking.unstakeAvailableAt' =>
            ({required Object date}) => 'Estimated withdrawal date: ${date}',
          'tronStaking.unfreezeSlotsRemaining' =>
            ({required Object count}) => '${count} unstake slots remaining',
          'tronStaking.pendingUnfreeze' => 'Pending unstake',
          'tronStaking.pendingTotal' =>
            ({required Object amount}) => 'Pending total: ${amount} TRX',
          'tronStaking.withdrawableAmount' =>
            ({required Object amount}) =>
                'Currently withdrawable: ${amount} TRX',
          'tronStaking.nextUnfreezeAt' =>
            ({required Object date}) => 'Next expiry: ${date}',
          'tronStaking.pendingEmpty' => 'There is no pending unstake',
          'tronStaking.expiresAt' =>
            ({required Object date}) => 'Expires ${date}',
          'tronStaking.withdrawable' => 'Withdrawable',
          'tronStaking.withdraw' =>
            ({required Object amount}) => 'Withdraw ${amount} TRX',
          'tronStaking.cancelAll' => 'Cancel all unstakes',
          'tronStaking.cancelAllWarning' =>
            'This cancels every unexpired unstake. The protocol does not support cancelling only one entry.',
          'tronStaking.delegations' => 'Resource delegations',
          'tronStaking.delegationsEmpty' => 'There are no resource delegations',
          'tronStaking.delegatedTo' => 'Delegated to',
          'tronStaking.receivedFrom' => 'Received from',
          'tronStaking.undelegate' => 'Undelegate',
          'tronStaking.witnesses' => 'Super Representatives',
          'tronStaking.witnessSearch' => 'Search address or URL',
          'tronStaking.witnessVotes' =>
            ({required Object count}) => '${count} votes',
          'tronStaking.myVotes' => 'My votes',
          'tronStaking.voteSummary' =>
            ({required Object used, required Object total}) =>
                '${used} / ${total} votes allocated',
          'tronStaking.clearVotes' => 'Clear votes',
          'tronStaking.reward' => 'Claimable reward',
          'tronStaking.claimReward' => 'Claim reward',
          'tronStaking.noReward' => 'There is no reward to claim',
          'tronStaking.submitting' => 'Submitting TRON transaction…',
          'tronStaking.submitted' => 'TRON transaction submitted',
          'tronStaking.walletLocked' => 'Unlock the wallet to sign',
          'tronStaking.signingKeyUnavailable' =>
            'This wallet has no available TRON private key',
          'tronStaking.nothingToWithdraw' =>
            'There is no expired TRX available to withdraw',
          'tronStaking.cancelUnsupported' =>
            'This network does not support cancelling all unstakes',
          'tronStaking.nothingToCancel' =>
            'There is no pending unstake to cancel',
          'tronStaking.delegationUnsupported' =>
            'Resource delegation is not enabled on this network',
          'tronStaking.invalidDelegation' =>
            'The delegation address or lock settings are invalid',
          'tronStaking.insufficientDelegatableBalance' =>
            'There is no staked resource available to delegate',
          'tronStaking.delegationLocked' =>
            'This delegation is locked and cannot be removed before expiry',
          'tronStaking.insufficientDelegatedBalance' =>
            'The undelegatable resource balance is insufficient',
          'tronStaking.excessiveVotes' =>
            'The vote allocation exceeds available TRON Power',
          'tronStaking.nothingToClaim' => 'There is no reward to claim',
          'tronStaking.transactionValidationFailed' =>
            'The transaction returned by the node failed local security validation',
          'tronStaking.broadcastFailed' =>
            'Could not submit the TRON transaction. Refresh the on-chain state and retry.',
          'tronStaking.operationUnavailable' =>
            'The current on-chain state does not allow this operation',
          'advanced.title' => 'Advanced',
          'advanced.contractCall' => 'Contract Call',
          'advanced.contractCallSubtitle' =>
            'Read contracts or sign and submit write calls',
          'advanced.wrappedNative' => 'Wrap Native Token',
          'advanced.wrappedNativeSubtitle' =>
            'Convert 1:1 between the native token and its wrapped token',
          'advanced.wrappedNativeWallet' => 'Wallet',
          'advanced.wrappedNativeNetwork' => 'Network',
          'advanced.wrappedNativeWrap' => 'Wrap',
          'advanced.wrappedNativeUnwrap' => 'Unwrap',
          'advanced.wrappedNativeBalance' => 'Native Balance',
          'advanced.wrappedNativeTokenBalance' => 'Wrapped Token Balance',
          'advanced.wrappedNativeAmount' => 'Amount',
          'advanced.wrappedNativeAmountHint' => 'Enter amount to convert',
          'advanced.wrappedNativeMax' => 'Max',
          'advanced.wrappedNativeReview' => 'Review Transaction',
          'advanced.wrappedNativePreparing' =>
            'Simulating and estimating fees…',
          'advanced.wrappedNativeRefresh' => 'Refresh Balances',
          'advanced.wrappedNativeRisk' =>
            'The conversion uses this network\'s standard wrapped-token contract at a 1:1 rate. Verify the network, amount, fee, and destination token before signing.',
          'advanced.wrappedNativeConfirmTitle' =>
            'Confirm Native Token Conversion',
          'advanced.wrappedNativeFrom' => 'Pay',
          'advanced.wrappedNativeTo' => 'Receive',
          'advanced.wrappedNativeNetworkFee' => 'Maximum Network Fee',
          'advanced.wrappedNativeRent' => 'Account Rent',
          'advanced.wrappedNativeConfirmWrap' => 'Confirm Wrap',
          'advanced.wrappedNativeConfirmUnwrap' => 'Confirm Unwrap',
          'advanced.wrappedNativeSubmitting' => 'Signing and submitting…',
          'advanced.wrappedNativeSuccessWrap' => 'Wrap transaction submitted',
          'advanced.wrappedNativeSuccessUnwrap' =>
            'Unwrap transaction submitted',
          'advanced.wrappedNativeTransactionHash' => 'Transaction Hash',
          'advanced.wrappedNativeViewExplorer' => 'View in Explorer',
          'advanced.wrappedNativeNoWallet' =>
            'No wallet is available for the selected network',
          'advanced.wrappedNativeNoNetwork' =>
            'No network supports native token wrapping',
          'advanced.wrappedNativeInvalidAmount' =>
            'Enter a valid amount greater than zero',
          'advanced.wrappedNativeInsufficientNative' =>
            'Insufficient native balance after reserving network fees and possible account rent',
          'advanced.wrappedNativeInsufficientWrapped' =>
            'Insufficient wrapped-token balance',
          'advanced.wrappedNativeBalanceFailed' =>
            'Unable to load balances. Check the RPC node and try again',
          'advanced.wrappedNativePreparationFailed' =>
            'Transaction simulation or fee estimation failed. Check the balance and RPC node',
          'advanced.wrappedNativeWalletLocked' =>
            'Unlock the wallet before signing',
          'advanced.wrappedNativeSigningKeyUnavailable' =>
            'The selected wallet has no signing key for this network',
          'advanced.wrappedNativeSubmissionFailed' =>
            'Transaction submission failed. Refresh balances and verify the on-chain result',
          'advanced.solanaRentRecovery' => 'Solana Rent Recovery',
          'advanced.solanaRentRecoverySubtitle' =>
            'Close safe empty token accounts and reclaim their rent',
          'advanced.solanaRentWallet' => 'Wallet',
          'advanced.solanaRentNetwork' => 'Solana Network',
          'advanced.solanaRentRefresh' => 'Refresh Recoverable Rent',
          'advanced.solanaRentRecoverableAccounts' => 'Recoverable Accounts',
          'advanced.solanaRentSelectedSummary' => 'Selected Accounts',
          'advanced.solanaRentTotalRecoverable' => 'Total Recoverable',
          'advanced.solanaRentNetRecoverable' => 'Estimated Net Amount',
          'advanced.solanaRentNoAccounts' =>
            'There are no empty token accounts that can be safely closed',
          'advanced.solanaRentStartRecovery' => 'Start Recovery',
          'advanced.solanaRentRisk' =>
            'Recovery closes the selected zero-balance token accounts and returns their rent to this wallet. A token account may be created again and charge rent if you hold that token later.',
          'advanced.solanaRentConfirmTitle' => 'Confirm Rent Recovery',
          'advanced.solanaRentSelectedAccounts' => 'Accounts',
          'advanced.solanaRentReceivingWallet' => 'Receiving Wallet',
          'advanced.solanaRentConfirmAndSign' => 'Confirm and Sign',
          'advanced.solanaRentScanning' => 'Scanning recoverable accounts…',
          'advanced.solanaRentSubmitting' =>
            'Submitting recovery transactions in batches…',
          'advanced.solanaRentRecovering' => 'Recovering…',
          'advanced.solanaRentSuccess' => 'Rent Recovery Successful',
          'advanced.solanaRentPartialSuccess' => 'Rent Partially Recovered',
          'advanced.solanaRentFailed' => 'Rent Recovery Failed',
          'advanced.solanaRentRecoveredAccounts' => 'Completed Accounts',
          'advanced.solanaRentRecoveredAmount' => 'Recovered Amount',
          'advanced.solanaRentSignatures' => 'Transaction Signatures',
          'advanced.solanaRentCopySignature' => 'Copy Signature',
          'advanced.solanaRentSignatureCopied' =>
            'Transaction signature copied',
          'advanced.solanaRentOpenSolscan' => 'View on Solscan',
          'advanced.solanaRentSplToken' => 'SPL Token',
          'advanced.solanaRentToken2022' => 'Token-2022',
          'advanced.solanaRentNoWallet' =>
            'No wallet with a Solana address is available',
          'advanced.solanaRentNoNetwork' => 'No Solana network is available',
          'advanced.solanaRentScanFailed' =>
            'Unable to scan recoverable accounts. Check the RPC node and try again',
          'advanced.solanaRentSimulationFailed' =>
            'Transaction simulation failed. The selected accounts may have changed',
          'advanced.solanaRentInsufficientFee' =>
            'The wallet does not have enough SOL to pay the estimated network fee',
          'advanced.solanaRentSelectAccount' =>
            'Select at least one token account to recover',
          'advanced.solanaRentWalletLocked' =>
            'Unlock the wallet before signing',
          'advanced.solanaRentSigningKeyUnavailable' =>
            'The selected wallet has no Solana signing key',
          'advanced.solanaRentAccountsChanged' =>
            'Recoverable accounts changed. Refresh and try again',
          'advanced.solanaRentRecoveryFailed' =>
            'Some or all recovery transactions failed. Refresh to verify the on-chain result',
          'advanced.walletConnect' => 'WalletConnect',
          'advanced.walletConnectSubtitle' =>
            'Connect external dApps and manage active sessions',
          'advanced.walletConnectScan' => 'Scan QR Code',
          'advanced.walletConnectPaste' => 'Paste Connection URI',
          'advanced.walletConnectUriHint' => 'wc: URI',
          'advanced.walletConnectConnect' => 'Connect',
          'advanced.walletConnectActiveSessions' => 'Active Sessions',
          'advanced.walletConnectNoSessions' =>
            'No active WalletConnect sessions',
          'advanced.walletConnectMissingConfig' =>
            'REOWN_PROJECT_ID was not provided at build time. You can set your WalletConnect Dashboard Project ID in the app.',
          'advanced.walletConnectProjectId' => 'Project ID',
          'advanced.walletConnectProjectIdDescription' =>
            'A Project ID is a public project identifier, not a wallet private key.',
          'advanced.walletConnectProjectIdSourceCustom' => 'Set in App',
          'advanced.walletConnectProjectIdSourceBuild' => 'Build Configuration',
          'advanced.walletConnectProjectIdSourceMissing' => 'Not Configured',
          'advanced.walletConnectProjectIdSet' => 'Set',
          'advanced.walletConnectProjectIdReplace' => 'Replace',
          'advanced.walletConnectProjectIdDelete' => 'Delete',
          'advanced.walletConnectProjectIdInputTitle' => 'Set Project ID',
          'advanced.walletConnectProjectIdInputHint' =>
            '32-character hexadecimal Project ID',
          'advanced.walletConnectProjectIdInvalid' =>
            'Enter a 32-character hexadecimal Project ID.',
          'advanced.walletConnectProjectIdSaved' =>
            'Project ID saved and applied.',
          'advanced.walletConnectProjectIdDeleted' =>
            'Custom Project ID deleted. The build configuration is now active.',
          'advanced.walletConnectProjectIdDeletedWithoutBuild' =>
            'Custom Project ID deleted. WalletConnect is now disabled.',
          'advanced.walletConnectProjectIdApplyFailed' =>
            'Project ID was saved, but WalletConnect could not be initialized. Check the value and try again.',
          'advanced.walletConnectProjectIdDeleteTitle' =>
            'Delete Custom Project ID',
          'advanced.walletConnectProjectIdDeleteWithBuild' =>
            'After deletion, WalletConnect will fall back to the Project ID provided at build time.',
          'advanced.walletConnectProjectIdDeleteWithoutBuild' =>
            'No build-time Project ID is available. WalletConnect will be unavailable after deletion.',
          'advanced.walletConnectProjectIdDisconnectTitle' =>
            'Disconnect Active Sessions',
          'advanced.walletConnectProjectIdDisconnectBody' =>
            'Changing the Project ID requires disconnecting all active WalletConnect sessions first.',
          'advanced.walletConnectProjectIdDisconnectFailed' =>
            'Unable to disconnect all sessions. The Project ID was not changed.',
          'advanced.walletConnectInitializeFailed' =>
            'Unable to initialize WalletConnect.',
          'advanced.walletConnectInvalidUri' => 'Invalid WalletConnect URI',
          'advanced.walletConnectDuplicateUri' =>
            'This WalletConnect URI was already handled',
          'advanced.walletConnectPairFailed' =>
            'Unable to start the WalletConnect pairing',
          'advanced.walletConnectPairStarted' => 'Pairing request received',
          'advanced.walletConnectDisconnect' => 'Disconnect',
          'advanced.walletConnectDisconnectTitle' => 'Disconnect Session',
          'advanced.walletConnectDisconnectBody' =>
            'This dApp will no longer be able to request signatures from this wallet.',
          'advanced.walletConnectDisconnectAll' => 'Disconnect All',
          'advanced.walletConnectDisconnectAllTitle' =>
            'Disconnect All Sessions',
          'advanced.walletConnectDisconnectAllBody' =>
            'Disconnect every active WalletConnect session?',
          'advanced.walletConnectExpires' =>
            ({required Object date}) => 'Expires: ${date}',
          'advanced.walletConnectAccounts' => 'Accounts',
          'advanced.walletConnectNetworks' => 'Networks',
          'advanced.walletConnectMethods' => 'Permissions',
          'advanced.walletConnectProposalTitle' => 'Connection Request',
          'advanced.walletConnectProposalAccounts' => 'Wallet accounts',
          'advanced.walletConnectProposalNetworks' => 'Requested networks',
          'advanced.walletConnectProposalMethods' => 'Requested permissions',
          'advanced.walletConnectProposalEvents' => 'Requested events',
          'advanced.walletConnectVerifyValid' =>
            'Domain verified by WalletConnect Verify.',
          'advanced.walletConnectVerifyInvalid' =>
            'Domain mismatch: the verified request origin does not match the sender.',
          'advanced.walletConnectVerifyScam' =>
            'Security risk: this domain is flagged as malicious.',
          'advanced.walletConnectVerifyUnknown' =>
            'The request origin could not be verified. Check it carefully before connecting.',
          'advanced.walletConnectUnsupportedProposal' =>
            'This request includes unsupported required networks or permissions.',
          'advanced.walletConnectApprove' => 'Connect',
          'advanced.walletConnectReject' => 'Reject',
          'advanced.walletConnectCameraTitle' => 'Scan WalletConnect QR',
          'advanced.walletRequired' =>
            'The current wallet has no available EVM address.',
          'advanced.contractAddress' => 'Contract Address',
          'advanced.callMode' => 'Call Mode',
          'advanced.modeStandard' => 'Standard ABI',
          'advanced.modeCustomAbi' => 'Paste ABI',
          'advanced.modeManual' => 'Manual Function',
          'advanced.modeRaw' => 'Raw Calldata',
          'advanced.standardTemplate' => 'Standard Contract Template',
          'advanced.erc20' => 'ERC-20',
          'advanced.erc721' => 'ERC-721',
          'advanced.erc1155' => 'ERC-1155',
          'advanced.abiJson' => 'ABI JSON',
          'advanced.parseAbi' => 'Parse ABI',
          'advanced.manualSignature' =>
            'Function signature, e.g. balanceOf(address)',
          'advanced.outputTypes' => 'Return types separated by commas',
          'advanced.readFunction' => 'Read-only function',
          'advanced.payableFunction' => 'Allow native value',
          'advanced.buildFunction' => 'Build Function',
          'advanced.function' => 'Function',
          'advanced.readBadge' => 'Read',
          'advanced.writeBadge' => 'Write',
          'advanced.argument' =>
            ({
              required Object index,
              required Object name,
              required Object type,
            }) => 'Argument ${index}: ${name} (${type})',
          'advanced.arrayArgumentHint' => 'Enter arrays and tuples as JSON',
          'advanced.rawCalldata' => 'Calldata (0x-prefixed)',
          'advanced.rawWrite' => 'Submit raw calldata as a write transaction',
          'advanced.nativeValue' => 'Native Value',
          'advanced.executeRead' => 'Read Contract',
          'advanced.prepareWrite' => 'Check and Prepare Write',
          'advanced.result' => 'Call Result',
          'advanced.copyResult' => 'Copy Call Result',
          'advanced.resultCopied' => 'Call result copied',
          'advanced.rawResult' => 'Raw Result',
          'advanced.transactionHash' => 'Transaction Hash',
          'advanced.writeRisk' =>
            'Contract writes can transfer assets or authorize third parties. Verify the contract, method, arguments, and calldata before signing.',
          'advanced.confirmWriteTitle' => 'Confirm Contract Write',
          'advanced.chain' => 'Network',
          'advanced.method' => 'Method',
          'advanced.value' => 'Native Value',
          'advanced.gasLimit' => 'Gas Limit',
          'advanced.gasPrice' => 'Gas Price',
          'advanced.estimatedFee' => 'Estimated Fee',
          'advanced.confirmAndSign' => 'Confirm and Sign',
          'advanced.invalidAbi' => 'Invalid ABI JSON',
          'advanced.invalidInput' =>
            'Check the contract address, arguments, and calldata',
          'advanced.notContract' =>
            'No contract code was found at this address',
          'advanced.callFailed' => 'Contract call failed',
          'advanced.walletLocked' => 'Unlock the wallet before signing',
          'advanced.submitted' => 'Contract transaction submitted',
          'about.title' => 'About',
          'about.tagline' => 'A self-custody multichain wallet',
          'about.version' =>
            ({required Object version, required Object buildNumber}) =>
                'Version ${version} (Build ${buildNumber})',
          'about.versionAndUpdates' => 'Version & Updates',
          'about.checkUpdate' => 'Check for Updates',
          'about.checkingUpdate' => 'Checking…',
          'about.releaseNotes' => 'Release Notes',
          'about.github' => 'GitHub',
          'about.transparencyAndSecurity' => 'Transparency & Security',
          'about.dataAndNetwork' => 'Data & Network Information',
          'about.openSourceLicenses' => 'Open Source Licenses',
          'about.helpAndLegal' => 'Help & Legal',
          'about.feedback' => 'Report an Issue',
          'about.privacyPolicy' => 'Privacy Policy',
          'about.termsOfUse' => 'Terms of Use',
          'about.openLinkFailed' =>
            'Unable to open the link. Please try again.',
          'about.checkUpdateFailed' =>
            'Unable to check for updates. Please try again.',
          'about.updateAvailableTitle' =>
            ({required Object version}) => 'Version ${version} is available',
          'about.latestVersionTitle' => 'You\'re Up to Date',
          'about.latestVersionBody' =>
            'The installed version is already the latest version.',
          'about.noReleaseTitle' => 'No Update Available',
          'about.noReleaseBody' =>
            'There is no public stable release available on GitHub yet.',
          'about.currentVersion' =>
            ({required Object version}) => 'Current version: ${version}',
          'about.publishedAt' =>
            ({required Object date}) => 'Published: ${date}',
          'about.releaseNotesEmpty' =>
            'No release notes were provided for this version.',
          'about.goToUpdate' => 'View Update',
          'about.close' => 'Close',
          'about.dataLocalTitle' => 'Local Keys and Data',
          'about.dataLocalBody' =>
            'Mnemonics and private keys are encrypted and stored on this device. Safe Wallet cannot recover your mnemonic, private key, or wallet password.',
          'about.backendTitle' => 'No Proprietary Backend Required',
          'about.backendBody' =>
            'Safe Wallet does not depend on a proprietary account system or private backend. Assets, transactions, and on-chain operations are requested directly through your selected RPC nodes.',
          'about.servicesTitle' => 'External Network Services',
          'about.servicesBody' =>
            'Depending on the feature, the app may access RPC nodes, Chainlist, CoinGecko, DefiLlama, Jupiter, DexScreener, Frankfurter, and GitHub. Third-party dApps and services are governed by their own privacy policies.',
          'about.analyticsTitle' => 'No Ads or Behavioral Tracking',
          'about.analyticsBody' =>
            'This version does not include advertising, behavioral analytics, or crash-reporting SDKs. dApps, RPC nodes, and third-party data services may independently log network requests.',
          'about.privacyLocalBody' =>
            'Wallet keys, wallet accounts, and address book data are stored on this device. Sensitive key material is encrypted.',
          'about.privacyNetworkBody' =>
            'The app sends necessary requests to selected RPC nodes and public data services to retrieve balances, prices, transaction status, network configuration, and update information.',
          'about.privacyNoAnalyticsBody' =>
            'This version does not include advertising or behavioral analytics SDKs and does not upload mnemonics, private keys, or wallet passwords to a Safe Wallet server.',
          'about.privacyThirdPartyBody' =>
            'When using dApps, RPC nodes, or third-party data services, those providers may process IP addresses, wallet addresses, and request content under their own privacy policies.',
          'about.privacyChangeBody' =>
            'This notice will be updated if data handling changes in a future release.',
          'about.termsSelfCustodyBody' =>
            'Safe Wallet is a self-custody wallet. You are responsible for protecting your mnemonic, private keys, and wallet password. The developer cannot recover them.',
          'about.termsTransactionBody' =>
            'Blockchain transactions are generally irreversible. Verify the address, network, amount, and fee before submitting.',
          'about.termsRiskBody' =>
            'Digital assets and on-chain applications involve risk. Information in the app is not investment, legal, or tax advice.',
          'about.termsThirdPartyBody' =>
            'RPC nodes, dApps, tokens, and third-party services are operated by their respective providers. Safe Wallet does not control their availability or content.',
          'about.termsWarrantyBody' =>
            'The software is provided as-is. To the extent permitted by applicable law, you assume the risks of using it.',
          'errors.unknown' => 'Operation failed. Please try again later.',
          'errors.walletLocked' => 'Wallet is locked. Please unlock it first.',
          'errors.invalidMnemonic' => 'Invalid mnemonic format or checksum.',
          'errors.invalidPrivateKey' => 'Invalid private key format.',
          'errors.passwordAttemptLocked' =>
            'Too many password attempts. Please try again later.',
          'errors.walletPasswordTooShort' =>
            'Wallet password must contain at least 8 characters.',
          'errors.walletPasswordTooWeak' =>
            'This password is too common. Use a harder-to-guess password.',
          'errors.invalidRpcUrl' => 'Invalid RPC URL.',
          'errors.rpcUnavailable' =>
            'RPC node is unavailable. Check the address or network.',
          'errors.rpcMissingCredential' =>
            'RPC credentials are missing. Reconfigure the node.',
          'errors.rpcInvalidCredential' =>
            'RPC credentials are invalid or expired.',
          'errors.rpcAccessDenied' =>
            'RPC access was denied. Check node permissions, IP restrictions, or VPN settings.',
          'errors.rpcRateLimited' =>
            'RPC requests are rate limited or the quota is exhausted.',
          'errors.rpcChainMismatch' =>
            'RPC node does not match the current chain.',
          'errors.balanceQueryFailed' =>
            'Balance query failed. Please check the RPC node.',
          'errors.feeEstimateFailed' =>
            'Fee estimation failed. The transaction cannot be sent yet.',
          'errors.transactionBroadcastFailed' =>
            'Transaction submission failed. Please try again later.',
          'errors.suiInsufficientBalance' => 'Insufficient Sui Coin balance.',
          'errors.suiInsufficientGas' => 'Insufficient SUI balance for gas.',
          'errors.suiObjectConflict' =>
            'A Sui Coin object is in use or stale. Refresh and try again.',
          'errors.suiSimulationFailed' =>
            'Sui transaction simulation failed. Refresh balances and try again.',
          'errors.dappRejected' => 'The dApp request was rejected.',
          'errors.dappUnsupportedMethod' =>
            'This dApp method is not supported yet.',
          'errors.dappUnauthorized' => 'This dApp is not authorized.',
          'errors.unsupportedChain' => 'This chain is not supported yet.',
          'errors.securityCheckFailed' =>
            'Security check failed. Please try again.',
          _ => null,
        };
  }
}
