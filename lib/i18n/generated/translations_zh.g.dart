///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import

part of 'translations.g.dart';

// Path: <root>
typedef TranslationsZh = Translations; // ignore: unused_element

class Translations with BaseTranslations<AppLocale, Translations> {
  /// Returns the current translations of the given [context].
  ///
  /// Usage:
  /// final t = Translations.of(context);
  static Translations of(BuildContext context) =>
      InheritedLocaleData.of<AppLocale, Translations>(context).translations;

  /// You can call this constructor and build your own translation instance of this locale.
  /// Constructing via the enum [AppLocale.build] is preferred.
  Translations({
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
             locale: AppLocale.zh,
             overrides: overrides ?? {},
             cardinalResolver: cardinalResolver,
             ordinalResolver: ordinalResolver,
           ) {
    $meta.setFlatMapFunction(_flatMapFunction);
  }

  /// Metadata for the translations of <zh>.
  @override
  final TranslationMetadata<AppLocale, Translations> $meta;

  /// Access flat map
  dynamic operator [](String key) => $meta.getTranslation(key);

  late final Translations _root = this; // ignore: unused_field

  Translations $copyWith({
    TranslationMetadata<AppLocale, Translations>? meta,
  }) => Translations(meta: meta ?? this.$meta);

  // Translations
  late final Translations$app$zh app = Translations$app$zh.internal(_root);
  late final Translations$tabs$zh tabs = Translations$tabs$zh.internal(_root);
  late final Translations$actions$zh actions = Translations$actions$zh.internal(
    _root,
  );
  late final Translations$onboarding$zh onboarding =
      Translations$onboarding$zh.internal(_root);
  late final Translations$home$zh home = Translations$home$zh.internal(_root);
  late final Translations$browser$zh browser = Translations$browser$zh.internal(
    _root,
  );
  late final Translations$dapp$zh dapp = Translations$dapp$zh.internal(_root);
  late final Translations$chains$zh chains = Translations$chains$zh.internal(
    _root,
  );
  late final Translations$nodes$zh nodes = Translations$nodes$zh.internal(
    _root,
  );
  late final Translations$tokens$zh tokens = Translations$tokens$zh.internal(
    _root,
  );
  late final Translations$assets$zh assets = Translations$assets$zh.internal(
    _root,
  );
  late final Translations$transactions$zh transactions =
      Translations$transactions$zh.internal(_root);
  late final Translations$transfer$zh transfer =
      Translations$transfer$zh.internal(_root);
  late final Translations$addressBook$zh addressBook =
      Translations$addressBook$zh.internal(_root);
  late final Translations$wallet$zh wallet = Translations$wallet$zh.internal(
    _root,
  );
  late final Translations$settings$zh settings =
      Translations$settings$zh.internal(_root);
  late final Translations$tronStaking$zh tronStaking =
      Translations$tronStaking$zh.internal(_root);
  late final Translations$advanced$zh advanced =
      Translations$advanced$zh.internal(_root);
  late final Translations$about$zh about = Translations$about$zh.internal(
    _root,
  );
  late final Translations$errors$zh errors = Translations$errors$zh.internal(
    _root,
  );
}

// Path: app
class Translations$app$zh {
  Translations$app$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: 'Safe Wallet'
  String get name => 'Safe Wallet';
}

// Path: tabs
class Translations$tabs$zh {
  Translations$tabs$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '首页'
  String get home => '首页';

  /// zh: '浏览器'
  String get browser => '浏览器';

  /// zh: '设置'
  String get settings => '设置';
}

// Path: actions
class Translations$actions$zh {
  Translations$actions$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '接收'
  String get receive => '接收';

  /// zh: '转账'
  String get send => '转账';

  /// zh: '扫码'
  String get scan => '扫码';

  /// zh: '确认'
  String get confirm => '确认';

  /// zh: '提交'
  String get submit => '提交';

  /// zh: '取消'
  String get cancel => '取消';

  /// zh: '继续'
  String get kContinue => '继续';

  /// zh: '完成'
  String get done => '完成';

  /// zh: '返回'
  String get back => '返回';

  /// zh: '关闭'
  String get close => '关闭';

  /// zh: '粘贴'
  String get paste => '粘贴';

  /// zh: '再次返回即可退出 App'
  String get exitAppHint => '再次返回即可退出 App';

  /// zh: '显示密码'
  String get showPassword => '显示密码';

  /// zh: '隐藏密码'
  String get hidePassword => '隐藏密码';
}

// Path: onboarding
class Translations$onboarding$zh {
  Translations$onboarding$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '安全地开始使用钱包'
  String get entryTitle => '安全地开始使用钱包';

  /// zh: '创建新钱包或导入已有钱包，私钥和助记词只保存在本机加密存储中。'
  String get entrySubtitle => '创建新钱包或导入已有钱包，私钥和助记词只保存在本机加密存储中。';

  /// zh: '创建钱包'
  String get createWallet => '创建钱包';

  /// zh: '导入钱包'
  String get importWallet => '导入钱包';

  /// zh: '创建新钱包'
  String get createTitle => '创建新钱包';

  /// zh: '应用会生成一组新的助记词，并派生默认 EVM、Bitcoin、Tron、Solana 和 Sui 地址。'
  String get createBody =>
      '应用会生成一组新的助记词，并派生默认 EVM、Bitcoin、Tron、Solana 和 Sui 地址。';

  /// zh: '助记词风险说明'
  String get riskTitle => '助记词风险说明';

  /// zh: '助记词丢失后无法找回钱包'
  String get riskLoss => '助记词丢失后无法找回钱包';

  /// zh: '请自行保存助记词。任何人拿到助记词都可以控制你的资产，应用无法替你恢复或冻结钱包。'
  String get riskResponsibility => '请自行保存助记词。任何人拿到助记词都可以控制你的资产，应用无法替你恢复或冻结钱包。';

  /// zh: 'MVP 不要求备份校验，但你仍需在进入钱包前理解风险。'
  String get riskNoBackupGate => 'MVP 不要求备份校验，但你仍需在进入钱包前理解风险。';

  /// zh: '我已了解风险'
  String get riskAccepted => '我已了解风险';

  /// zh: '导入钱包'
  String get importTitle => '导入钱包';

  /// zh: '支持通过助记词、EVM 私钥、Bitcoin 私钥、Tron 私钥、Solana 私钥或 Sui suiprivkey 导入。导入材料会在设置密码后加密保存。'
  String get importBody =>
      '支持通过助记词、EVM 私钥、Bitcoin 私钥、Tron 私钥、Solana 私钥或 Sui suiprivkey 导入。导入材料会在设置密码后加密保存。';

  /// zh: '助记词'
  String get importMnemonic => '助记词';

  /// zh: '私钥'
  String get importPrivateKey => '私钥';

  /// zh: '助记词钱包'
  String get importMnemonicWallet => '助记词钱包';

  /// zh: '私钥钱包'
  String get importPrivateKeyWallet => '私钥钱包';

  /// zh: '多链钱包'
  String get importMnemonicWalletDescription => '多链钱包';

  /// zh: 'EVM、Bitcoin、Tron、Solana 或 Sui 钱包'
  String get importPrivateKeyWalletDescription =>
      'EVM、Bitcoin、Tron、Solana 或 Sui 钱包';

  /// zh: '选择导入类型'
  String get selectImportType => '选择导入类型';

  /// zh: '选择私钥网络'
  String get selectPrivateKeyChain => '选择私钥网络';

  /// zh: 'EVM'
  String get importEvm => 'EVM';

  /// zh: 'Bitcoin'
  String get importBitcoin => 'Bitcoin';

  /// zh: 'Tron'
  String get importTron => 'Tron';

  /// zh: 'Solana'
  String get importSolana => 'Solana';

  /// zh: 'Sui'
  String get importSui => 'Sui';

  /// zh: '请输入助记词，12或24个单词，用空格分隔'
  String get mnemonicHint => '请输入助记词，12或24个单词，用空格分隔';

  /// zh: '输入单词'
  String get mnemonicWordHint => '输入单词';

  /// zh: '12 个英文单词'
  String get mnemonicWordCount12 => '12 个英文单词';

  /// zh: '24 个英文单词'
  String get mnemonicWordCount24 => '24 个英文单词';

  /// zh: '如何获取？'
  String get mnemonicHelp => '如何获取？';

  /// zh: '输入助记词以导入现有钱包'
  String get mnemonicImportHint => '输入助记词以导入现有钱包';

  /// zh: '支持 EVM hex、Bitcoin WIF/hex、Solana 私钥或 Sui suiprivkey'
  String get privateKeyHint =>
      '支持 EVM hex、Bitcoin WIF/hex、Solana 私钥或 Sui suiprivkey';

  /// zh: '设置钱包密码'
  String get setPasswordTitle => '设置钱包密码';

  /// zh: '该密码用于本机解锁和加密钱包数据。忘记密码后需要重新导入助记词或私钥。'
  String get setPasswordBody => '该密码用于本机解锁和加密钱包数据。忘记密码后需要重新导入助记词或私钥。';

  /// zh: '钱包密码'
  String get passwordLabel => '钱包密码';

  /// zh: '确认密码'
  String get confirmPasswordLabel => '确认密码';

  /// zh: '请输入钱包密码'
  String get passwordRequired => '请输入钱包密码';

  /// zh: '两次输入的密码不一致'
  String get passwordMismatch => '两次输入的密码不一致';

  /// zh: '请输入导入内容'
  String get importMaterialRequired => '请输入导入内容';

  /// zh: '正在读取钱包'
  String get loadingWallet => '正在读取钱包';

  /// zh: '正在创建钱包'
  String get creatingWallet => '正在创建钱包';

  /// zh: '正在导入钱包'
  String get importingWallet => '正在导入钱包';
}

// Path: home
class Translations$home$zh {
  Translations$home$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '我的钱包'
  String get defaultWalletName => '我的钱包';

  /// zh: '总资产估值'
  String get totalValue => '总资产估值';

  /// zh: '隐藏金额'
  String get hideAmounts => '隐藏金额';

  /// zh: '显示金额'
  String get showAmounts => '显示金额';

  /// zh: '交易记录'
  String get recentTransactions => '交易记录';

  /// zh: '查看全部'
  String get viewAll => '查看全部';

  /// zh: '资产列表'
  String get assetList => '资产列表';

  /// zh: '管理代币'
  String get manageTokens => '管理代币';

  /// zh: '刷新资产'
  String get refreshAssets => '刷新资产';

  /// zh: '暂无交易'
  String get emptyTransactions => '暂无交易';

  /// zh: '尚未创建钱包'
  String get noWallet => '尚未创建钱包';

  /// zh: '钱包已锁定'
  String get walletLocked => '钱包已锁定';

  /// zh: '资产加载中'
  String get loadingAssets => '资产加载中';

  /// zh: '暂无资产'
  String get emptyAssets => '暂无资产';

  /// zh: '资产加载失败'
  String get assetLoadError => '资产加载失败';
}

// Path: browser
class Translations$browser$zh {
  Translations$browser$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '常用 dApp'
  String get commonDapps => '常用 dApp';

  /// zh: '搜索 dApp 或输入 URL'
  String get urlHint => '搜索 dApp 或输入 URL';

  /// zh: '请输入有效网址'
  String get invalidUrl => '请输入有效网址';

  /// zh: '无法打开 dApp，请检查网址或网络后重试'
  String get loadFailed => '无法打开 dApp，请检查网址或网络后重试';

  /// zh: '确认打开网站'
  String get confirmExternalTitle => '确认打开网站';

  /// zh: '请确认即将打开的网站域名，避免误入伪装站点。'
  String get confirmExternalBody => '请确认即将打开的网站域名，避免误入伪装站点。';

  /// zh: '打开'
  String get openExternal => '打开';

  /// zh: 'Swap'
  String get swap => 'Swap';

  /// zh: 'Predictions'
  String get predictions => 'Predictions';

  /// zh: 'Staking'
  String get staking => 'Staking';

  /// zh: 'Bridge'
  String get bridge => 'Bridge';

  /// zh: '聚合器'
  String get swapAggregator => '聚合器';

  /// zh: 'DEX'
  String get swapDex => 'DEX';

  /// zh: 'Meme'
  String get swapMeme => 'Meme';

  /// zh: '跨链'
  String get swapCrossChain => '跨链';

  /// zh: '高风险'
  String get riskHigh => '高风险';

  /// zh: '全部'
  String get all => '全部';

  /// zh: '网络'
  String get networkFilter => '网络';

  /// zh: '类型'
  String get typeFilter => '类型';

  /// zh: '全部网络'
  String get allNetworks => '全部网络';

  /// zh: '全部类型'
  String get allTypes => '全部类型';

  /// zh: '选择网络'
  String get selectNetwork => '选择网络';

  /// zh: '选择类型'
  String get selectType => '选择类型';

  /// zh: 'DeFi'
  String get defi => 'DeFi';

  /// zh: 'NFT'
  String get nft => 'NFT';

  /// zh: '工具'
  String get tools => '工具';

  /// zh: '收藏'
  String get favorites => '收藏';

  /// zh: '最近'
  String get recent => '最近';

  /// zh: '暂无收藏'
  String get emptyFavorites => '暂无收藏';

  /// zh: '暂无访问记录'
  String get emptyRecent => '暂无访问记录';

  /// zh: '未找到匹配的 dApp'
  String get noResults => '未找到匹配的 dApp';

  /// zh: '收藏'
  String get favorite => '收藏';

  /// zh: '取消收藏'
  String get unfavorite => '取消收藏';

  /// zh: '前进'
  String get forward => '前进';

  /// zh: '刷新'
  String get refresh => '刷新';
}

// Path: dapp
class Translations$dapp$zh {
  Translations$dapp$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '连接 dApp'
  String get authorizationTitle => '连接 dApp';

  /// zh: '授权后，该站点可以读取当前账户地址并请求签名或交易确认。'
  String get authorizationBody => '授权后，该站点可以读取当前账户地址并请求签名或交易确认。';

  /// zh: '记住该站点 30 天'
  String get rememberAuthorization => '记住该站点 30 天';

  /// zh: '确认签名'
  String get signatureTitle => '确认签名';

  /// zh: '确认交易'
  String get transactionTitle => '确认交易';

  /// zh: '切换网络'
  String get chainSwitchTitle => '切换网络';

  /// zh: '该站点请求切换当前 EVM 网络，请确认后继续。'
  String get chainSwitchBody => '该站点请求切换当前 EVM 网络，请确认后继续。';

  /// zh: '域名'
  String get domain => '域名';

  /// zh: '网络'
  String get chain => '网络';

  /// zh: '目标网络'
  String get requestedChain => '目标网络';

  /// zh: '账户'
  String get account => '账户';

  /// zh: '发送方'
  String get from => '发送方';

  /// zh: '接收方'
  String get to => '接收方';

  /// zh: '金额'
  String get value => '金额';

  /// zh: '合约'
  String get contract => '合约';

  /// zh: '预估手续费'
  String get feeEstimate => '预估手续费';

  /// zh: '解析信息'
  String get decodedInfo => '解析信息';

  /// zh: '原始交易数据'
  String get rawTransactionData => '原始交易数据';

  /// zh: '签名内容'
  String get message => '签名内容';

  /// zh: '批准'
  String get approve => '批准';

  /// zh: '拒绝'
  String get reject => '拒绝';

  /// zh: '签名前请确认内容来自可信站点。签名可能代表登录、授权或其他链下声明。'
  String get signatureRiskWarning => '签名前请确认内容来自可信站点。签名可能代表登录、授权或其他链下声明。';

  /// zh: '该签名内容不可读，请仅在完全信任该站点时继续。'
  String get unreadableSignatureWarning => '该签名内容不可读，请仅在完全信任该站点时继续。';

  /// zh: '该交易包含无法解析的合约调用，请仔细核对站点和合约地址。'
  String get unparsedTransactionWarning => '该交易包含无法解析的合约调用，请仔细核对站点和合约地址。';

  /// zh: '交易仿真失败：$reason'
  String simulationFailedWarning({required Object reason}) =>
      '交易仿真失败：${reason}';

  /// zh: 'Solana dApp 测试'
  String get solanaTestTitle => 'Solana dApp 测试';

  /// zh: '该内部页面用于验证 Solana dApp 接口边界，外部完整适配将在后续版本提供。'
  String get solanaTestBody => '该内部页面用于验证 Solana dApp 接口边界，外部完整适配将在后续版本提供。';

  /// zh: 'Solana dApp 接口预留'
  String get solanaBoundaryReserved => 'Solana dApp 接口预留';

  /// zh: '连接请求边界已预留'
  String get solanaConnectCheck => '连接请求边界已预留';

  /// zh: '消息签名边界已预留'
  String get solanaSignCheck => '消息签名边界已预留';

  /// zh: '交易请求边界已预留'
  String get solanaTransactionCheck => '交易请求边界已预留';

  /// zh: '当前未选择 Solana 网络'
  String get solanaNonSolanaChain => '当前未选择 Solana 网络';

  /// zh: '暂无 Solana 地址'
  String get solanaUnavailable => '暂无 Solana 地址';
}

// Path: chains
class Translations$chains$zh {
  Translations$chains$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '网络'
  String get network => '网络';

  /// zh: '选择网络'
  String get selectorTitle => '选择网络';

  /// zh: '添加网络'
  String get addNetwork => '添加网络';

  /// zh: '添加自定义'
  String get addCustom => '添加自定义';

  /// zh: '新增 EVM 网络'
  String get addCustomEvm => '新增 EVM 网络';

  /// zh: '搜索网络'
  String get searchNetworkHint => '搜索网络';

  /// zh: '暂无可添加网络'
  String get emptySearch => '暂无可添加网络';

  /// zh: '移除网络'
  String get removeNetwork => '移除网络';

  /// zh: '移除网络'
  String get removeNetworkTitle => '移除网络';

  /// zh: '移除后该网络将不再显示，相关自定义配置不会继续使用。'
  String get removeNetworkMessage => '移除后该网络将不再显示，相关自定义配置不会继续使用。';

  /// zh: '确认移除'
  String get confirmRemoveNetwork => '确认移除';

  /// zh: '网络名称'
  String get nameLabel => '网络名称';

  /// zh: 'Chain ID'
  String get chainIdLabel => 'Chain ID';

  /// zh: 'RPC URL'
  String get rpcUrlLabel => 'RPC URL';

  /// zh: '原生币符号'
  String get symbolLabel => '原生币符号';

  /// zh: '区块浏览器 URL'
  String get blockExplorerLabel => '区块浏览器 URL';

  /// zh: '测试网'
  String get testnetLabel => '测试网';

  /// zh: '请输入网络名称'
  String get nameRequired => '请输入网络名称';

  /// zh: '请输入 Chain ID'
  String get chainIdRequired => '请输入 Chain ID';

  /// zh: '请输入有效 Chain ID'
  String get invalidChainId => '请输入有效 Chain ID';

  /// zh: '请输入 RPC URL'
  String get rpcUrlRequired => '请输入 RPC URL';

  /// zh: '请输入有效 RPC URL'
  String get invalidRpcUrl => '请输入有效 RPC URL';

  /// zh: '请输入原生币符号'
  String get symbolRequired => '请输入原生币符号';

  /// zh: '请输入有效区块浏览器 URL'
  String get invalidBlockExplorerUrl => '请输入有效区块浏览器 URL';

  /// zh: '该 Chain ID 已存在'
  String get duplicateChainId => '该 Chain ID 已存在';

  /// zh: '当前'
  String get current => '当前';

  /// zh: '主网'
  String get mainnet => '主网';

  /// zh: '测试网'
  String get testnet => '测试网';

  /// zh: '正在读取网络'
  String get loading => '正在读取网络';

  /// zh: '网络列表读取失败'
  String get loadFailed => '网络列表读取失败';
}

// Path: nodes
class Translations$nodes$zh {
  Translations$nodes$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: 'RPC 节点'
  String get managementTitle => 'RPC 节点';

  /// zh: '新增节点'
  String get addNode => '新增节点';

  /// zh: '编辑节点'
  String get editNode => '编辑节点';

  /// zh: '默认'
  String get defaultNode => '默认';

  /// zh: 'Chainlist'
  String get chainlistNode => 'Chainlist';

  /// zh: '自定义'
  String get customNode => '自定义';

  /// zh: '已选'
  String get selected => '已选';

  /// zh: '选择'
  String get select => '选择';

  /// zh: '测试'
  String get test => '测试';

  /// zh: '删除'
  String get delete => '删除';

  /// zh: '删除节点'
  String get deleteTitle => '删除节点';

  /// zh: '删除后该自定义 RPC 节点将不再可用。'
  String get deleteMessage => '删除后该自定义 RPC 节点将不再可用。';

  /// zh: '确认删除'
  String get confirmDelete => '确认删除';

  /// zh: '保存'
  String get save => '保存';

  /// zh: '节点名称'
  String get nameLabel => '节点名称';

  /// zh: 'URL'
  String get urlLabel => 'URL';

  /// zh: '服务商'
  String get providerLabel => '服务商';

  /// zh: '自定义'
  String get customProvider => '自定义';

  /// zh: 'API Key'
  String get apiKeyLabel => 'API Key';

  /// zh: '鉴权方式'
  String get authModeLabel => '鉴权方式';

  /// zh: '无需参数'
  String get authNone => '无需参数';

  /// zh: 'Query 参数'
  String get authQuery => 'Query 参数';

  /// zh: 'Path 参数'
  String get authPath => 'Path 参数';

  /// zh: 'HTTP Header'
  String get authHeader => 'HTTP Header';

  /// zh: '凭据参数名'
  String get credentialParameterLabel => '凭据参数名';

  /// zh: '请输入节点凭据'
  String get credentialRequired => '请输入节点凭据';

  /// zh: '留空则保留现有凭据'
  String get credentialKeepHint => '留空则保留现有凭据';

  /// zh: '留空则保留现有 URL'
  String get urlKeepHint => '留空则保留现有 URL';

  /// zh: '该服务商暂不支持当前网络'
  String get providerUnsupported => '该服务商暂不支持当前网络';

  /// zh: '备注'
  String get noteLabel => '备注';

  /// zh: '请输入节点名称'
  String get nameRequired => '请输入节点名称';

  /// zh: '请输入 URL'
  String get urlRequired => '请输入 URL';

  /// zh: '未测试'
  String get statusUntested => '未测试';

  /// zh: '测试中'
  String get statusTesting => '测试中';

  /// zh: '可用'
  String get statusAvailable => '可用';

  /// zh: '不可用'
  String get statusUnavailable => '不可用';

  /// zh: '区块'
  String get blockHeightPrefix => '区块';

  /// zh: 'ms'
  String get latencyMsSuffix => 'ms';

  /// zh: '无追踪'
  String get trackingNone => '无追踪';

  /// zh: '有追踪'
  String get trackingYes => '有追踪';

  /// zh: '追踪未知'
  String get trackingUnknown => '追踪未知';

  /// zh: '节点列表读取失败'
  String get loadFailed => '节点列表读取失败';

  /// zh: '暂无节点'
  String get empty => '暂无节点';
}

// Path: tokens
class Translations$tokens$zh {
  Translations$tokens$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '代币管理'
  String get managementTitle => '代币管理';

  /// zh: '添加代币'
  String get addToken => '添加代币';

  /// zh: '添加自定义'
  String get addCustomToken => '添加自定义';

  /// zh: '搜索代币名称、符号或合约地址'
  String get searchTokenHint => '搜索代币名称、符号或合约地址';

  /// zh: '未找到匹配的代币'
  String get emptySearch => '未找到匹配的代币';

  /// zh: '发现代币'
  String get runDiscovery => '发现代币';

  /// zh: '发现中'
  String get discovering => '发现中';

  /// zh: '已发现 $count 个代币'
  String discoverySuccess({required Object count}) => '已发现 ${count} 个代币';

  /// zh: '未发现持有的代币'
  String get discoveryEmpty => '未发现持有的代币';

  /// zh: '代币发现失败，请检查网络节点'
  String get discoveryFailed => '代币发现失败，请检查网络节点';

  /// zh: '合约地址'
  String get contractAddressLabel => '合约地址';

  /// zh: '代币符号'
  String get symbolLabel => '代币符号';

  /// zh: '代币名称'
  String get nameLabel => '代币名称';

  /// zh: '精度'
  String get decimalsLabel => '精度';

  /// zh: '请输入合约地址'
  String get contractAddressRequired => '请输入合约地址';

  /// zh: '请输入有效合约地址'
  String get invalidContractAddress => '请输入有效合约地址';

  /// zh: '请输入代币名称和符号'
  String get metadataRequired => '请输入代币名称和符号';

  /// zh: '请输入有效精度'
  String get invalidDecimals => '请输入有效精度';

  /// zh: '隐藏'
  String get hide => '隐藏';

  /// zh: '取消隐藏'
  String get unhide => '取消隐藏';

  /// zh: '内置'
  String get builtIn => '内置';

  /// zh: '手动'
  String get userAdded => '手动';

  /// zh: '发现'
  String get discovered => '发现';

  /// zh: '已隐藏'
  String get hidden => '已隐藏';

  /// zh: '暂无代币'
  String get empty => '暂无代币';

  /// zh: '代币列表读取失败'
  String get loadFailed => '代币列表读取失败';
}

// Path: assets
class Translations$assets$zh {
  Translations$assets$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '资产详情'
  String get detailTitle => '资产详情';

  /// zh: '网络'
  String get network => '网络';

  /// zh: '余额'
  String get balance => '余额';

  /// zh: '估值'
  String get fiatValue => '估值';

  /// zh: '合约地址'
  String get contractAddress => '合约地址';

  /// zh: '原生资产'
  String get nativeAsset => '原生资产';

  /// zh: '当前价格'
  String get currentPrice => '当前价格';

  /// zh: '24h 涨跌'
  String get change24h => '24h 涨跌';

  /// zh: '市场概览'
  String get marketOverview => '市场概览';

  /// zh: '24h 成交额'
  String get volume24h => '24h 成交额';

  /// zh: '流动性'
  String get liquidity => '流动性';

  /// zh: '市值'
  String get marketCap => '市值';

  /// zh: 'FDV'
  String get fdv => 'FDV';

  /// zh: '24h 买入 / 卖出'
  String get transactions24h => '24h 买入 / 卖出';

  /// zh: '主要交易对'
  String get primaryPair => '主要交易对';

  /// zh: '在 DexScreener 查看'
  String get viewOnDexScreener => '在 DexScreener 查看';

  /// zh: '暂无市场数据'
  String get marketDataUnavailable => '暂无市场数据';

  /// zh: '数据来源：DexScreener'
  String get marketDataSource => '数据来源：DexScreener';

  /// zh: '更新于'
  String get updatedAt => '更新于';

  /// zh: '交易池创建于'
  String get pairCreatedAt => '交易池创建于';

  /// zh: '该交易池流动性较低，市场价格可能出现较大波动。'
  String get lowLiquidityWarning => '该交易池流动性较低，市场价格可能出现较大波动。';

  /// zh: '钱包估值价格与 DEX 市场价格存在明显偏差。'
  String get priceDivergenceWarning => '钱包估值价格与 DEX 市场价格存在明显偏差。';
}

// Path: transactions
class Translations$transactions$zh {
  Translations$transactions$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '交易历史'
  String get historyTitle => '交易历史';

  /// zh: '暂无交易记录'
  String get empty => '暂无交易记录';

  /// zh: '交易记录读取失败'
  String get loadFailed => '交易记录读取失败';

  /// zh: '提交中'
  String get submitting => '提交中';

  /// zh: '已提交'
  String get submitted => '已提交';

  /// zh: '成功'
  String get success => '成功';

  /// zh: '失败'
  String get failed => '失败';

  /// zh: '接收'
  String get incoming => '接收';

  /// zh: '转账'
  String get outgoing => '转账';

  /// zh: '封装原生币'
  String get operationWrap => '封装原生币';

  /// zh: '解封装原生币'
  String get operationUnwrap => '解封装原生币';

  /// zh: '质押 TRX'
  String get operationStake => '质押 TRX';

  /// zh: '解押 TRX'
  String get operationUnstake => '解押 TRX';

  /// zh: '提取已解押 TRX'
  String get operationWithdrawUnfreeze => '提取已解押 TRX';

  /// zh: '取消全部解押'
  String get operationCancelUnfreeze => '取消全部解押';

  /// zh: '委托 TRON 资源'
  String get operationDelegateResource => '委托 TRON 资源';

  /// zh: '取消委托 TRON 资源'
  String get operationUndelegateResource => '取消委托 TRON 资源';

  /// zh: '超级代表投票'
  String get operationVote => '超级代表投票';

  /// zh: '领取投票奖励'
  String get operationClaimReward => '领取投票奖励';

  /// zh: '在区块浏览器中查看更多'
  String get viewMoreOnExplorer => '在区块浏览器中查看更多';
}

// Path: transfer
class Translations$transfer$zh {
  Translations$transfer$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '转账'
  String get title => '转账';

  /// zh: '确认转账'
  String get confirmTitle => '确认转账';

  /// zh: '转账结果'
  String get resultTitle => '转账结果';

  /// zh: '复制交易哈希'
  String get copyTransactionHash => '复制交易哈希';

  /// zh: '区块浏览器查看'
  String get viewTransactionExplorer => '区块浏览器查看';

  /// zh: '交易哈希已复制'
  String get transactionHashCopied => '交易哈希已复制';

  /// zh: '选择资产'
  String get selectedAsset => '选择资产';

  /// zh: '隐藏 0 余额资产'
  String get hideZeroBalances => '隐藏 0 余额资产';

  /// zh: '收款地址'
  String get recipientLabel => '收款地址';

  /// zh: '金额'
  String get amountLabel => '金额';

  /// zh: '备注 / Tag'
  String get memoLabel => '备注 / Tag';

  /// zh: '可选。仅在收款方要求时填写。'
  String get memoOptionalHelper => '可选。仅在收款方要求时填写。';

  /// zh: '备注 / Tag'
  String get memoRequiredLabel => '备注 / Tag';

  /// zh: '该资产转账必须填写。'
  String get memoRequiredHelper => '该资产转账必须填写。';

  /// zh: '选择联系人'
  String get selectContact => '选择联系人';

  /// zh: '最大'
  String get max => '最大';

  /// zh: '下一步'
  String get next => '下一步';

  /// zh: '余额'
  String get balance => '余额';

  /// zh: '暂无可转账资产'
  String get noAssets => '暂无可转账资产';

  /// zh: '钱包已锁定'
  String get walletLocked => '钱包已锁定';

  /// zh: '收款地址格式无效'
  String get invalidAddress => '收款地址格式无效';

  /// zh: '请输入大于 0 的金额'
  String get invalidAmount => '请输入大于 0 的金额';

  /// zh: '余额不足'
  String get insufficientBalance => '余额不足';

  /// zh: '资产余额不可用'
  String get unavailableBalance => '资产余额不可用';

  /// zh: '请输入必填的 Memo / Tag'
  String get memoRequired => '请输入必填的 Memo / Tag';

  /// zh: '手续费估算失败，暂不能继续'
  String get feeFailed => '手续费估算失败，暂不能继续';

  /// zh: '网络'
  String get chain => '网络';

  /// zh: '发送方'
  String get from => '发送方';

  /// zh: '接收方'
  String get to => '接收方';

  /// zh: '资产'
  String get token => '资产';

  /// zh: '金额'
  String get amount => '金额';

  /// zh: '手续费'
  String get fee => '手续费';

  /// zh: '预计手续费'
  String get estimatedFee => '预计手续费';

  /// zh: '最高手续费'
  String get maximumFee => '最高手续费';

  /// zh: '手续费设置'
  String get feeSettings => '手续费设置';

  /// zh: '省钱'
  String get feeEconomy => '省钱';

  /// zh: '费用较低，确认可能较慢'
  String get feeEconomyHint => '费用较低，确认可能较慢';

  /// zh: '标准'
  String get feeStandard => '标准';

  /// zh: '费用和确认速度均衡'
  String get feeStandardHint => '费用和确认速度均衡';

  /// zh: '快速'
  String get feeFast => '快速';

  /// zh: '费用较高，优先确认'
  String get feeFastHint => '费用较高，优先确认';

  /// zh: '自定义'
  String get feeCustom => '自定义';

  /// zh: '手动设置链上手续费参数'
  String get feeCustomHint => '手动设置链上手续费参数';

  /// zh: '最大费率 (Gwei)'
  String get maxFeeGwei => '最大费率 (Gwei)';

  /// zh: '优先费率 (Gwei)'
  String get priorityFeeGwei => '优先费率 (Gwei)';

  /// zh: 'Gas Price (Gwei)'
  String get gasPriceGwei => 'Gas Price (Gwei)';

  /// zh: '总优先费 (SOL)'
  String get priorityFeeSol => '总优先费 (SOL)';

  /// zh: '费率 (sat/vB)'
  String get bitcoinFeeRate => '费率 (sat/vB)';

  /// zh: '预计确认'
  String get estimatedConfirmation => '预计确认';

  /// zh: '约'
  String get approximately => '约';

  /// zh: '个区块'
  String get blocks => '个区块';

  /// zh: '最大可燃烧 TRX'
  String get tronFeeLimit => '最大可燃烧 TRX';

  /// zh: '应用手续费'
  String get applyFee => '应用手续费';

  /// zh: '请输入有效的手续费'
  String get invalidFee => '请输入有效的手续费';

  /// zh: '最大费率不能低于优先费率'
  String get maxFeeBelowPriority => '最大费率不能低于优先费率';

  /// zh: '最大可燃烧 TRX 不能低于预计手续费'
  String get feeLimitBelowEstimate => '最大可燃烧 TRX 不能低于预计手续费';

  /// zh: '当前费率低于网络基础费用，交易可能长时间无法确认'
  String get feeTooLow => '当前费率低于网络基础费用，交易可能长时间无法确认';

  /// zh: '当前手续费明显高于网络建议值，请确认后继续'
  String get feeVeryHigh => '当前手续费明显高于网络建议值，请确认后继续';

  /// zh: '手续费模型'
  String get feeModel => '手续费模型';

  /// zh: 'EIP-1559'
  String get feeModelEip1559 => 'EIP-1559';

  /// zh: 'Legacy Gas Price'
  String get feeModelLegacy => 'Legacy Gas Price';

  /// zh: 'Bitcoin 手续费'
  String get feeModelBitcoin => 'Bitcoin 手续费';

  /// zh: 'Tron 手续费'
  String get feeModelTron => 'Tron 手续费';

  /// zh: 'Solana Fee'
  String get feeModelSolana => 'Solana Fee';

  /// zh: 'Sui Gas 费'
  String get feeModelSui => 'Sui Gas 费';

  /// zh: '最大 Gas 费率'
  String get maxFeePerGas => '最大 Gas 费率';

  /// zh: '优先费率'
  String get maxPriorityFeePerGas => '优先费率';

  /// zh: 'Gas Price'
  String get gasPrice => 'Gas Price';

  /// zh: '总扣款'
  String get totalDeduction => '总扣款';

  /// zh: '这是一个从未转账过的新地址，请核对完整地址和收款网络。'
  String get newRecipientWarning => '这是一个从未转账过的新地址，请核对完整地址和收款网络。';

  /// zh: '该地址与历史收款地址高度相似但并不相同，可能是地址投毒。相似历史地址：$address'
  String lookalikeRecipientWarning({required Object address}) =>
      '该地址与历史收款地址高度相似但并不相同，可能是地址投毒。相似历史地址：${address}';

  /// zh: '合约地址'
  String get contractAddress => '合约地址';

  /// zh: '风险提示'
  String get riskWarnings => '风险提示';

  /// zh: '当前网络使用 Legacy 手续费模型，请确认手续费后再签名。'
  String get riskLegacy => '当前网络使用 Legacy 手续费模型，请确认手续费后再签名。';

  /// zh: '这是合约代币转账，请确认合约地址和收款地址。'
  String get riskErc20 => '这是合约代币转账，请确认合约地址和收款地址。';

  /// zh: '扫码'
  String get scanTitle => '扫码';

  /// zh: '扫描钱包地址二维码，识别后会填入转账收款地址。'
  String get scanInstruction => '扫描钱包地址二维码，识别后会填入转账收款地址。';

  /// zh: '二维码内容不是有效地址'
  String get scanInvalid => '二维码内容不是有效地址';

  /// zh: '地址已识别'
  String get scanSuccess => '地址已识别';

  /// zh: '需要相机权限才能扫码'
  String get scanCameraPermissionDenied => '需要相机权限才能扫码';

  /// zh: '当前设备不支持扫码'
  String get scanCameraUnsupported => '当前设备不支持扫码';

  /// zh: '相机启动失败，请稍后重试'
  String get scanCameraError => '相机启动失败，请稍后重试';
}

// Path: addressBook
class Translations$addressBook$zh {
  Translations$addressBook$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '地址簿'
  String get managementTitle => '地址簿';

  /// zh: '新增联系人'
  String get addContact => '新增联系人';

  /// zh: '编辑联系人'
  String get editContact => '编辑联系人';

  /// zh: '删除'
  String get delete => '删除';

  /// zh: '保存'
  String get save => '保存';

  /// zh: '联系人名称'
  String get nameLabel => '联系人名称';

  /// zh: '钱包地址'
  String get addressLabel => '钱包地址';

  /// zh: '备注'
  String get noteLabel => '备注';

  /// zh: '链类型'
  String get chainTypeLabel => '链类型';

  /// zh: 'EVM'
  String get evm => 'EVM';

  /// zh: 'Bitcoin'
  String get bitcoin => 'Bitcoin';

  /// zh: 'Tron'
  String get tron => 'Tron';

  /// zh: 'Solana'
  String get solana => 'Solana';

  /// zh: 'Sui'
  String get sui => 'Sui';

  /// zh: '请输入联系人名称'
  String get nameRequired => '请输入联系人名称';

  /// zh: '请输入钱包地址'
  String get addressRequired => '请输入钱包地址';

  /// zh: '地址格式与链类型不匹配'
  String get invalidAddress => '地址格式与链类型不匹配';

  /// zh: '删除联系人'
  String get deleteTitle => '删除联系人';

  /// zh: '删除后无法从地址簿中选择该联系人。'
  String get deleteMessage => '删除后无法从地址簿中选择该联系人。';

  /// zh: '确认删除'
  String get confirmDelete => '确认删除';

  /// zh: '暂无联系人'
  String get empty => '暂无联系人';

  /// zh: '联系人列表读取失败'
  String get loadFailed => '联系人列表读取失败';

  /// zh: '选择联系人'
  String get pickTitle => '选择联系人';

  /// zh: '其他钱包'
  String get otherWallets => '其他钱包';

  /// zh: '地址簿联系人'
  String get contacts => '地址簿联系人';

  /// zh: '当前链暂无可选联系人'
  String get noContactsForChain => '当前链暂无可选联系人';
}

// Path: wallet
class Translations$wallet$zh {
  Translations$wallet$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '创建钱包'
  String get create => '创建钱包';

  /// zh: '导入钱包'
  String get import => '导入钱包';

  /// zh: '查看'
  String get view => '查看';

  /// zh: '助记词'
  String get mnemonicWallet => '助记词';

  /// zh: '私钥'
  String get privateKeyWallet => '私钥';

  /// zh: '更多操作'
  String get moreActions => '更多操作';

  /// zh: '复制 EVM 地址'
  String get copyEvm => '复制 EVM 地址';

  /// zh: '复制 BTC 地址'
  String get copyBtc => '复制 BTC 地址';

  /// zh: '复制 Solana 地址'
  String get copySolana => '复制 Solana 地址';

  /// zh: '复制 Sui 地址'
  String get copySui => '复制 Sui 地址';

  /// zh: '接收二维码'
  String get receiveQr => '接收二维码';

  /// zh: '$walletName - $chainName'
  String receiveQrTitle({
    required Object walletName,
    required Object chainName,
  }) => '${walletName} - ${chainName}';

  /// zh: '复制地址'
  String get copyAddress => '复制地址';

  /// zh: '复制'
  String get copy => '复制';

  /// zh: '保存'
  String get saveQrImage => '保存';

  /// zh: '数量'
  String get amount => '数量';

  /// zh: '请输入数量'
  String get enterAmountTitle => '请输入数量';

  /// zh: '确定'
  String get amountConfirm => '确定';

  /// zh: '约等于'
  String get amountApproxPrefix => '约等于';

  /// zh: 'USD'
  String get usdCode => 'USD';

  /// zh: '当前钱包没有当前链地址'
  String get noAddressForChain => '当前钱包没有当前链地址';

  /// zh: '二维码已保存到相册'
  String get qrImageSaved => '二维码已保存到相册';

  /// zh: '需要相册权限才能保存二维码'
  String get qrImagePhotoPermissionRequired => '需要相册权限才能保存二维码';

  /// zh: '二维码保存失败，请重试'
  String get qrImageSaveFailed => '二维码保存失败，请重试';

  /// zh: '重命名'
  String get rename => '重命名';

  /// zh: '修改密码'
  String get changePassword => '修改密码';

  /// zh: '当前钱包密码'
  String get currentPasswordLabel => '当前钱包密码';

  /// zh: '新钱包密码'
  String get newPasswordLabel => '新钱包密码';

  /// zh: '确认新密码'
  String get confirmNewPasswordLabel => '确认新密码';

  /// zh: '请输入新钱包密码'
  String get newPasswordRequired => '请输入新钱包密码';

  /// zh: '密码已修改'
  String get passwordChanged => '密码已修改';

  /// zh: '钱包名称'
  String get nameLabel => '钱包名称';

  /// zh: '切换钱包'
  String get switchWallet => '切换钱包';

  /// zh: '当前'
  String get selected => '当前';

  /// zh: '删除'
  String get delete => '删除';

  /// zh: '删除钱包'
  String get deleteTitle => '删除钱包';

  /// zh: '删除前必须确认密码。删除后需要重新导入助记词或私钥才能恢复。'
  String get deleteMessage => '删除前必须确认密码。删除后需要重新导入助记词或私钥才能恢复。';

  /// zh: '我确认已备份该钱包的助记词或私钥'
  String get deleteAcknowledge => '我确认已备份该钱包的助记词或私钥';

  /// zh: '请先确认已备份钱包'
  String get deleteRequiresConfirmation => '请先确认已备份钱包';

  /// zh: '导出'
  String get exportSecret => '导出';

  /// zh: '导出助记词'
  String get exportMnemonic => '导出助记词';

  /// zh: '导出私钥'
  String get exportPrivateKey => '导出私钥';

  /// zh: '导出 BTC 私钥'
  String get exportBtcPrivateKey => '导出 BTC 私钥';

  /// zh: '高风险操作。请确认周围环境安全，导出的内容不要截图、不要发送给任何人。'
  String get exportSecretWarning => '高风险操作。请确认周围环境安全，导出的内容不要截图、不要发送给任何人。';

  /// zh: '验证钱包密码'
  String get exportPasswordTitle => '验证钱包密码';

  /// zh: '输入钱包密码后查看导出内容。'
  String get exportPasswordBody => '输入钱包密码后查看导出内容。';

  /// zh: '助记词可恢复钱包并控制全部资产。请勿截图、上传云端或发送给任何人；复制后请及时清理剪贴板。'
  String get mnemonicRiskWarning =>
      '助记词可恢复钱包并控制全部资产。请勿截图、上传云端或发送给任何人；复制后请及时清理剪贴板。';

  /// zh: '私钥可直接控制对应网络资产。请勿截图、粘贴到不可信应用或发送给任何人；复制后请及时清理剪贴板。'
  String get privateKeyRiskWarning =>
      '私钥可直接控制对应网络资产。请勿截图、粘贴到不可信应用或发送给任何人；复制后请及时清理剪贴板。';

  /// zh: '助记词已复制'
  String get mnemonicCopied => '助记词已复制';

  /// zh: '私钥已复制'
  String get privateKeyCopied => '私钥已复制';

  /// zh: '地址已复制'
  String get addressCopied => '地址已复制';

  /// zh: 'EVM 地址'
  String get evmAddress => 'EVM 地址';

  /// zh: 'BTC 地址'
  String get btcAddress => 'BTC 地址';

  /// zh: 'Tron 地址'
  String get tronAddress => 'Tron 地址';

  /// zh: 'Solana 地址'
  String get solanaAddress => 'Solana 地址';

  /// zh: 'Sui 地址'
  String get suiAddress => 'Sui 地址';

  /// zh: '解锁钱包'
  String get unlockTitle => '解锁钱包';

  /// zh: '输入本机钱包密码以恢复当前会话。'
  String get unlockBody => '输入本机钱包密码以恢复当前会话。';

  /// zh: '解锁'
  String get unlockButton => '解锁';

  /// zh: '正在解锁'
  String get unlocking => '正在解锁';

  /// zh: '验证签名身份'
  String get signingPasswordTitle => '验证签名身份';

  /// zh: '验证身份后继续本次签名操作。'
  String get signingPasswordBody => '验证身份后继续本次签名操作。';

  /// zh: '15 分钟内记住密码'
  String get rememberSigningPassword => '15 分钟内记住密码';

  /// zh: '设置生物识别密码'
  String get biometricSetupTitle => '设置生物识别密码';

  /// zh: '以后需要钱包密码时，可优先使用指纹或面容验证。'
  String get biometricSetupBody => '以后需要钱包密码时，可优先使用指纹或面容验证。';

  /// zh: '设置'
  String get biometricSetupConfirm => '设置';

  /// zh: '验证身份以使用钱包密码'
  String get biometricReason => '验证身份以使用钱包密码';

  /// zh: '使用生物识别'
  String get biometricUseButton => '使用生物识别';

  /// zh: '生物识别密码已启用'
  String get biometricEnabled => '生物识别密码已启用';
}

// Path: settings
class Translations$settings$zh {
  Translations$settings$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '钱包管理'
  String get walletManagement => '钱包管理';

  /// zh: '网络管理'
  String get networkManagement => '网络管理';

  /// zh: '地址簿'
  String get addressBook => '地址簿';

  /// zh: '高级'
  String get advanced => '高级';

  /// zh: '偏好设置'
  String get preferences => '偏好设置';

  /// zh: '多语言设置'
  String get language => '多语言设置';

  /// zh: '货币'
  String get fiatCurrency => '货币';

  /// zh: '美元 (USD)'
  String get fiatCurrencyUsd => '美元 (USD)';

  /// zh: '人民币 (CNY)'
  String get fiatCurrencyCny => '人民币 (CNY)';

  /// zh: '欧元 (EUR)'
  String get fiatCurrencyEur => '欧元 (EUR)';

  /// zh: '日元 (JPY)'
  String get fiatCurrencyJpy => '日元 (JPY)';

  /// zh: '主题模式'
  String get themeMode => '主题模式';

  /// zh: '跟随系统'
  String get themeModeSystem => '跟随系统';

  /// zh: '亮色模式'
  String get themeModeLight => '亮色模式';

  /// zh: '暗色模式'
  String get themeModeDark => '暗色模式';

  /// zh: '主题颜色'
  String get themeColor => '主题颜色';

  /// zh: '靛蓝'
  String get themeColorIndigo => '靛蓝';

  /// zh: '蓝色'
  String get themeColorBlue => '蓝色';

  /// zh: '紫色'
  String get themeColorPurple => '紫色';

  /// zh: '绿色'
  String get themeColorGreen => '绿色';

  /// zh: '橙色'
  String get themeColorOrange => '橙色';

  /// zh: '玫红'
  String get themeColorRose => '玫红';

  /// zh: '深蓝'
  String get themeColorNavy => '深蓝';

  /// zh: '安全设置'
  String get security => '安全设置';

  /// zh: '关于'
  String get about => '关于';

  /// zh: '跟随系统'
  String get languageSystem => '跟随系统';

  /// zh: '简体中文'
  String get languageZh => '简体中文';

  /// zh: 'English'
  String get languageEn => 'English';

  /// zh: '启动时要求密码'
  String get requirePasswordOnLaunch => '启动时要求密码';

  /// zh: '每次启动 App 时先验证钱包密码'
  String get requirePasswordOnLaunchSubtitle => '每次启动 App 时先验证钱包密码';

  /// zh: '后台隐私遮罩'
  String get backgroundPrivacyShield => '后台隐私遮罩';

  /// zh: '进入后台时模糊显示 App 内容'
  String get backgroundPrivacyShieldSubtitle => '进入后台时模糊显示 App 内容';

  /// zh: '自动锁定'
  String get autoLock => '自动锁定';

  /// zh: '离开 App 后多久锁定钱包'
  String get autoLockSubtitle => '离开 App 后多久锁定钱包';

  /// zh: '立即'
  String get autoLockImmediately => '立即';

  /// zh: '1 分钟'
  String get autoLockOneMinute => '1 分钟';

  /// zh: '5 分钟'
  String get autoLockFiveMinutes => '5 分钟';

  /// zh: '15 分钟'
  String get autoLockFifteenMinutes => '15 分钟';

  /// zh: '1 小时'
  String get autoLockOneHour => '1 小时';

  /// zh: '生物识别密码'
  String get biometricPassword => '生物识别密码';

  /// zh: '需要钱包密码时可使用生物识别'
  String get biometricPasswordSubtitle => '需要钱包密码时可使用生物识别';

  /// zh: '当前设备不可用生物识别'
  String get biometricPasswordUnavailable => '当前设备不可用生物识别';

  /// zh: '输入当前钱包密码以启用生物识别密码。'
  String get biometricPasswordSetupPrompt => '输入当前钱包密码以启用生物识别密码。';

  /// zh: '更新全局钱包密码'
  String get changePasswordSubtitle => '更新全局钱包密码';

  /// zh: '安全日志'
  String get securityLog => '安全日志';

  /// zh: '自动在本机记录并查看敏感安全操作'
  String get securityLogSubtitle => '自动在本机记录并查看敏感安全操作';

  /// zh: '验证钱包密码'
  String get securityLogPasswordTitle => '验证钱包密码';

  /// zh: '查看安全日志前，请先验证钱包密码。'
  String get securityLogPasswordBody => '查看安全日志前，请先验证钱包密码。';

  /// zh: '暂无安全日志'
  String get securityLogEmpty => '暂无安全日志';

  /// zh: '安全日志仅记录操作类型、钱包名称、链、公开地址、币种、数量和时间，并只存储在您的设备本地，不会保存私钥、助记词、密码或签名内容。'
  String get securityLogSafetyNotice =>
      '安全日志仅记录操作类型、钱包名称、链、公开地址、币种、数量和时间，并只存储在您的设备本地，不会保存私钥、助记词、密码或签名内容。';

  /// zh: '钱包：'
  String get securityLogWalletLabel => '钱包：';

  /// zh: '链：'
  String get securityLogChainLabel => '链：';

  /// zh: '金额：'
  String get securityLogAmountLabel => '金额：';

  /// zh: '公开地址：'
  String get securityLogAddressLabel => '公开地址：';

  /// zh: '查看助记词'
  String get securityLogViewMnemonic => '查看助记词';

  /// zh: '查看私钥'
  String get securityLogViewPrivateKey => '查看私钥';

  /// zh: '复制助记词'
  String get securityLogCopyMnemonic => '复制助记词';

  /// zh: '复制私钥'
  String get securityLogCopyPrivateKey => '复制私钥';

  /// zh: '创建钱包'
  String get securityLogCreateWallet => '创建钱包';

  /// zh: '导入钱包'
  String get securityLogImportWallet => '导入钱包';

  /// zh: '删除钱包'
  String get securityLogDeleteWallet => '删除钱包';

  /// zh: '修改密码'
  String get securityLogChangePassword => '修改密码';

  /// zh: '消息签名'
  String get securityLogSignMessage => '消息签名';

  /// zh: '交易签名'
  String get securityLogSignTransaction => '交易签名';

  /// zh: '封装原生币'
  String get securityLogWrapNative => '封装原生币';

  /// zh: '解封装原生币'
  String get securityLogUnwrapNative => '解封装原生币';

  /// zh: 'Solana 租金回收'
  String get securityLogSolanaRentRecovery => 'Solana 租金回收';

  /// zh: 'TRX 质押'
  String get securityLogTronStake => 'TRX 质押';

  /// zh: 'TRX 解押'
  String get securityLogTronUnstake => 'TRX 解押';

  /// zh: '提取已解押 TRX'
  String get securityLogTronWithdrawUnfreeze => '提取已解押 TRX';

  /// zh: '取消 TRX 解押'
  String get securityLogTronCancelUnfreeze => '取消 TRX 解押';

  /// zh: '委托 TRON 资源'
  String get securityLogTronDelegateResource => '委托 TRON 资源';

  /// zh: '取消委托 TRON 资源'
  String get securityLogTronUndelegateResource => '取消委托 TRON 资源';

  /// zh: 'TRON 超级代表投票'
  String get securityLogTronVote => 'TRON 超级代表投票';

  /// zh: '领取 TRON 投票奖励'
  String get securityLogTronClaimReward => '领取 TRON 投票奖励';

  /// zh: '清除 dApp 授权'
  String get clearDappPermissions => '清除 dApp 授权';

  /// zh: '移除站点连接权限'
  String get clearDappPermissionsSubtitle => '移除站点连接权限';

  /// zh: '已授权 dApp'
  String get connectedDapps => '已授权 dApp';

  /// zh: '暂无已授权 dApp'
  String get noConnectedDapps => '暂无已授权 dApp';

  /// zh: '撤销'
  String get revoke => '撤销';

  /// zh: '撤销 dApp 授权'
  String get revokeDappPermission => '撤销 dApp 授权';

  /// zh: '撤销后，该站点需要重新请求授权才能读取账户地址。'
  String get revokeDappPermissionSubtitle => '撤销后，该站点需要重新请求授权才能读取账户地址。';

  /// zh: 'EVM 网络'
  String get evmNetworks => 'EVM 网络';

  /// zh: 'Bitcoin 网络'
  String get bitcoinNetworks => 'Bitcoin 网络';

  /// zh: 'Solana 网络'
  String get solanaNetworks => 'Solana 网络';

  /// zh: 'Tron 网络'
  String get tronNetworks => 'Tron 网络';

  /// zh: 'Sui 网络'
  String get suiNetworks => 'Sui 网络';

  /// zh: '当前 RPC 读取中'
  String get currentRpcUnknown => '当前 RPC 读取中';
}

// Path: tronStaking
class Translations$tronStaking$zh {
  Translations$tronStaking$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: 'TRX 质押'
  String get title => 'TRX 质押';

  /// zh: '管理 Stake 2.0、资源委托、投票和奖励'
  String get advancedSubtitle => '管理 Stake 2.0、资源委托、投票和奖励';

  /// zh: '钱包'
  String get wallet => '钱包';

  /// zh: '网络'
  String get network => '网络';

  /// zh: '刷新质押状态'
  String get refresh => '刷新质押状态';

  /// zh: '没有包含 TRON 地址的钱包'
  String get noWallet => '没有包含 TRON 地址的钱包';

  /// zh: '没有可用的 TRON 网络'
  String get noNetwork => '没有可用的 TRON 网络';

  /// zh: '质押数据加载失败，请检查 TRON 节点后重试'
  String get loadFailed => '质押数据加载失败，请检查 TRON 节点后重试';

  /// zh: '可用余额'
  String get availableBalance => '可用余额';

  /// zh: 'Bandwidth 质押'
  String get bandwidthStaked => 'Bandwidth 质押';

  /// zh: 'Energy 质押'
  String get energyStaked => 'Energy 质押';

  /// zh: 'TRON Power'
  String get tronPower => 'TRON Power';

  /// zh: '可用票数'
  String get availableVotes => '可用票数';

  /// zh: '资源'
  String get resourceOverview => '资源';

  /// zh: 'Bandwidth'
  String get bandwidth => 'Bandwidth';

  /// zh: 'Energy'
  String get energy => 'Energy';

  /// zh: '可用 $available / $limit · 已用 $used'
  String availableResource({
    required Object available,
    required Object limit,
    required Object used,
  }) => '可用 ${available} / ${limit} · 已用 ${used}';

  /// zh: '质押'
  String get stake => '质押';

  /// zh: '解押'
  String get unstake => '解押';

  /// zh: '资源委托'
  String get delegate => '资源委托';

  /// zh: '超级代表投票'
  String get vote => '超级代表投票';

  /// zh: '质押 TRX'
  String get stakeTitle => '质押 TRX';

  /// zh: '解押 TRX'
  String get unstakeTitle => '解押 TRX';

  /// zh: '委托资源'
  String get delegateTitle => '委托资源';

  /// zh: '取消资源委托'
  String get undelegateTitle => '取消资源委托';

  /// zh: '资源类型'
  String get resourceType => '资源类型';

  /// zh: '数量'
  String get amount => '数量';

  /// zh: '输入 TRX 数量'
  String get amountHint => '输入 TRX 数量';

  /// zh: '最大'
  String get maximum => '最大';

  /// zh: '继续'
  String get continueAction => '继续';

  /// zh: '请输入有效的 TRX 数量，最多 6 位小数'
  String get invalidAmount => '请输入有效的 TRX 数量，最多 6 位小数';

  /// zh: '可用 TRX 余额不足'
  String get insufficientBalance => '可用 TRX 余额不足';

  /// zh: '该资源的可解押质押不足'
  String get insufficientStaked => '该资源的可解押质押不足';

  /// zh: '当前没有可用的解押次数'
  String get noUnfreezeSlots => '当前没有可用的解押次数';

  /// zh: '确认质押'
  String get confirmStake => '确认质押';

  /// zh: '确认解押'
  String get confirmUnstake => '确认解押';

  /// zh: '确认资源委托'
  String get confirmDelegate => '确认资源委托';

  /// zh: '确认取消委托'
  String get confirmUndelegate => '确认取消委托';

  /// zh: '确认提取已解押 TRX'
  String get confirmWithdraw => '确认提取已解押 TRX';

  /// zh: '确认取消全部解押'
  String get confirmCancel => '确认取消全部解押';

  /// zh: '确认投票分配'
  String get confirmVote => '确认投票分配';

  /// zh: '确认领取奖励'
  String get confirmClaimReward => '确认领取奖励';

  /// zh: '确认并签名'
  String get confirmAndSign => '确认并签名';

  /// zh: '钱包地址'
  String get owner => '钱包地址';

  /// zh: '接收地址'
  String get receiver => '接收地址';

  /// zh: '输入 TRON 地址'
  String get receiverHint => '输入 TRON 地址';

  /// zh: '请输入有效且不同于当前钱包的 TRON 地址'
  String get invalidReceiver => '请输入有效且不同于当前钱包的 TRON 地址';

  /// zh: '锁定委托'
  String get lockResource => '锁定委托';

  /// zh: '当前网络不支持锁定委托'
  String get lockUnsupported => '当前网络不支持锁定委托';

  /// zh: '已锁定'
  String get locked => '已锁定';

  /// zh: '不锁定'
  String get unlocked => '不锁定';

  /// zh: '锁定周期（区块）'
  String get lockPeriod => '锁定周期（区块）';

  /// zh: '输入区块数，最多 $max 个区块'
  String lockPeriodHint({required Object max}) => '输入区块数，最多 ${max} 个区块';

  /// zh: '$count 个区块'
  String lockPeriodValue({required Object count}) => '${count} 个区块';

  /// zh: '预计网络费用'
  String get estimatedFee => '预计网络费用';

  /// zh: '质押后可用余额'
  String get remainingBalance => '质押后可用余额';

  /// zh: '根据 Bandwidth 使用情况动态计算'
  String get feeCalculatedByNetwork => '根据 Bandwidth 使用情况动态计算';

  /// zh: '网络费用估算失败，暂不能继续'
  String get feeEstimateFailed => '网络费用估算失败，暂不能继续';

  /// zh: '解押等待期为 $days 天，到期后需要提取'
  String unstakeDelay({required Object days}) => '解押等待期为 ${days} 天，到期后需要提取';

  /// zh: '预计 $date 可提取'
  String unstakeAvailableAt({required Object date}) => '预计 ${date} 可提取';

  /// zh: '剩余可发起解押次数：$count'
  String unfreezeSlotsRemaining({required Object count}) =>
      '剩余可发起解押次数：${count}';

  /// zh: '解押中'
  String get pendingUnfreeze => '解押中';

  /// zh: '解押中总额：$amount TRX'
  String pendingTotal({required Object amount}) => '解押中总额：${amount} TRX';

  /// zh: '当前可提取：$amount TRX'
  String withdrawableAmount({required Object amount}) => '当前可提取：${amount} TRX';

  /// zh: '最近到期：$date'
  String nextUnfreezeAt({required Object date}) => '最近到期：${date}';

  /// zh: '当前没有解押中的 TRX'
  String get pendingEmpty => '当前没有解押中的 TRX';

  /// zh: '$date 到期'
  String expiresAt({required Object date}) => '${date} 到期';

  /// zh: '可提取'
  String get withdrawable => '可提取';

  /// zh: '提取 $amount TRX'
  String withdraw({required Object amount}) => '提取 ${amount} TRX';

  /// zh: '取消全部解押'
  String get cancelAll => '取消全部解押';

  /// zh: '该操作会取消全部未到期解押，协议不支持只取消其中一笔。'
  String get cancelAllWarning => '该操作会取消全部未到期解押，协议不支持只取消其中一笔。';

  /// zh: '资源委托'
  String get delegations => '资源委托';

  /// zh: '当前没有资源委托记录'
  String get delegationsEmpty => '当前没有资源委托记录';

  /// zh: '已委托给'
  String get delegatedTo => '已委托给';

  /// zh: '收到自'
  String get receivedFrom => '收到自';

  /// zh: '取消委托'
  String get undelegate => '取消委托';

  /// zh: '超级代表'
  String get witnesses => '超级代表';

  /// zh: '搜索地址或 URL'
  String get witnessSearch => '搜索地址或 URL';

  /// zh: '$count 票'
  String witnessVotes({required Object count}) => '${count} 票';

  /// zh: '我的票数'
  String get myVotes => '我的票数';

  /// zh: '已分配 $used / $total 票'
  String voteSummary({required Object used, required Object total}) =>
      '已分配 ${used} / ${total} 票';

  /// zh: '清空投票'
  String get clearVotes => '清空投票';

  /// zh: '可领取奖励'
  String get reward => '可领取奖励';

  /// zh: '领取奖励'
  String get claimReward => '领取奖励';

  /// zh: '当前没有可领取奖励'
  String get noReward => '当前没有可领取奖励';

  /// zh: '正在提交 TRON 交易…'
  String get submitting => '正在提交 TRON 交易…';

  /// zh: 'TRON 交易已提交'
  String get submitted => 'TRON 交易已提交';

  /// zh: '需要解锁钱包才能签名'
  String get walletLocked => '需要解锁钱包才能签名';

  /// zh: '当前钱包没有可用的 TRON 私钥'
  String get signingKeyUnavailable => '当前钱包没有可用的 TRON 私钥';

  /// zh: '当前没有已到期、可提取的 TRX'
  String get nothingToWithdraw => '当前没有已到期、可提取的 TRX';

  /// zh: '当前网络不支持取消全部解押'
  String get cancelUnsupported => '当前网络不支持取消全部解押';

  /// zh: '当前没有可取消的解押记录'
  String get nothingToCancel => '当前没有可取消的解押记录';

  /// zh: '当前网络未启用资源委托'
  String get delegationUnsupported => '当前网络未启用资源委托';

  /// zh: '委托地址或锁定参数无效'
  String get invalidDelegation => '委托地址或锁定参数无效';

  /// zh: '当前没有可委托的质押资源'
  String get insufficientDelegatableBalance => '当前没有可委托的质押资源';

  /// zh: '该委托仍在锁定期，到期后才能取消'
  String get delegationLocked => '该委托仍在锁定期，到期后才能取消';

  /// zh: '可取消的委托资源不足'
  String get insufficientDelegatedBalance => '可取消的委托资源不足';

  /// zh: '分配票数超过可用 TRON Power'
  String get excessiveVotes => '分配票数超过可用 TRON Power';

  /// zh: '当前没有可领取奖励'
  String get nothingToClaim => '当前没有可领取奖励';

  /// zh: '节点返回的交易未通过本地安全校验'
  String get transactionValidationFailed => '节点返回的交易未通过本地安全校验';

  /// zh: 'TRON 交易提交失败，请刷新链上状态后重试'
  String get broadcastFailed => 'TRON 交易提交失败，请刷新链上状态后重试';

  /// zh: '当前链上状态不允许执行该操作'
  String get operationUnavailable => '当前链上状态不允许执行该操作';
}

// Path: advanced
class Translations$advanced$zh {
  Translations$advanced$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '高级'
  String get title => '高级';

  /// zh: '合约调用'
  String get contractCall => '合约调用';

  /// zh: '读取合约或签名发起写入调用'
  String get contractCallSubtitle => '读取合约或签名发起写入调用';

  /// zh: '原生币封装'
  String get wrappedNative => '原生币封装';

  /// zh: '在原生币与封装代币之间进行 1:1 转换'
  String get wrappedNativeSubtitle => '在原生币与封装代币之间进行 1:1 转换';

  /// zh: '钱包'
  String get wrappedNativeWallet => '钱包';

  /// zh: '网络'
  String get wrappedNativeNetwork => '网络';

  /// zh: '封装'
  String get wrappedNativeWrap => '封装';

  /// zh: '解封装'
  String get wrappedNativeUnwrap => '解封装';

  /// zh: '原生币余额'
  String get wrappedNativeBalance => '原生币余额';

  /// zh: '封装代币余额'
  String get wrappedNativeTokenBalance => '封装代币余额';

  /// zh: '数量'
  String get wrappedNativeAmount => '数量';

  /// zh: '输入转换数量'
  String get wrappedNativeAmountHint => '输入转换数量';

  /// zh: '最大'
  String get wrappedNativeMax => '最大';

  /// zh: '检查交易'
  String get wrappedNativeReview => '检查交易';

  /// zh: '正在模拟并估算费用…'
  String get wrappedNativePreparing => '正在模拟并估算费用…';

  /// zh: '刷新余额'
  String get wrappedNativeRefresh => '刷新余额';

  /// zh: '转换由当前网络的标准封装合约执行，兑换比例为 1:1。请核对网络、数量、手续费和目标代币后再签名。'
  String get wrappedNativeRisk =>
      '转换由当前网络的标准封装合约执行，兑换比例为 1:1。请核对网络、数量、手续费和目标代币后再签名。';

  /// zh: '确认原生币转换'
  String get wrappedNativeConfirmTitle => '确认原生币转换';

  /// zh: '支付'
  String get wrappedNativeFrom => '支付';

  /// zh: '获得'
  String get wrappedNativeTo => '获得';

  /// zh: '最大网络手续费'
  String get wrappedNativeNetworkFee => '最大网络手续费';

  /// zh: '账户租金'
  String get wrappedNativeRent => '账户租金';

  /// zh: '确认封装'
  String get wrappedNativeConfirmWrap => '确认封装';

  /// zh: '确认解封装'
  String get wrappedNativeConfirmUnwrap => '确认解封装';

  /// zh: '正在签名并提交…'
  String get wrappedNativeSubmitting => '正在签名并提交…';

  /// zh: '封装交易已提交'
  String get wrappedNativeSuccessWrap => '封装交易已提交';

  /// zh: '解封装交易已提交'
  String get wrappedNativeSuccessUnwrap => '解封装交易已提交';

  /// zh: '交易 Hash'
  String get wrappedNativeTransactionHash => '交易 Hash';

  /// zh: '在区块浏览器查看'
  String get wrappedNativeViewExplorer => '在区块浏览器查看';

  /// zh: '没有适用于当前网络的钱包'
  String get wrappedNativeNoWallet => '没有适用于当前网络的钱包';

  /// zh: '没有支持原生币封装的网络'
  String get wrappedNativeNoNetwork => '没有支持原生币封装的网络';

  /// zh: '请输入有效且大于零的数量'
  String get wrappedNativeInvalidAmount => '请输入有效且大于零的数量';

  /// zh: '原生币余额不足，需同时预留网络手续费和可能的账户租金'
  String get wrappedNativeInsufficientNative => '原生币余额不足，需同时预留网络手续费和可能的账户租金';

  /// zh: '封装代币余额不足'
  String get wrappedNativeInsufficientWrapped => '封装代币余额不足';

  /// zh: '余额读取失败，请检查 RPC 节点后重试'
  String get wrappedNativeBalanceFailed => '余额读取失败，请检查 RPC 节点后重试';

  /// zh: '交易模拟或费用估算失败，请检查余额和 RPC 节点'
  String get wrappedNativePreparationFailed => '交易模拟或费用估算失败，请检查余额和 RPC 节点';

  /// zh: '需要解锁钱包才能签名'
  String get wrappedNativeWalletLocked => '需要解锁钱包才能签名';

  /// zh: '所选钱包没有当前网络可用的签名私钥'
  String get wrappedNativeSigningKeyUnavailable => '所选钱包没有当前网络可用的签名私钥';

  /// zh: '交易提交失败，请刷新余额并确认链上结果'
  String get wrappedNativeSubmissionFailed => '交易提交失败，请刷新余额并确认链上结果';

  /// zh: 'Solana 租金回收'
  String get solanaRentRecovery => 'Solana 租金回收';

  /// zh: '关闭安全的空 Token 账户并取回账户租金'
  String get solanaRentRecoverySubtitle => '关闭安全的空 Token 账户并取回账户租金';

  /// zh: '钱包'
  String get solanaRentWallet => '钱包';

  /// zh: 'Solana 网络'
  String get solanaRentNetwork => 'Solana 网络';

  /// zh: '刷新可回收租金'
  String get solanaRentRefresh => '刷新可回收租金';

  /// zh: '可回收账户'
  String get solanaRentRecoverableAccounts => '可回收账户';

  /// zh: '已选账户'
  String get solanaRentSelectedSummary => '已选账户';

  /// zh: '可回收总额'
  String get solanaRentTotalRecoverable => '可回收总额';

  /// zh: '预计净到账'
  String get solanaRentNetRecoverable => '预计净到账';

  /// zh: '当前没有可安全回收租金的空 Token 账户'
  String get solanaRentNoAccounts => '当前没有可安全回收租金的空 Token 账户';

  /// zh: '开始回收'
  String get solanaRentStartRecovery => '开始回收';

  /// zh: '回收会关闭所选的零余额 Token 账户，并将账户租金退回当前钱包。若以后再次持有对应代币，链上可能重新创建 Token 账户并产生租金。'
  String get solanaRentRisk =>
      '回收会关闭所选的零余额 Token 账户，并将账户租金退回当前钱包。若以后再次持有对应代币，链上可能重新创建 Token 账户并产生租金。';

  /// zh: '确认租金回收'
  String get solanaRentConfirmTitle => '确认租金回收';

  /// zh: '账户数量'
  String get solanaRentSelectedAccounts => '账户数量';

  /// zh: '接收钱包'
  String get solanaRentReceivingWallet => '接收钱包';

  /// zh: '确认并签名'
  String get solanaRentConfirmAndSign => '确认并签名';

  /// zh: '正在扫描可回收账户…'
  String get solanaRentScanning => '正在扫描可回收账户…';

  /// zh: '正在分批提交回收交易…'
  String get solanaRentSubmitting => '正在分批提交回收交易…';

  /// zh: '回收中…'
  String get solanaRentRecovering => '回收中…';

  /// zh: '租金回收成功'
  String get solanaRentSuccess => '租金回收成功';

  /// zh: '部分租金已回收'
  String get solanaRentPartialSuccess => '部分租金已回收';

  /// zh: '租金回收失败'
  String get solanaRentFailed => '租金回收失败';

  /// zh: '已完成账户'
  String get solanaRentRecoveredAccounts => '已完成账户';

  /// zh: '实际回收金额'
  String get solanaRentRecoveredAmount => '实际回收金额';

  /// zh: '交易签名'
  String get solanaRentSignatures => '交易签名';

  /// zh: '复制签名'
  String get solanaRentCopySignature => '复制签名';

  /// zh: '交易签名已复制'
  String get solanaRentSignatureCopied => '交易签名已复制';

  /// zh: '在 Solscan 查看'
  String get solanaRentOpenSolscan => '在 Solscan 查看';

  /// zh: 'SPL Token'
  String get solanaRentSplToken => 'SPL Token';

  /// zh: 'Token-2022'
  String get solanaRentToken2022 => 'Token-2022';

  /// zh: '没有包含 Solana 地址的钱包'
  String get solanaRentNoWallet => '没有包含 Solana 地址的钱包';

  /// zh: '没有可用的 Solana 网络'
  String get solanaRentNoNetwork => '没有可用的 Solana 网络';

  /// zh: '扫描可回收账户失败，请检查 RPC 节点后重试'
  String get solanaRentScanFailed => '扫描可回收账户失败，请检查 RPC 节点后重试';

  /// zh: '交易模拟失败，所选账户可能已发生变化'
  String get solanaRentSimulationFailed => '交易模拟失败，所选账户可能已发生变化';

  /// zh: '钱包的 SOL 余额不足以支付预计网络手续费'
  String get solanaRentInsufficientFee => '钱包的 SOL 余额不足以支付预计网络手续费';

  /// zh: '请至少选择一个要回收的 Token 账户'
  String get solanaRentSelectAccount => '请至少选择一个要回收的 Token 账户';

  /// zh: '需要解锁钱包才能签名'
  String get solanaRentWalletLocked => '需要解锁钱包才能签名';

  /// zh: '所选钱包没有可用的 Solana 签名私钥'
  String get solanaRentSigningKeyUnavailable => '所选钱包没有可用的 Solana 签名私钥';

  /// zh: '可回收账户已发生变化，请刷新后重试'
  String get solanaRentAccountsChanged => '可回收账户已发生变化，请刷新后重试';

  /// zh: '部分或全部回收交易失败，请刷新后确认链上结果'
  String get solanaRentRecoveryFailed => '部分或全部回收交易失败，请刷新后确认链上结果';

  /// zh: 'WalletConnect'
  String get walletConnect => 'WalletConnect';

  /// zh: '连接外部 dApp 并管理活跃会话'
  String get walletConnectSubtitle => '连接外部 dApp 并管理活跃会话';

  /// zh: '扫描二维码'
  String get walletConnectScan => '扫描二维码';

  /// zh: '粘贴连接 URI'
  String get walletConnectPaste => '粘贴连接 URI';

  /// zh: 'wc: URI'
  String get walletConnectUriHint => 'wc: URI';

  /// zh: '连接'
  String get walletConnectConnect => '连接';

  /// zh: '活跃会话'
  String get walletConnectActiveSessions => '活跃会话';

  /// zh: '暂无活跃的 WalletConnect 会话'
  String get walletConnectNoSessions => '暂无活跃的 WalletConnect 会话';

  /// zh: '构建时未设置 REOWN_PROJECT_ID，你可以在 App 内设置自己的 WalletConnect Dashboard Project ID。'
  String get walletConnectMissingConfig =>
      '构建时未设置 REOWN_PROJECT_ID，你可以在 App 内设置自己的 WalletConnect Dashboard Project ID。';

  /// zh: 'Project ID'
  String get walletConnectProjectId => 'Project ID';

  /// zh: 'Project ID 是公开的项目标识，不是钱包私钥。'
  String get walletConnectProjectIdDescription => 'Project ID 是公开的项目标识，不是钱包私钥。';

  /// zh: 'App 内设置'
  String get walletConnectProjectIdSourceCustom => 'App 内设置';

  /// zh: '构建配置'
  String get walletConnectProjectIdSourceBuild => '构建配置';

  /// zh: '未配置'
  String get walletConnectProjectIdSourceMissing => '未配置';

  /// zh: '设置'
  String get walletConnectProjectIdSet => '设置';

  /// zh: '替换'
  String get walletConnectProjectIdReplace => '替换';

  /// zh: '删除'
  String get walletConnectProjectIdDelete => '删除';

  /// zh: '设置 Project ID'
  String get walletConnectProjectIdInputTitle => '设置 Project ID';

  /// zh: '32 位十六进制 Project ID'
  String get walletConnectProjectIdInputHint => '32 位十六进制 Project ID';

  /// zh: '请输入 32 位十六进制 Project ID。'
  String get walletConnectProjectIdInvalid => '请输入 32 位十六进制 Project ID。';

  /// zh: 'Project ID 已保存并生效。'
  String get walletConnectProjectIdSaved => 'Project ID 已保存并生效。';

  /// zh: '自定义 Project ID 已删除，已启用构建配置。'
  String get walletConnectProjectIdDeleted => '自定义 Project ID 已删除，已启用构建配置。';

  /// zh: '自定义 Project ID 已删除，WalletConnect 已停用。'
  String get walletConnectProjectIdDeletedWithoutBuild =>
      '自定义 Project ID 已删除，WalletConnect 已停用。';

  /// zh: 'Project ID 已保存，但 WalletConnect 初始化失败，请检查后重试。'
  String get walletConnectProjectIdApplyFailed =>
      'Project ID 已保存，但 WalletConnect 初始化失败，请检查后重试。';

  /// zh: '删除自定义 Project ID'
  String get walletConnectProjectIdDeleteTitle => '删除自定义 Project ID';

  /// zh: '删除后，WalletConnect 将回退使用构建时配置的 Project ID。'
  String get walletConnectProjectIdDeleteWithBuild =>
      '删除后，WalletConnect 将回退使用构建时配置的 Project ID。';

  /// zh: '构建时也没有 Project ID，删除后 WalletConnect 将不可用。'
  String get walletConnectProjectIdDeleteWithoutBuild =>
      '构建时也没有 Project ID，删除后 WalletConnect 将不可用。';

  /// zh: '断开活跃会话'
  String get walletConnectProjectIdDisconnectTitle => '断开活跃会话';

  /// zh: '更换 Project ID 前需要先断开所有活跃的 WalletConnect 会话。'
  String get walletConnectProjectIdDisconnectBody =>
      '更换 Project ID 前需要先断开所有活跃的 WalletConnect 会话。';

  /// zh: '无法断开全部会话，Project ID 未修改。'
  String get walletConnectProjectIdDisconnectFailed =>
      '无法断开全部会话，Project ID 未修改。';

  /// zh: 'WalletConnect 初始化失败'
  String get walletConnectInitializeFailed => 'WalletConnect 初始化失败';

  /// zh: 'WalletConnect URI 无效'
  String get walletConnectInvalidUri => 'WalletConnect URI 无效';

  /// zh: '该 WalletConnect URI 已处理'
  String get walletConnectDuplicateUri => '该 WalletConnect URI 已处理';

  /// zh: '无法发起 WalletConnect 配对'
  String get walletConnectPairFailed => '无法发起 WalletConnect 配对';

  /// zh: '已收到配对请求'
  String get walletConnectPairStarted => '已收到配对请求';

  /// zh: '断开连接'
  String get walletConnectDisconnect => '断开连接';

  /// zh: '断开会话'
  String get walletConnectDisconnectTitle => '断开会话';

  /// zh: '断开后，该 dApp 将无法再向此钱包发起签名请求。'
  String get walletConnectDisconnectBody => '断开后，该 dApp 将无法再向此钱包发起签名请求。';

  /// zh: '断开全部会话'
  String get walletConnectDisconnectAll => '断开全部会话';

  /// zh: '断开全部会话'
  String get walletConnectDisconnectAllTitle => '断开全部会话';

  /// zh: '确定断开所有活跃的 WalletConnect 会话吗？'
  String get walletConnectDisconnectAllBody => '确定断开所有活跃的 WalletConnect 会话吗？';

  /// zh: '到期时间：$date'
  String walletConnectExpires({required Object date}) => '到期时间：${date}';

  /// zh: '账户'
  String get walletConnectAccounts => '账户';

  /// zh: '网络'
  String get walletConnectNetworks => '网络';

  /// zh: '权限'
  String get walletConnectMethods => '权限';

  /// zh: '连接请求'
  String get walletConnectProposalTitle => '连接请求';

  /// zh: '钱包账户'
  String get walletConnectProposalAccounts => '钱包账户';

  /// zh: '请求的网络'
  String get walletConnectProposalNetworks => '请求的网络';

  /// zh: '请求的权限'
  String get walletConnectProposalMethods => '请求的权限';

  /// zh: '请求的事件'
  String get walletConnectProposalEvents => '请求的事件';

  /// zh: 'WalletConnect Verify 已验证该域名。'
  String get walletConnectVerifyValid => 'WalletConnect Verify 已验证该域名。';

  /// zh: '域名不匹配：验证到的请求来源与发送方不一致。'
  String get walletConnectVerifyInvalid => '域名不匹配：验证到的请求来源与发送方不一致。';

  /// zh: '安全风险：该域名已被标记为恶意站点。'
  String get walletConnectVerifyScam => '安全风险：该域名已被标记为恶意站点。';

  /// zh: '无法验证请求来源，请在连接前仔细核对。'
  String get walletConnectVerifyUnknown => '无法验证请求来源，请在连接前仔细核对。';

  /// zh: '该请求包含不支持的必选网络或权限。'
  String get walletConnectUnsupportedProposal => '该请求包含不支持的必选网络或权限。';

  /// zh: '连接'
  String get walletConnectApprove => '连接';

  /// zh: '拒绝'
  String get walletConnectReject => '拒绝';

  /// zh: '扫描 WalletConnect 二维码'
  String get walletConnectCameraTitle => '扫描 WalletConnect 二维码';

  /// zh: '当前钱包没有可用的 EVM 地址。'
  String get walletRequired => '当前钱包没有可用的 EVM 地址。';

  /// zh: '合约地址'
  String get contractAddress => '合约地址';

  /// zh: '调用方式'
  String get callMode => '调用方式';

  /// zh: '标准 ABI'
  String get modeStandard => '标准 ABI';

  /// zh: '粘贴 ABI'
  String get modeCustomAbi => '粘贴 ABI';

  /// zh: '手动函数'
  String get modeManual => '手动函数';

  /// zh: '原始 calldata'
  String get modeRaw => '原始 calldata';

  /// zh: '标准合约模板'
  String get standardTemplate => '标准合约模板';

  /// zh: 'ERC-20'
  String get erc20 => 'ERC-20';

  /// zh: 'ERC-721'
  String get erc721 => 'ERC-721';

  /// zh: 'ERC-1155'
  String get erc1155 => 'ERC-1155';

  /// zh: 'ABI JSON'
  String get abiJson => 'ABI JSON';

  /// zh: '解析 ABI'
  String get parseAbi => '解析 ABI';

  /// zh: '函数签名，例如 balanceOf(address)'
  String get manualSignature => '函数签名，例如 balanceOf(address)';

  /// zh: '返回类型，多个用逗号分隔'
  String get outputTypes => '返回类型，多个用逗号分隔';

  /// zh: '只读函数'
  String get readFunction => '只读函数';

  /// zh: '允许附带原生币'
  String get payableFunction => '允许附带原生币';

  /// zh: '生成函数'
  String get buildFunction => '生成函数';

  /// zh: '函数'
  String get function => '函数';

  /// zh: '读取'
  String get readBadge => '读取';

  /// zh: '写入'
  String get writeBadge => '写入';

  /// zh: '参数 $index：$name ($type)'
  String argument({
    required Object index,
    required Object name,
    required Object type,
  }) => '参数 ${index}：${name} (${type})';

  /// zh: '数组和 tuple 请输入 JSON'
  String get arrayArgumentHint => '数组和 tuple 请输入 JSON';

  /// zh: 'Calldata（0x 开头）'
  String get rawCalldata => 'Calldata（0x 开头）';

  /// zh: '将原始 calldata 作为写入交易'
  String get rawWrite => '将原始 calldata 作为写入交易';

  /// zh: '附带原生币数量'
  String get nativeValue => '附带原生币数量';

  /// zh: '读取合约'
  String get executeRead => '读取合约';

  /// zh: '检查并准备写入'
  String get prepareWrite => '检查并准备写入';

  /// zh: '调用结果'
  String get result => '调用结果';

  /// zh: '复制调用结果'
  String get copyResult => '复制调用结果';

  /// zh: '调用结果已复制'
  String get resultCopied => '调用结果已复制';

  /// zh: '原始返回值'
  String get rawResult => '原始返回值';

  /// zh: '交易 Hash'
  String get transactionHash => '交易 Hash';

  /// zh: '合约写入可能转移资产或授权第三方。签名前请仔细核对合约地址、函数、参数和 calldata。'
  String get writeRisk => '合约写入可能转移资产或授权第三方。签名前请仔细核对合约地址、函数、参数和 calldata。';

  /// zh: '确认合约写入'
  String get confirmWriteTitle => '确认合约写入';

  /// zh: '网络'
  String get chain => '网络';

  /// zh: '方法'
  String get method => '方法';

  /// zh: '原生币'
  String get value => '原生币';

  /// zh: 'Gas Limit'
  String get gasLimit => 'Gas Limit';

  /// zh: 'Gas Price'
  String get gasPrice => 'Gas Price';

  /// zh: '预计手续费'
  String get estimatedFee => '预计手续费';

  /// zh: '确认并签名'
  String get confirmAndSign => '确认并签名';

  /// zh: 'ABI 格式无效'
  String get invalidAbi => 'ABI 格式无效';

  /// zh: '请检查合约地址、函数参数和 calldata'
  String get invalidInput => '请检查合约地址、函数参数和 calldata';

  /// zh: '该地址未检测到合约代码'
  String get notContract => '该地址未检测到合约代码';

  /// zh: '合约调用失败'
  String get callFailed => '合约调用失败';

  /// zh: '需要解锁钱包才能签名'
  String get walletLocked => '需要解锁钱包才能签名';

  /// zh: '合约交易已提交'
  String get submitted => '合约交易已提交';
}

// Path: about
class Translations$about$zh {
  Translations$about$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '关于'
  String get title => '关于';

  /// zh: '非托管多链钱包'
  String get tagline => '非托管多链钱包';

  /// zh: '版本 $version（Build $buildNumber）'
  String version({required Object version, required Object buildNumber}) =>
      '版本 ${version}（Build ${buildNumber}）';

  /// zh: '版本与更新'
  String get versionAndUpdates => '版本与更新';

  /// zh: '检查更新'
  String get checkUpdate => '检查更新';

  /// zh: '正在检查…'
  String get checkingUpdate => '正在检查…';

  /// zh: '更新日志'
  String get releaseNotes => '更新日志';

  /// zh: 'GitHub'
  String get github => 'GitHub';

  /// zh: '透明与安全'
  String get transparencyAndSecurity => '透明与安全';

  /// zh: '数据与网络说明'
  String get dataAndNetwork => '数据与网络说明';

  /// zh: '开源软件许可'
  String get openSourceLicenses => '开源软件许可';

  /// zh: '帮助与法律'
  String get helpAndLegal => '帮助与法律';

  /// zh: '问题反馈'
  String get feedback => '问题反馈';

  /// zh: '隐私政策'
  String get privacyPolicy => '隐私政策';

  /// zh: '使用条款'
  String get termsOfUse => '使用条款';

  /// zh: '无法打开链接，请稍后重试'
  String get openLinkFailed => '无法打开链接，请稍后重试';

  /// zh: '检查更新失败，请稍后重试'
  String get checkUpdateFailed => '检查更新失败，请稍后重试';

  /// zh: '发现新版本 $version'
  String updateAvailableTitle({required Object version}) => '发现新版本 ${version}';

  /// zh: '已是最新版本'
  String get latestVersionTitle => '已是最新版本';

  /// zh: '当前安装的版本已经是最新版本。'
  String get latestVersionBody => '当前安装的版本已经是最新版本。';

  /// zh: '暂未发现可用更新'
  String get noReleaseTitle => '暂未发现可用更新';

  /// zh: 'GitHub 暂无可用的正式发布版本。'
  String get noReleaseBody => 'GitHub 暂无可用的正式发布版本。';

  /// zh: '当前版本：$version'
  String currentVersion({required Object version}) => '当前版本：${version}';

  /// zh: '发布时间：$date'
  String publishedAt({required Object date}) => '发布时间：${date}';

  /// zh: '本次发布暂无更新说明。'
  String get releaseNotesEmpty => '本次发布暂无更新说明。';

  /// zh: '前往更新'
  String get goToUpdate => '前往更新';

  /// zh: '关闭'
  String get close => '关闭';

  /// zh: '本地密钥与数据'
  String get dataLocalTitle => '本地密钥与数据';

  /// zh: '助记词和私钥经过加密后保存在本机。Safe Wallet 无法替你找回助记词、私钥或钱包密码。'
  String get dataLocalBody => '助记词和私钥经过加密后保存在本机。Safe Wallet 无法替你找回助记词、私钥或钱包密码。';

  /// zh: '不依赖自建私有后端'
  String get backendTitle => '不依赖自建私有后端';

  /// zh: 'Safe Wallet 不依赖自建账户系统或私有后端。资产、交易和链上操作会直接请求你选择的 RPC 节点。'
  String get backendBody =>
      'Safe Wallet 不依赖自建账户系统或私有后端。资产、交易和链上操作会直接请求你选择的 RPC 节点。';

  /// zh: '外部网络服务'
  String get servicesTitle => '外部网络服务';

  /// zh: '应用会按功能访问 RPC 节点、Chainlist、CoinGecko、DefiLlama、Jupiter、DexScreener、Frankfurter 和 GitHub。第三方 dApp 与服务受其各自隐私政策约束。'
  String get servicesBody =>
      '应用会按功能访问 RPC 节点、Chainlist、CoinGecko、DefiLlama、Jupiter、DexScreener、Frankfurter 和 GitHub。第三方 dApp 与服务受其各自隐私政策约束。';

  /// zh: '无广告与行为追踪'
  String get analyticsTitle => '无广告与行为追踪';

  /// zh: '当前版本未接入广告、行为分析或崩溃上报 SDK。你访问的 dApp、RPC 节点和第三方数据服务可能自行记录网络请求。'
  String get analyticsBody =>
      '当前版本未接入广告、行为分析或崩溃上报 SDK。你访问的 dApp、RPC 节点和第三方数据服务可能自行记录网络请求。';

  /// zh: '钱包密钥、钱包账户和地址簿等数据保存在本机；敏感密钥会加密存储。'
  String get privacyLocalBody => '钱包密钥、钱包账户和地址簿等数据保存在本机；敏感密钥会加密存储。';

  /// zh: '为获取余额、价格、交易状态、网络配置和更新信息，应用会向所选 RPC 及公开数据服务发送必要的网络请求。'
  String get privacyNetworkBody =>
      '为获取余额、价格、交易状态、网络配置和更新信息，应用会向所选 RPC 及公开数据服务发送必要的网络请求。';

  /// zh: '当前版本不包含广告或行为分析 SDK，也不会向 Safe Wallet 自建服务器上传助记词、私钥或钱包密码。'
  String get privacyNoAnalyticsBody =>
      '当前版本不包含广告或行为分析 SDK，也不会向 Safe Wallet 自建服务器上传助记词、私钥或钱包密码。';

  /// zh: '使用 dApp、RPC 或第三方数据服务时，对方可能依据其隐私政策处理 IP 地址、钱包地址和请求内容。'
  String get privacyThirdPartyBody =>
      '使用 dApp、RPC 或第三方数据服务时，对方可能依据其隐私政策处理 IP 地址、钱包地址和请求内容。';

  /// zh: '如果未来的数据处理方式发生变化，本说明将随版本更新。'
  String get privacyChangeBody => '如果未来的数据处理方式发生变化，本说明将随版本更新。';

  /// zh: 'Safe Wallet 是非托管钱包。你需要自行保管助记词、私钥和钱包密码，遗失后无法由开发者恢复。'
  String get termsSelfCustodyBody =>
      'Safe Wallet 是非托管钱包。你需要自行保管助记词、私钥和钱包密码，遗失后无法由开发者恢复。';

  /// zh: '区块链交易通常不可撤销。提交前请核对地址、网络、金额和手续费。'
  String get termsTransactionBody => '区块链交易通常不可撤销。提交前请核对地址、网络、金额和手续费。';

  /// zh: '数字资产价格和链上应用存在风险，本应用提供的内容不构成投资、法律或税务建议。'
  String get termsRiskBody => '数字资产价格和链上应用存在风险，本应用提供的内容不构成投资、法律或税务建议。';

  /// zh: 'RPC、dApp、代币和第三方服务由相应提供方负责，Safe Wallet 不控制其可用性或内容。'
  String get termsThirdPartyBody =>
      'RPC、dApp、代币和第三方服务由相应提供方负责，Safe Wallet 不控制其可用性或内容。';

  /// zh: '本软件按现状提供。在适用法律允许的范围内，使用者需自行承担使用风险。'
  String get termsWarrantyBody => '本软件按现状提供。在适用法律允许的范围内，使用者需自行承担使用风险。';
}

// Path: errors
class Translations$errors$zh {
  Translations$errors$zh.internal(this._root);

  final Translations _root; // ignore: unused_field

  // Translations

  /// zh: '操作失败，请稍后重试'
  String get unknown => '操作失败，请稍后重试';

  /// zh: '钱包已锁定，请先解锁'
  String get walletLocked => '钱包已锁定，请先解锁';

  /// zh: '助记词格式或校验和无效'
  String get invalidMnemonic => '助记词格式或校验和无效';

  /// zh: '私钥格式无效'
  String get invalidPrivateKey => '私钥格式无效';

  /// zh: '密码错误次数过多，请稍后再试'
  String get passwordAttemptLocked => '密码错误次数过多，请稍后再试';

  /// zh: '钱包密码至少需要 8 个字符'
  String get walletPasswordTooShort => '钱包密码至少需要 8 个字符';

  /// zh: '该密码过于常见，请使用更难猜的密码'
  String get walletPasswordTooWeak => '该密码过于常见，请使用更难猜的密码';

  /// zh: 'RPC URL 格式无效'
  String get invalidRpcUrl => 'RPC URL 格式无效';

  /// zh: 'RPC 节点不可用，请检查地址或网络'
  String get rpcUnavailable => 'RPC 节点不可用，请检查地址或网络';

  /// zh: 'RPC 凭据缺失，请重新配置节点'
  String get rpcMissingCredential => 'RPC 凭据缺失，请重新配置节点';

  /// zh: 'RPC 凭据无效或已失效'
  String get rpcInvalidCredential => 'RPC 凭据无效或已失效';

  /// zh: 'RPC 拒绝访问，请检查节点权限、IP 或 VPN 设置'
  String get rpcAccessDenied => 'RPC 拒绝访问，请检查节点权限、IP 或 VPN 设置';

  /// zh: 'RPC 请求过于频繁或额度已用尽'
  String get rpcRateLimited => 'RPC 请求过于频繁或额度已用尽';

  /// zh: 'RPC 节点与当前链不匹配'
  String get rpcChainMismatch => 'RPC 节点与当前链不匹配';

  /// zh: '余额查询失败，请检查网络节点'
  String get balanceQueryFailed => '余额查询失败，请检查网络节点';

  /// zh: '手续费估算失败，暂不能发送交易'
  String get feeEstimateFailed => '手续费估算失败，暂不能发送交易';

  /// zh: '交易提交失败，请稍后重试'
  String get transactionBroadcastFailed => '交易提交失败，请稍后重试';

  /// zh: 'Sui Coin 余额不足'
  String get suiInsufficientBalance => 'Sui Coin 余额不足';

  /// zh: 'SUI Gas 余额不足'
  String get suiInsufficientGas => 'SUI Gas 余额不足';

  /// zh: 'Sui Coin 对象已被占用或版本已过期，请刷新后重试'
  String get suiObjectConflict => 'Sui Coin 对象已被占用或版本已过期，请刷新后重试';

  /// zh: 'Sui 交易模拟失败，请刷新余额后重试'
  String get suiSimulationFailed => 'Sui 交易模拟失败，请刷新余额后重试';

  /// zh: '用户已拒绝 dApp 请求'
  String get dappRejected => '用户已拒绝 dApp 请求';

  /// zh: '当前 dApp 方法暂不支持'
  String get dappUnsupportedMethod => '当前 dApp 方法暂不支持';

  /// zh: '该 dApp 尚未授权'
  String get dappUnauthorized => '该 dApp 尚未授权';

  /// zh: '当前链暂不支持'
  String get unsupportedChain => '当前链暂不支持';

  /// zh: '安全校验失败，请重试'
  String get securityCheckFailed => '安全校验失败，请重试';
}

/// The flat map containing all translations for locale <zh>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
  dynamic _flatMapFunction(String path) {
    return switch (path) {
          'app.name' => 'Safe Wallet',
          'tabs.home' => '首页',
          'tabs.browser' => '浏览器',
          'tabs.settings' => '设置',
          'actions.receive' => '接收',
          'actions.send' => '转账',
          'actions.scan' => '扫码',
          'actions.confirm' => '确认',
          'actions.submit' => '提交',
          'actions.cancel' => '取消',
          'actions.kContinue' => '继续',
          'actions.done' => '完成',
          'actions.back' => '返回',
          'actions.close' => '关闭',
          'actions.paste' => '粘贴',
          'actions.exitAppHint' => '再次返回即可退出 App',
          'actions.showPassword' => '显示密码',
          'actions.hidePassword' => '隐藏密码',
          'onboarding.entryTitle' => '安全地开始使用钱包',
          'onboarding.entrySubtitle' => '创建新钱包或导入已有钱包，私钥和助记词只保存在本机加密存储中。',
          'onboarding.createWallet' => '创建钱包',
          'onboarding.importWallet' => '导入钱包',
          'onboarding.createTitle' => '创建新钱包',
          'onboarding.createBody' =>
            '应用会生成一组新的助记词，并派生默认 EVM、Bitcoin、Tron、Solana 和 Sui 地址。',
          'onboarding.riskTitle' => '助记词风险说明',
          'onboarding.riskLoss' => '助记词丢失后无法找回钱包',
          'onboarding.riskResponsibility' =>
            '请自行保存助记词。任何人拿到助记词都可以控制你的资产，应用无法替你恢复或冻结钱包。',
          'onboarding.riskNoBackupGate' => 'MVP 不要求备份校验，但你仍需在进入钱包前理解风险。',
          'onboarding.riskAccepted' => '我已了解风险',
          'onboarding.importTitle' => '导入钱包',
          'onboarding.importBody' =>
            '支持通过助记词、EVM 私钥、Bitcoin 私钥、Tron 私钥、Solana 私钥或 Sui suiprivkey 导入。导入材料会在设置密码后加密保存。',
          'onboarding.importMnemonic' => '助记词',
          'onboarding.importPrivateKey' => '私钥',
          'onboarding.importMnemonicWallet' => '助记词钱包',
          'onboarding.importPrivateKeyWallet' => '私钥钱包',
          'onboarding.importMnemonicWalletDescription' => '多链钱包',
          'onboarding.importPrivateKeyWalletDescription' =>
            'EVM、Bitcoin、Tron、Solana 或 Sui 钱包',
          'onboarding.selectImportType' => '选择导入类型',
          'onboarding.selectPrivateKeyChain' => '选择私钥网络',
          'onboarding.importEvm' => 'EVM',
          'onboarding.importBitcoin' => 'Bitcoin',
          'onboarding.importTron' => 'Tron',
          'onboarding.importSolana' => 'Solana',
          'onboarding.importSui' => 'Sui',
          'onboarding.mnemonicHint' => '请输入助记词，12或24个单词，用空格分隔',
          'onboarding.mnemonicWordHint' => '输入单词',
          'onboarding.mnemonicWordCount12' => '12 个英文单词',
          'onboarding.mnemonicWordCount24' => '24 个英文单词',
          'onboarding.mnemonicHelp' => '如何获取？',
          'onboarding.mnemonicImportHint' => '输入助记词以导入现有钱包',
          'onboarding.privateKeyHint' =>
            '支持 EVM hex、Bitcoin WIF/hex、Solana 私钥或 Sui suiprivkey',
          'onboarding.setPasswordTitle' => '设置钱包密码',
          'onboarding.setPasswordBody' => '该密码用于本机解锁和加密钱包数据。忘记密码后需要重新导入助记词或私钥。',
          'onboarding.passwordLabel' => '钱包密码',
          'onboarding.confirmPasswordLabel' => '确认密码',
          'onboarding.passwordRequired' => '请输入钱包密码',
          'onboarding.passwordMismatch' => '两次输入的密码不一致',
          'onboarding.importMaterialRequired' => '请输入导入内容',
          'onboarding.loadingWallet' => '正在读取钱包',
          'onboarding.creatingWallet' => '正在创建钱包',
          'onboarding.importingWallet' => '正在导入钱包',
          'home.defaultWalletName' => '我的钱包',
          'home.totalValue' => '总资产估值',
          'home.hideAmounts' => '隐藏金额',
          'home.showAmounts' => '显示金额',
          'home.recentTransactions' => '交易记录',
          'home.viewAll' => '查看全部',
          'home.assetList' => '资产列表',
          'home.manageTokens' => '管理代币',
          'home.refreshAssets' => '刷新资产',
          'home.emptyTransactions' => '暂无交易',
          'home.noWallet' => '尚未创建钱包',
          'home.walletLocked' => '钱包已锁定',
          'home.loadingAssets' => '资产加载中',
          'home.emptyAssets' => '暂无资产',
          'home.assetLoadError' => '资产加载失败',
          'browser.commonDapps' => '常用 dApp',
          'browser.urlHint' => '搜索 dApp 或输入 URL',
          'browser.invalidUrl' => '请输入有效网址',
          'browser.loadFailed' => '无法打开 dApp，请检查网址或网络后重试',
          'browser.confirmExternalTitle' => '确认打开网站',
          'browser.confirmExternalBody' => '请确认即将打开的网站域名，避免误入伪装站点。',
          'browser.openExternal' => '打开',
          'browser.swap' => 'Swap',
          'browser.predictions' => 'Predictions',
          'browser.staking' => 'Staking',
          'browser.bridge' => 'Bridge',
          'browser.swapAggregator' => '聚合器',
          'browser.swapDex' => 'DEX',
          'browser.swapMeme' => 'Meme',
          'browser.swapCrossChain' => '跨链',
          'browser.riskHigh' => '高风险',
          'browser.all' => '全部',
          'browser.networkFilter' => '网络',
          'browser.typeFilter' => '类型',
          'browser.allNetworks' => '全部网络',
          'browser.allTypes' => '全部类型',
          'browser.selectNetwork' => '选择网络',
          'browser.selectType' => '选择类型',
          'browser.defi' => 'DeFi',
          'browser.nft' => 'NFT',
          'browser.tools' => '工具',
          'browser.favorites' => '收藏',
          'browser.recent' => '最近',
          'browser.emptyFavorites' => '暂无收藏',
          'browser.emptyRecent' => '暂无访问记录',
          'browser.noResults' => '未找到匹配的 dApp',
          'browser.favorite' => '收藏',
          'browser.unfavorite' => '取消收藏',
          'browser.forward' => '前进',
          'browser.refresh' => '刷新',
          'dapp.authorizationTitle' => '连接 dApp',
          'dapp.authorizationBody' => '授权后，该站点可以读取当前账户地址并请求签名或交易确认。',
          'dapp.rememberAuthorization' => '记住该站点 30 天',
          'dapp.signatureTitle' => '确认签名',
          'dapp.transactionTitle' => '确认交易',
          'dapp.chainSwitchTitle' => '切换网络',
          'dapp.chainSwitchBody' => '该站点请求切换当前 EVM 网络，请确认后继续。',
          'dapp.domain' => '域名',
          'dapp.chain' => '网络',
          'dapp.requestedChain' => '目标网络',
          'dapp.account' => '账户',
          'dapp.from' => '发送方',
          'dapp.to' => '接收方',
          'dapp.value' => '金额',
          'dapp.contract' => '合约',
          'dapp.feeEstimate' => '预估手续费',
          'dapp.decodedInfo' => '解析信息',
          'dapp.rawTransactionData' => '原始交易数据',
          'dapp.message' => '签名内容',
          'dapp.approve' => '批准',
          'dapp.reject' => '拒绝',
          'dapp.signatureRiskWarning' => '签名前请确认内容来自可信站点。签名可能代表登录、授权或其他链下声明。',
          'dapp.unreadableSignatureWarning' => '该签名内容不可读，请仅在完全信任该站点时继续。',
          'dapp.unparsedTransactionWarning' => '该交易包含无法解析的合约调用，请仔细核对站点和合约地址。',
          'dapp.simulationFailedWarning' =>
            ({required Object reason}) => '交易仿真失败：${reason}',
          'dapp.solanaTestTitle' => 'Solana dApp 测试',
          'dapp.solanaTestBody' => '该内部页面用于验证 Solana dApp 接口边界，外部完整适配将在后续版本提供。',
          'dapp.solanaBoundaryReserved' => 'Solana dApp 接口预留',
          'dapp.solanaConnectCheck' => '连接请求边界已预留',
          'dapp.solanaSignCheck' => '消息签名边界已预留',
          'dapp.solanaTransactionCheck' => '交易请求边界已预留',
          'dapp.solanaNonSolanaChain' => '当前未选择 Solana 网络',
          'dapp.solanaUnavailable' => '暂无 Solana 地址',
          'chains.network' => '网络',
          'chains.selectorTitle' => '选择网络',
          'chains.addNetwork' => '添加网络',
          'chains.addCustom' => '添加自定义',
          'chains.addCustomEvm' => '新增 EVM 网络',
          'chains.searchNetworkHint' => '搜索网络',
          'chains.emptySearch' => '暂无可添加网络',
          'chains.removeNetwork' => '移除网络',
          'chains.removeNetworkTitle' => '移除网络',
          'chains.removeNetworkMessage' => '移除后该网络将不再显示，相关自定义配置不会继续使用。',
          'chains.confirmRemoveNetwork' => '确认移除',
          'chains.nameLabel' => '网络名称',
          'chains.chainIdLabel' => 'Chain ID',
          'chains.rpcUrlLabel' => 'RPC URL',
          'chains.symbolLabel' => '原生币符号',
          'chains.blockExplorerLabel' => '区块浏览器 URL',
          'chains.testnetLabel' => '测试网',
          'chains.nameRequired' => '请输入网络名称',
          'chains.chainIdRequired' => '请输入 Chain ID',
          'chains.invalidChainId' => '请输入有效 Chain ID',
          'chains.rpcUrlRequired' => '请输入 RPC URL',
          'chains.invalidRpcUrl' => '请输入有效 RPC URL',
          'chains.symbolRequired' => '请输入原生币符号',
          'chains.invalidBlockExplorerUrl' => '请输入有效区块浏览器 URL',
          'chains.duplicateChainId' => '该 Chain ID 已存在',
          'chains.current' => '当前',
          'chains.mainnet' => '主网',
          'chains.testnet' => '测试网',
          'chains.loading' => '正在读取网络',
          'chains.loadFailed' => '网络列表读取失败',
          'nodes.managementTitle' => 'RPC 节点',
          'nodes.addNode' => '新增节点',
          'nodes.editNode' => '编辑节点',
          'nodes.defaultNode' => '默认',
          'nodes.chainlistNode' => 'Chainlist',
          'nodes.customNode' => '自定义',
          'nodes.selected' => '已选',
          'nodes.select' => '选择',
          'nodes.test' => '测试',
          'nodes.delete' => '删除',
          'nodes.deleteTitle' => '删除节点',
          'nodes.deleteMessage' => '删除后该自定义 RPC 节点将不再可用。',
          'nodes.confirmDelete' => '确认删除',
          'nodes.save' => '保存',
          'nodes.nameLabel' => '节点名称',
          'nodes.urlLabel' => 'URL',
          'nodes.providerLabel' => '服务商',
          'nodes.customProvider' => '自定义',
          'nodes.apiKeyLabel' => 'API Key',
          'nodes.authModeLabel' => '鉴权方式',
          'nodes.authNone' => '无需参数',
          'nodes.authQuery' => 'Query 参数',
          'nodes.authPath' => 'Path 参数',
          'nodes.authHeader' => 'HTTP Header',
          'nodes.credentialParameterLabel' => '凭据参数名',
          'nodes.credentialRequired' => '请输入节点凭据',
          'nodes.credentialKeepHint' => '留空则保留现有凭据',
          'nodes.urlKeepHint' => '留空则保留现有 URL',
          'nodes.providerUnsupported' => '该服务商暂不支持当前网络',
          'nodes.noteLabel' => '备注',
          'nodes.nameRequired' => '请输入节点名称',
          'nodes.urlRequired' => '请输入 URL',
          'nodes.statusUntested' => '未测试',
          'nodes.statusTesting' => '测试中',
          'nodes.statusAvailable' => '可用',
          'nodes.statusUnavailable' => '不可用',
          'nodes.blockHeightPrefix' => '区块',
          'nodes.latencyMsSuffix' => 'ms',
          'nodes.trackingNone' => '无追踪',
          'nodes.trackingYes' => '有追踪',
          'nodes.trackingUnknown' => '追踪未知',
          'nodes.loadFailed' => '节点列表读取失败',
          'nodes.empty' => '暂无节点',
          'tokens.managementTitle' => '代币管理',
          'tokens.addToken' => '添加代币',
          'tokens.addCustomToken' => '添加自定义',
          'tokens.searchTokenHint' => '搜索代币名称、符号或合约地址',
          'tokens.emptySearch' => '未找到匹配的代币',
          'tokens.runDiscovery' => '发现代币',
          'tokens.discovering' => '发现中',
          'tokens.discoverySuccess' =>
            ({required Object count}) => '已发现 ${count} 个代币',
          'tokens.discoveryEmpty' => '未发现持有的代币',
          'tokens.discoveryFailed' => '代币发现失败，请检查网络节点',
          'tokens.contractAddressLabel' => '合约地址',
          'tokens.symbolLabel' => '代币符号',
          'tokens.nameLabel' => '代币名称',
          'tokens.decimalsLabel' => '精度',
          'tokens.contractAddressRequired' => '请输入合约地址',
          'tokens.invalidContractAddress' => '请输入有效合约地址',
          'tokens.metadataRequired' => '请输入代币名称和符号',
          'tokens.invalidDecimals' => '请输入有效精度',
          'tokens.hide' => '隐藏',
          'tokens.unhide' => '取消隐藏',
          'tokens.builtIn' => '内置',
          'tokens.userAdded' => '手动',
          'tokens.discovered' => '发现',
          'tokens.hidden' => '已隐藏',
          'tokens.empty' => '暂无代币',
          'tokens.loadFailed' => '代币列表读取失败',
          'assets.detailTitle' => '资产详情',
          'assets.network' => '网络',
          'assets.balance' => '余额',
          'assets.fiatValue' => '估值',
          'assets.contractAddress' => '合约地址',
          'assets.nativeAsset' => '原生资产',
          'assets.currentPrice' => '当前价格',
          'assets.change24h' => '24h 涨跌',
          'assets.marketOverview' => '市场概览',
          'assets.volume24h' => '24h 成交额',
          'assets.liquidity' => '流动性',
          'assets.marketCap' => '市值',
          'assets.fdv' => 'FDV',
          'assets.transactions24h' => '24h 买入 / 卖出',
          'assets.primaryPair' => '主要交易对',
          'assets.viewOnDexScreener' => '在 DexScreener 查看',
          'assets.marketDataUnavailable' => '暂无市场数据',
          'assets.marketDataSource' => '数据来源：DexScreener',
          'assets.updatedAt' => '更新于',
          'assets.pairCreatedAt' => '交易池创建于',
          'assets.lowLiquidityWarning' => '该交易池流动性较低，市场价格可能出现较大波动。',
          'assets.priceDivergenceWarning' => '钱包估值价格与 DEX 市场价格存在明显偏差。',
          'transactions.historyTitle' => '交易历史',
          'transactions.empty' => '暂无交易记录',
          'transactions.loadFailed' => '交易记录读取失败',
          'transactions.submitting' => '提交中',
          'transactions.submitted' => '已提交',
          'transactions.success' => '成功',
          'transactions.failed' => '失败',
          'transactions.incoming' => '接收',
          'transactions.outgoing' => '转账',
          'transactions.operationWrap' => '封装原生币',
          'transactions.operationUnwrap' => '解封装原生币',
          'transactions.operationStake' => '质押 TRX',
          'transactions.operationUnstake' => '解押 TRX',
          'transactions.operationWithdrawUnfreeze' => '提取已解押 TRX',
          'transactions.operationCancelUnfreeze' => '取消全部解押',
          'transactions.operationDelegateResource' => '委托 TRON 资源',
          'transactions.operationUndelegateResource' => '取消委托 TRON 资源',
          'transactions.operationVote' => '超级代表投票',
          'transactions.operationClaimReward' => '领取投票奖励',
          'transactions.viewMoreOnExplorer' => '在区块浏览器中查看更多',
          'transfer.title' => '转账',
          'transfer.confirmTitle' => '确认转账',
          'transfer.resultTitle' => '转账结果',
          'transfer.copyTransactionHash' => '复制交易哈希',
          'transfer.viewTransactionExplorer' => '区块浏览器查看',
          'transfer.transactionHashCopied' => '交易哈希已复制',
          'transfer.selectedAsset' => '选择资产',
          'transfer.hideZeroBalances' => '隐藏 0 余额资产',
          'transfer.recipientLabel' => '收款地址',
          'transfer.amountLabel' => '金额',
          'transfer.memoLabel' => '备注 / Tag',
          'transfer.memoOptionalHelper' => '可选。仅在收款方要求时填写。',
          'transfer.memoRequiredLabel' => '备注 / Tag',
          'transfer.memoRequiredHelper' => '该资产转账必须填写。',
          'transfer.selectContact' => '选择联系人',
          'transfer.max' => '最大',
          'transfer.next' => '下一步',
          'transfer.balance' => '余额',
          'transfer.noAssets' => '暂无可转账资产',
          'transfer.walletLocked' => '钱包已锁定',
          'transfer.invalidAddress' => '收款地址格式无效',
          'transfer.invalidAmount' => '请输入大于 0 的金额',
          'transfer.insufficientBalance' => '余额不足',
          'transfer.unavailableBalance' => '资产余额不可用',
          'transfer.memoRequired' => '请输入必填的 Memo / Tag',
          'transfer.feeFailed' => '手续费估算失败，暂不能继续',
          'transfer.chain' => '网络',
          'transfer.from' => '发送方',
          'transfer.to' => '接收方',
          'transfer.token' => '资产',
          'transfer.amount' => '金额',
          'transfer.fee' => '手续费',
          'transfer.estimatedFee' => '预计手续费',
          'transfer.maximumFee' => '最高手续费',
          'transfer.feeSettings' => '手续费设置',
          'transfer.feeEconomy' => '省钱',
          'transfer.feeEconomyHint' => '费用较低，确认可能较慢',
          'transfer.feeStandard' => '标准',
          'transfer.feeStandardHint' => '费用和确认速度均衡',
          'transfer.feeFast' => '快速',
          'transfer.feeFastHint' => '费用较高，优先确认',
          'transfer.feeCustom' => '自定义',
          'transfer.feeCustomHint' => '手动设置链上手续费参数',
          'transfer.maxFeeGwei' => '最大费率 (Gwei)',
          'transfer.priorityFeeGwei' => '优先费率 (Gwei)',
          'transfer.gasPriceGwei' => 'Gas Price (Gwei)',
          'transfer.priorityFeeSol' => '总优先费 (SOL)',
          'transfer.bitcoinFeeRate' => '费率 (sat/vB)',
          'transfer.estimatedConfirmation' => '预计确认',
          'transfer.approximately' => '约',
          'transfer.blocks' => '个区块',
          'transfer.tronFeeLimit' => '最大可燃烧 TRX',
          'transfer.applyFee' => '应用手续费',
          'transfer.invalidFee' => '请输入有效的手续费',
          'transfer.maxFeeBelowPriority' => '最大费率不能低于优先费率',
          'transfer.feeLimitBelowEstimate' => '最大可燃烧 TRX 不能低于预计手续费',
          'transfer.feeTooLow' => '当前费率低于网络基础费用，交易可能长时间无法确认',
          'transfer.feeVeryHigh' => '当前手续费明显高于网络建议值，请确认后继续',
          'transfer.feeModel' => '手续费模型',
          'transfer.feeModelEip1559' => 'EIP-1559',
          'transfer.feeModelLegacy' => 'Legacy Gas Price',
          'transfer.feeModelBitcoin' => 'Bitcoin 手续费',
          'transfer.feeModelTron' => 'Tron 手续费',
          'transfer.feeModelSolana' => 'Solana Fee',
          'transfer.feeModelSui' => 'Sui Gas 费',
          'transfer.maxFeePerGas' => '最大 Gas 费率',
          'transfer.maxPriorityFeePerGas' => '优先费率',
          'transfer.gasPrice' => 'Gas Price',
          'transfer.totalDeduction' => '总扣款',
          'transfer.newRecipientWarning' => '这是一个从未转账过的新地址，请核对完整地址和收款网络。',
          'transfer.lookalikeRecipientWarning' =>
            ({required Object address}) =>
                '该地址与历史收款地址高度相似但并不相同，可能是地址投毒。相似历史地址：${address}',
          'transfer.contractAddress' => '合约地址',
          'transfer.riskWarnings' => '风险提示',
          'transfer.riskLegacy' => '当前网络使用 Legacy 手续费模型，请确认手续费后再签名。',
          'transfer.riskErc20' => '这是合约代币转账，请确认合约地址和收款地址。',
          'transfer.scanTitle' => '扫码',
          'transfer.scanInstruction' => '扫描钱包地址二维码，识别后会填入转账收款地址。',
          'transfer.scanInvalid' => '二维码内容不是有效地址',
          'transfer.scanSuccess' => '地址已识别',
          'transfer.scanCameraPermissionDenied' => '需要相机权限才能扫码',
          'transfer.scanCameraUnsupported' => '当前设备不支持扫码',
          'transfer.scanCameraError' => '相机启动失败，请稍后重试',
          'addressBook.managementTitle' => '地址簿',
          'addressBook.addContact' => '新增联系人',
          'addressBook.editContact' => '编辑联系人',
          'addressBook.delete' => '删除',
          'addressBook.save' => '保存',
          'addressBook.nameLabel' => '联系人名称',
          'addressBook.addressLabel' => '钱包地址',
          'addressBook.noteLabel' => '备注',
          'addressBook.chainTypeLabel' => '链类型',
          'addressBook.evm' => 'EVM',
          'addressBook.bitcoin' => 'Bitcoin',
          'addressBook.tron' => 'Tron',
          'addressBook.solana' => 'Solana',
          'addressBook.sui' => 'Sui',
          'addressBook.nameRequired' => '请输入联系人名称',
          'addressBook.addressRequired' => '请输入钱包地址',
          'addressBook.invalidAddress' => '地址格式与链类型不匹配',
          'addressBook.deleteTitle' => '删除联系人',
          'addressBook.deleteMessage' => '删除后无法从地址簿中选择该联系人。',
          'addressBook.confirmDelete' => '确认删除',
          'addressBook.empty' => '暂无联系人',
          'addressBook.loadFailed' => '联系人列表读取失败',
          'addressBook.pickTitle' => '选择联系人',
          'addressBook.otherWallets' => '其他钱包',
          'addressBook.contacts' => '地址簿联系人',
          'addressBook.noContactsForChain' => '当前链暂无可选联系人',
          'wallet.create' => '创建钱包',
          'wallet.import' => '导入钱包',
          'wallet.view' => '查看',
          'wallet.mnemonicWallet' => '助记词',
          'wallet.privateKeyWallet' => '私钥',
          'wallet.moreActions' => '更多操作',
          'wallet.copyEvm' => '复制 EVM 地址',
          'wallet.copyBtc' => '复制 BTC 地址',
          'wallet.copySolana' => '复制 Solana 地址',
          'wallet.copySui' => '复制 Sui 地址',
          'wallet.receiveQr' => '接收二维码',
          'wallet.receiveQrTitle' =>
            ({required Object walletName, required Object chainName}) =>
                '${walletName} - ${chainName}',
          'wallet.copyAddress' => '复制地址',
          'wallet.copy' => '复制',
          'wallet.saveQrImage' => '保存',
          'wallet.amount' => '数量',
          'wallet.enterAmountTitle' => '请输入数量',
          'wallet.amountConfirm' => '确定',
          'wallet.amountApproxPrefix' => '约等于',
          'wallet.usdCode' => 'USD',
          'wallet.noAddressForChain' => '当前钱包没有当前链地址',
          'wallet.qrImageSaved' => '二维码已保存到相册',
          'wallet.qrImagePhotoPermissionRequired' => '需要相册权限才能保存二维码',
          'wallet.qrImageSaveFailed' => '二维码保存失败，请重试',
          'wallet.rename' => '重命名',
          'wallet.changePassword' => '修改密码',
          'wallet.currentPasswordLabel' => '当前钱包密码',
          'wallet.newPasswordLabel' => '新钱包密码',
          'wallet.confirmNewPasswordLabel' => '确认新密码',
          'wallet.newPasswordRequired' => '请输入新钱包密码',
          'wallet.passwordChanged' => '密码已修改',
          'wallet.nameLabel' => '钱包名称',
          'wallet.switchWallet' => '切换钱包',
          'wallet.selected' => '当前',
          'wallet.delete' => '删除',
          'wallet.deleteTitle' => '删除钱包',
          'wallet.deleteMessage' => '删除前必须确认密码。删除后需要重新导入助记词或私钥才能恢复。',
          'wallet.deleteAcknowledge' => '我确认已备份该钱包的助记词或私钥',
          'wallet.deleteRequiresConfirmation' => '请先确认已备份钱包',
          'wallet.exportSecret' => '导出',
          'wallet.exportMnemonic' => '导出助记词',
          'wallet.exportPrivateKey' => '导出私钥',
          'wallet.exportBtcPrivateKey' => '导出 BTC 私钥',
          'wallet.exportSecretWarning' => '高风险操作。请确认周围环境安全，导出的内容不要截图、不要发送给任何人。',
          'wallet.exportPasswordTitle' => '验证钱包密码',
          'wallet.exportPasswordBody' => '输入钱包密码后查看导出内容。',
          'wallet.mnemonicRiskWarning' =>
            '助记词可恢复钱包并控制全部资产。请勿截图、上传云端或发送给任何人；复制后请及时清理剪贴板。',
          'wallet.privateKeyRiskWarning' =>
            '私钥可直接控制对应网络资产。请勿截图、粘贴到不可信应用或发送给任何人；复制后请及时清理剪贴板。',
          'wallet.mnemonicCopied' => '助记词已复制',
          'wallet.privateKeyCopied' => '私钥已复制',
          'wallet.addressCopied' => '地址已复制',
          'wallet.evmAddress' => 'EVM 地址',
          'wallet.btcAddress' => 'BTC 地址',
          'wallet.tronAddress' => 'Tron 地址',
          'wallet.solanaAddress' => 'Solana 地址',
          'wallet.suiAddress' => 'Sui 地址',
          'wallet.unlockTitle' => '解锁钱包',
          'wallet.unlockBody' => '输入本机钱包密码以恢复当前会话。',
          'wallet.unlockButton' => '解锁',
          'wallet.unlocking' => '正在解锁',
          'wallet.signingPasswordTitle' => '验证签名身份',
          'wallet.signingPasswordBody' => '验证身份后继续本次签名操作。',
          'wallet.rememberSigningPassword' => '15 分钟内记住密码',
          'wallet.biometricSetupTitle' => '设置生物识别密码',
          'wallet.biometricSetupBody' => '以后需要钱包密码时，可优先使用指纹或面容验证。',
          'wallet.biometricSetupConfirm' => '设置',
          'wallet.biometricReason' => '验证身份以使用钱包密码',
          'wallet.biometricUseButton' => '使用生物识别',
          'wallet.biometricEnabled' => '生物识别密码已启用',
          'settings.walletManagement' => '钱包管理',
          'settings.networkManagement' => '网络管理',
          'settings.addressBook' => '地址簿',
          'settings.advanced' => '高级',
          'settings.preferences' => '偏好设置',
          'settings.language' => '多语言设置',
          'settings.fiatCurrency' => '货币',
          'settings.fiatCurrencyUsd' => '美元 (USD)',
          'settings.fiatCurrencyCny' => '人民币 (CNY)',
          'settings.fiatCurrencyEur' => '欧元 (EUR)',
          'settings.fiatCurrencyJpy' => '日元 (JPY)',
          'settings.themeMode' => '主题模式',
          'settings.themeModeSystem' => '跟随系统',
          'settings.themeModeLight' => '亮色模式',
          'settings.themeModeDark' => '暗色模式',
          'settings.themeColor' => '主题颜色',
          'settings.themeColorIndigo' => '靛蓝',
          'settings.themeColorBlue' => '蓝色',
          'settings.themeColorPurple' => '紫色',
          'settings.themeColorGreen' => '绿色',
          'settings.themeColorOrange' => '橙色',
          'settings.themeColorRose' => '玫红',
          'settings.themeColorNavy' => '深蓝',
          'settings.security' => '安全设置',
          'settings.about' => '关于',
          'settings.languageSystem' => '跟随系统',
          'settings.languageZh' => '简体中文',
          'settings.languageEn' => 'English',
          'settings.requirePasswordOnLaunch' => '启动时要求密码',
          'settings.requirePasswordOnLaunchSubtitle' => '每次启动 App 时先验证钱包密码',
          'settings.backgroundPrivacyShield' => '后台隐私遮罩',
          'settings.backgroundPrivacyShieldSubtitle' => '进入后台时模糊显示 App 内容',
          'settings.autoLock' => '自动锁定',
          'settings.autoLockSubtitle' => '离开 App 后多久锁定钱包',
          'settings.autoLockImmediately' => '立即',
          'settings.autoLockOneMinute' => '1 分钟',
          'settings.autoLockFiveMinutes' => '5 分钟',
          'settings.autoLockFifteenMinutes' => '15 分钟',
          'settings.autoLockOneHour' => '1 小时',
          'settings.biometricPassword' => '生物识别密码',
          'settings.biometricPasswordSubtitle' => '需要钱包密码时可使用生物识别',
          'settings.biometricPasswordUnavailable' => '当前设备不可用生物识别',
          'settings.biometricPasswordSetupPrompt' => '输入当前钱包密码以启用生物识别密码。',
          'settings.changePasswordSubtitle' => '更新全局钱包密码',
          'settings.securityLog' => '安全日志',
          'settings.securityLogSubtitle' => '自动在本机记录并查看敏感安全操作',
          'settings.securityLogPasswordTitle' => '验证钱包密码',
          'settings.securityLogPasswordBody' => '查看安全日志前，请先验证钱包密码。',
          'settings.securityLogEmpty' => '暂无安全日志',
          'settings.securityLogSafetyNotice' =>
            '安全日志仅记录操作类型、钱包名称、链、公开地址、币种、数量和时间，并只存储在您的设备本地，不会保存私钥、助记词、密码或签名内容。',
          _ => null,
        } ??
        switch (path) {
          'settings.securityLogWalletLabel' => '钱包：',
          'settings.securityLogChainLabel' => '链：',
          'settings.securityLogAmountLabel' => '金额：',
          'settings.securityLogAddressLabel' => '公开地址：',
          'settings.securityLogViewMnemonic' => '查看助记词',
          'settings.securityLogViewPrivateKey' => '查看私钥',
          'settings.securityLogCopyMnemonic' => '复制助记词',
          'settings.securityLogCopyPrivateKey' => '复制私钥',
          'settings.securityLogCreateWallet' => '创建钱包',
          'settings.securityLogImportWallet' => '导入钱包',
          'settings.securityLogDeleteWallet' => '删除钱包',
          'settings.securityLogChangePassword' => '修改密码',
          'settings.securityLogSignMessage' => '消息签名',
          'settings.securityLogSignTransaction' => '交易签名',
          'settings.securityLogWrapNative' => '封装原生币',
          'settings.securityLogUnwrapNative' => '解封装原生币',
          'settings.securityLogSolanaRentRecovery' => 'Solana 租金回收',
          'settings.securityLogTronStake' => 'TRX 质押',
          'settings.securityLogTronUnstake' => 'TRX 解押',
          'settings.securityLogTronWithdrawUnfreeze' => '提取已解押 TRX',
          'settings.securityLogTronCancelUnfreeze' => '取消 TRX 解押',
          'settings.securityLogTronDelegateResource' => '委托 TRON 资源',
          'settings.securityLogTronUndelegateResource' => '取消委托 TRON 资源',
          'settings.securityLogTronVote' => 'TRON 超级代表投票',
          'settings.securityLogTronClaimReward' => '领取 TRON 投票奖励',
          'settings.clearDappPermissions' => '清除 dApp 授权',
          'settings.clearDappPermissionsSubtitle' => '移除站点连接权限',
          'settings.connectedDapps' => '已授权 dApp',
          'settings.noConnectedDapps' => '暂无已授权 dApp',
          'settings.revoke' => '撤销',
          'settings.revokeDappPermission' => '撤销 dApp 授权',
          'settings.revokeDappPermissionSubtitle' => '撤销后，该站点需要重新请求授权才能读取账户地址。',
          'settings.evmNetworks' => 'EVM 网络',
          'settings.bitcoinNetworks' => 'Bitcoin 网络',
          'settings.solanaNetworks' => 'Solana 网络',
          'settings.tronNetworks' => 'Tron 网络',
          'settings.suiNetworks' => 'Sui 网络',
          'settings.currentRpcUnknown' => '当前 RPC 读取中',
          'tronStaking.title' => 'TRX 质押',
          'tronStaking.advancedSubtitle' => '管理 Stake 2.0、资源委托、投票和奖励',
          'tronStaking.wallet' => '钱包',
          'tronStaking.network' => '网络',
          'tronStaking.refresh' => '刷新质押状态',
          'tronStaking.noWallet' => '没有包含 TRON 地址的钱包',
          'tronStaking.noNetwork' => '没有可用的 TRON 网络',
          'tronStaking.loadFailed' => '质押数据加载失败，请检查 TRON 节点后重试',
          'tronStaking.availableBalance' => '可用余额',
          'tronStaking.bandwidthStaked' => 'Bandwidth 质押',
          'tronStaking.energyStaked' => 'Energy 质押',
          'tronStaking.tronPower' => 'TRON Power',
          'tronStaking.availableVotes' => '可用票数',
          'tronStaking.resourceOverview' => '资源',
          'tronStaking.bandwidth' => 'Bandwidth',
          'tronStaking.energy' => 'Energy',
          'tronStaking.availableResource' =>
            ({
              required Object available,
              required Object limit,
              required Object used,
            }) => '可用 ${available} / ${limit} · 已用 ${used}',
          'tronStaking.stake' => '质押',
          'tronStaking.unstake' => '解押',
          'tronStaking.delegate' => '资源委托',
          'tronStaking.vote' => '超级代表投票',
          'tronStaking.stakeTitle' => '质押 TRX',
          'tronStaking.unstakeTitle' => '解押 TRX',
          'tronStaking.delegateTitle' => '委托资源',
          'tronStaking.undelegateTitle' => '取消资源委托',
          'tronStaking.resourceType' => '资源类型',
          'tronStaking.amount' => '数量',
          'tronStaking.amountHint' => '输入 TRX 数量',
          'tronStaking.maximum' => '最大',
          'tronStaking.continueAction' => '继续',
          'tronStaking.invalidAmount' => '请输入有效的 TRX 数量，最多 6 位小数',
          'tronStaking.insufficientBalance' => '可用 TRX 余额不足',
          'tronStaking.insufficientStaked' => '该资源的可解押质押不足',
          'tronStaking.noUnfreezeSlots' => '当前没有可用的解押次数',
          'tronStaking.confirmStake' => '确认质押',
          'tronStaking.confirmUnstake' => '确认解押',
          'tronStaking.confirmDelegate' => '确认资源委托',
          'tronStaking.confirmUndelegate' => '确认取消委托',
          'tronStaking.confirmWithdraw' => '确认提取已解押 TRX',
          'tronStaking.confirmCancel' => '确认取消全部解押',
          'tronStaking.confirmVote' => '确认投票分配',
          'tronStaking.confirmClaimReward' => '确认领取奖励',
          'tronStaking.confirmAndSign' => '确认并签名',
          'tronStaking.owner' => '钱包地址',
          'tronStaking.receiver' => '接收地址',
          'tronStaking.receiverHint' => '输入 TRON 地址',
          'tronStaking.invalidReceiver' => '请输入有效且不同于当前钱包的 TRON 地址',
          'tronStaking.lockResource' => '锁定委托',
          'tronStaking.lockUnsupported' => '当前网络不支持锁定委托',
          'tronStaking.locked' => '已锁定',
          'tronStaking.unlocked' => '不锁定',
          'tronStaking.lockPeriod' => '锁定周期（区块）',
          'tronStaking.lockPeriodHint' =>
            ({required Object max}) => '输入区块数，最多 ${max} 个区块',
          'tronStaking.lockPeriodValue' =>
            ({required Object count}) => '${count} 个区块',
          'tronStaking.estimatedFee' => '预计网络费用',
          'tronStaking.remainingBalance' => '质押后可用余额',
          'tronStaking.feeCalculatedByNetwork' => '根据 Bandwidth 使用情况动态计算',
          'tronStaking.feeEstimateFailed' => '网络费用估算失败，暂不能继续',
          'tronStaking.unstakeDelay' =>
            ({required Object days}) => '解押等待期为 ${days} 天，到期后需要提取',
          'tronStaking.unstakeAvailableAt' =>
            ({required Object date}) => '预计 ${date} 可提取',
          'tronStaking.unfreezeSlotsRemaining' =>
            ({required Object count}) => '剩余可发起解押次数：${count}',
          'tronStaking.pendingUnfreeze' => '解押中',
          'tronStaking.pendingTotal' =>
            ({required Object amount}) => '解押中总额：${amount} TRX',
          'tronStaking.withdrawableAmount' =>
            ({required Object amount}) => '当前可提取：${amount} TRX',
          'tronStaking.nextUnfreezeAt' =>
            ({required Object date}) => '最近到期：${date}',
          'tronStaking.pendingEmpty' => '当前没有解押中的 TRX',
          'tronStaking.expiresAt' => ({required Object date}) => '${date} 到期',
          'tronStaking.withdrawable' => '可提取',
          'tronStaking.withdraw' =>
            ({required Object amount}) => '提取 ${amount} TRX',
          'tronStaking.cancelAll' => '取消全部解押',
          'tronStaking.cancelAllWarning' => '该操作会取消全部未到期解押，协议不支持只取消其中一笔。',
          'tronStaking.delegations' => '资源委托',
          'tronStaking.delegationsEmpty' => '当前没有资源委托记录',
          'tronStaking.delegatedTo' => '已委托给',
          'tronStaking.receivedFrom' => '收到自',
          'tronStaking.undelegate' => '取消委托',
          'tronStaking.witnesses' => '超级代表',
          'tronStaking.witnessSearch' => '搜索地址或 URL',
          'tronStaking.witnessVotes' =>
            ({required Object count}) => '${count} 票',
          'tronStaking.myVotes' => '我的票数',
          'tronStaking.voteSummary' =>
            ({required Object used, required Object total}) =>
                '已分配 ${used} / ${total} 票',
          'tronStaking.clearVotes' => '清空投票',
          'tronStaking.reward' => '可领取奖励',
          'tronStaking.claimReward' => '领取奖励',
          'tronStaking.noReward' => '当前没有可领取奖励',
          'tronStaking.submitting' => '正在提交 TRON 交易…',
          'tronStaking.submitted' => 'TRON 交易已提交',
          'tronStaking.walletLocked' => '需要解锁钱包才能签名',
          'tronStaking.signingKeyUnavailable' => '当前钱包没有可用的 TRON 私钥',
          'tronStaking.nothingToWithdraw' => '当前没有已到期、可提取的 TRX',
          'tronStaking.cancelUnsupported' => '当前网络不支持取消全部解押',
          'tronStaking.nothingToCancel' => '当前没有可取消的解押记录',
          'tronStaking.delegationUnsupported' => '当前网络未启用资源委托',
          'tronStaking.invalidDelegation' => '委托地址或锁定参数无效',
          'tronStaking.insufficientDelegatableBalance' => '当前没有可委托的质押资源',
          'tronStaking.delegationLocked' => '该委托仍在锁定期，到期后才能取消',
          'tronStaking.insufficientDelegatedBalance' => '可取消的委托资源不足',
          'tronStaking.excessiveVotes' => '分配票数超过可用 TRON Power',
          'tronStaking.nothingToClaim' => '当前没有可领取奖励',
          'tronStaking.transactionValidationFailed' => '节点返回的交易未通过本地安全校验',
          'tronStaking.broadcastFailed' => 'TRON 交易提交失败，请刷新链上状态后重试',
          'tronStaking.operationUnavailable' => '当前链上状态不允许执行该操作',
          'advanced.title' => '高级',
          'advanced.contractCall' => '合约调用',
          'advanced.contractCallSubtitle' => '读取合约或签名发起写入调用',
          'advanced.wrappedNative' => '原生币封装',
          'advanced.wrappedNativeSubtitle' => '在原生币与封装代币之间进行 1:1 转换',
          'advanced.wrappedNativeWallet' => '钱包',
          'advanced.wrappedNativeNetwork' => '网络',
          'advanced.wrappedNativeWrap' => '封装',
          'advanced.wrappedNativeUnwrap' => '解封装',
          'advanced.wrappedNativeBalance' => '原生币余额',
          'advanced.wrappedNativeTokenBalance' => '封装代币余额',
          'advanced.wrappedNativeAmount' => '数量',
          'advanced.wrappedNativeAmountHint' => '输入转换数量',
          'advanced.wrappedNativeMax' => '最大',
          'advanced.wrappedNativeReview' => '检查交易',
          'advanced.wrappedNativePreparing' => '正在模拟并估算费用…',
          'advanced.wrappedNativeRefresh' => '刷新余额',
          'advanced.wrappedNativeRisk' =>
            '转换由当前网络的标准封装合约执行，兑换比例为 1:1。请核对网络、数量、手续费和目标代币后再签名。',
          'advanced.wrappedNativeConfirmTitle' => '确认原生币转换',
          'advanced.wrappedNativeFrom' => '支付',
          'advanced.wrappedNativeTo' => '获得',
          'advanced.wrappedNativeNetworkFee' => '最大网络手续费',
          'advanced.wrappedNativeRent' => '账户租金',
          'advanced.wrappedNativeConfirmWrap' => '确认封装',
          'advanced.wrappedNativeConfirmUnwrap' => '确认解封装',
          'advanced.wrappedNativeSubmitting' => '正在签名并提交…',
          'advanced.wrappedNativeSuccessWrap' => '封装交易已提交',
          'advanced.wrappedNativeSuccessUnwrap' => '解封装交易已提交',
          'advanced.wrappedNativeTransactionHash' => '交易 Hash',
          'advanced.wrappedNativeViewExplorer' => '在区块浏览器查看',
          'advanced.wrappedNativeNoWallet' => '没有适用于当前网络的钱包',
          'advanced.wrappedNativeNoNetwork' => '没有支持原生币封装的网络',
          'advanced.wrappedNativeInvalidAmount' => '请输入有效且大于零的数量',
          'advanced.wrappedNativeInsufficientNative' =>
            '原生币余额不足，需同时预留网络手续费和可能的账户租金',
          'advanced.wrappedNativeInsufficientWrapped' => '封装代币余额不足',
          'advanced.wrappedNativeBalanceFailed' => '余额读取失败，请检查 RPC 节点后重试',
          'advanced.wrappedNativePreparationFailed' =>
            '交易模拟或费用估算失败，请检查余额和 RPC 节点',
          'advanced.wrappedNativeWalletLocked' => '需要解锁钱包才能签名',
          'advanced.wrappedNativeSigningKeyUnavailable' => '所选钱包没有当前网络可用的签名私钥',
          'advanced.wrappedNativeSubmissionFailed' => '交易提交失败，请刷新余额并确认链上结果',
          'advanced.solanaRentRecovery' => 'Solana 租金回收',
          'advanced.solanaRentRecoverySubtitle' => '关闭安全的空 Token 账户并取回账户租金',
          'advanced.solanaRentWallet' => '钱包',
          'advanced.solanaRentNetwork' => 'Solana 网络',
          'advanced.solanaRentRefresh' => '刷新可回收租金',
          'advanced.solanaRentRecoverableAccounts' => '可回收账户',
          'advanced.solanaRentSelectedSummary' => '已选账户',
          'advanced.solanaRentTotalRecoverable' => '可回收总额',
          'advanced.solanaRentNetRecoverable' => '预计净到账',
          'advanced.solanaRentNoAccounts' => '当前没有可安全回收租金的空 Token 账户',
          'advanced.solanaRentStartRecovery' => '开始回收',
          'advanced.solanaRentRisk' =>
            '回收会关闭所选的零余额 Token 账户，并将账户租金退回当前钱包。若以后再次持有对应代币，链上可能重新创建 Token 账户并产生租金。',
          'advanced.solanaRentConfirmTitle' => '确认租金回收',
          'advanced.solanaRentSelectedAccounts' => '账户数量',
          'advanced.solanaRentReceivingWallet' => '接收钱包',
          'advanced.solanaRentConfirmAndSign' => '确认并签名',
          'advanced.solanaRentScanning' => '正在扫描可回收账户…',
          'advanced.solanaRentSubmitting' => '正在分批提交回收交易…',
          'advanced.solanaRentRecovering' => '回收中…',
          'advanced.solanaRentSuccess' => '租金回收成功',
          'advanced.solanaRentPartialSuccess' => '部分租金已回收',
          'advanced.solanaRentFailed' => '租金回收失败',
          'advanced.solanaRentRecoveredAccounts' => '已完成账户',
          'advanced.solanaRentRecoveredAmount' => '实际回收金额',
          'advanced.solanaRentSignatures' => '交易签名',
          'advanced.solanaRentCopySignature' => '复制签名',
          'advanced.solanaRentSignatureCopied' => '交易签名已复制',
          'advanced.solanaRentOpenSolscan' => '在 Solscan 查看',
          'advanced.solanaRentSplToken' => 'SPL Token',
          'advanced.solanaRentToken2022' => 'Token-2022',
          'advanced.solanaRentNoWallet' => '没有包含 Solana 地址的钱包',
          'advanced.solanaRentNoNetwork' => '没有可用的 Solana 网络',
          'advanced.solanaRentScanFailed' => '扫描可回收账户失败，请检查 RPC 节点后重试',
          'advanced.solanaRentSimulationFailed' => '交易模拟失败，所选账户可能已发生变化',
          'advanced.solanaRentInsufficientFee' => '钱包的 SOL 余额不足以支付预计网络手续费',
          'advanced.solanaRentSelectAccount' => '请至少选择一个要回收的 Token 账户',
          'advanced.solanaRentWalletLocked' => '需要解锁钱包才能签名',
          'advanced.solanaRentSigningKeyUnavailable' => '所选钱包没有可用的 Solana 签名私钥',
          'advanced.solanaRentAccountsChanged' => '可回收账户已发生变化，请刷新后重试',
          'advanced.solanaRentRecoveryFailed' => '部分或全部回收交易失败，请刷新后确认链上结果',
          'advanced.walletConnect' => 'WalletConnect',
          'advanced.walletConnectSubtitle' => '连接外部 dApp 并管理活跃会话',
          'advanced.walletConnectScan' => '扫描二维码',
          'advanced.walletConnectPaste' => '粘贴连接 URI',
          'advanced.walletConnectUriHint' => 'wc: URI',
          'advanced.walletConnectConnect' => '连接',
          'advanced.walletConnectActiveSessions' => '活跃会话',
          'advanced.walletConnectNoSessions' => '暂无活跃的 WalletConnect 会话',
          'advanced.walletConnectMissingConfig' =>
            '构建时未设置 REOWN_PROJECT_ID，你可以在 App 内设置自己的 WalletConnect Dashboard Project ID。',
          'advanced.walletConnectProjectId' => 'Project ID',
          'advanced.walletConnectProjectIdDescription' =>
            'Project ID 是公开的项目标识，不是钱包私钥。',
          'advanced.walletConnectProjectIdSourceCustom' => 'App 内设置',
          'advanced.walletConnectProjectIdSourceBuild' => '构建配置',
          'advanced.walletConnectProjectIdSourceMissing' => '未配置',
          'advanced.walletConnectProjectIdSet' => '设置',
          'advanced.walletConnectProjectIdReplace' => '替换',
          'advanced.walletConnectProjectIdDelete' => '删除',
          'advanced.walletConnectProjectIdInputTitle' => '设置 Project ID',
          'advanced.walletConnectProjectIdInputHint' => '32 位十六进制 Project ID',
          'advanced.walletConnectProjectIdInvalid' =>
            '请输入 32 位十六进制 Project ID。',
          'advanced.walletConnectProjectIdSaved' => 'Project ID 已保存并生效。',
          'advanced.walletConnectProjectIdDeleted' =>
            '自定义 Project ID 已删除，已启用构建配置。',
          'advanced.walletConnectProjectIdDeletedWithoutBuild' =>
            '自定义 Project ID 已删除，WalletConnect 已停用。',
          'advanced.walletConnectProjectIdApplyFailed' =>
            'Project ID 已保存，但 WalletConnect 初始化失败，请检查后重试。',
          'advanced.walletConnectProjectIdDeleteTitle' => '删除自定义 Project ID',
          'advanced.walletConnectProjectIdDeleteWithBuild' =>
            '删除后，WalletConnect 将回退使用构建时配置的 Project ID。',
          'advanced.walletConnectProjectIdDeleteWithoutBuild' =>
            '构建时也没有 Project ID，删除后 WalletConnect 将不可用。',
          'advanced.walletConnectProjectIdDisconnectTitle' => '断开活跃会话',
          'advanced.walletConnectProjectIdDisconnectBody' =>
            '更换 Project ID 前需要先断开所有活跃的 WalletConnect 会话。',
          'advanced.walletConnectProjectIdDisconnectFailed' =>
            '无法断开全部会话，Project ID 未修改。',
          'advanced.walletConnectInitializeFailed' => 'WalletConnect 初始化失败',
          'advanced.walletConnectInvalidUri' => 'WalletConnect URI 无效',
          'advanced.walletConnectDuplicateUri' => '该 WalletConnect URI 已处理',
          'advanced.walletConnectPairFailed' => '无法发起 WalletConnect 配对',
          'advanced.walletConnectPairStarted' => '已收到配对请求',
          'advanced.walletConnectDisconnect' => '断开连接',
          'advanced.walletConnectDisconnectTitle' => '断开会话',
          'advanced.walletConnectDisconnectBody' =>
            '断开后，该 dApp 将无法再向此钱包发起签名请求。',
          'advanced.walletConnectDisconnectAll' => '断开全部会话',
          'advanced.walletConnectDisconnectAllTitle' => '断开全部会话',
          'advanced.walletConnectDisconnectAllBody' =>
            '确定断开所有活跃的 WalletConnect 会话吗？',
          'advanced.walletConnectExpires' =>
            ({required Object date}) => '到期时间：${date}',
          'advanced.walletConnectAccounts' => '账户',
          'advanced.walletConnectNetworks' => '网络',
          'advanced.walletConnectMethods' => '权限',
          'advanced.walletConnectProposalTitle' => '连接请求',
          'advanced.walletConnectProposalAccounts' => '钱包账户',
          'advanced.walletConnectProposalNetworks' => '请求的网络',
          'advanced.walletConnectProposalMethods' => '请求的权限',
          'advanced.walletConnectProposalEvents' => '请求的事件',
          'advanced.walletConnectVerifyValid' => 'WalletConnect Verify 已验证该域名。',
          'advanced.walletConnectVerifyInvalid' => '域名不匹配：验证到的请求来源与发送方不一致。',
          'advanced.walletConnectVerifyScam' => '安全风险：该域名已被标记为恶意站点。',
          'advanced.walletConnectVerifyUnknown' => '无法验证请求来源，请在连接前仔细核对。',
          'advanced.walletConnectUnsupportedProposal' => '该请求包含不支持的必选网络或权限。',
          'advanced.walletConnectApprove' => '连接',
          'advanced.walletConnectReject' => '拒绝',
          'advanced.walletConnectCameraTitle' => '扫描 WalletConnect 二维码',
          'advanced.walletRequired' => '当前钱包没有可用的 EVM 地址。',
          'advanced.contractAddress' => '合约地址',
          'advanced.callMode' => '调用方式',
          'advanced.modeStandard' => '标准 ABI',
          'advanced.modeCustomAbi' => '粘贴 ABI',
          'advanced.modeManual' => '手动函数',
          'advanced.modeRaw' => '原始 calldata',
          'advanced.standardTemplate' => '标准合约模板',
          'advanced.erc20' => 'ERC-20',
          'advanced.erc721' => 'ERC-721',
          'advanced.erc1155' => 'ERC-1155',
          'advanced.abiJson' => 'ABI JSON',
          'advanced.parseAbi' => '解析 ABI',
          'advanced.manualSignature' => '函数签名，例如 balanceOf(address)',
          'advanced.outputTypes' => '返回类型，多个用逗号分隔',
          'advanced.readFunction' => '只读函数',
          'advanced.payableFunction' => '允许附带原生币',
          'advanced.buildFunction' => '生成函数',
          'advanced.function' => '函数',
          'advanced.readBadge' => '读取',
          'advanced.writeBadge' => '写入',
          'advanced.argument' =>
            ({
              required Object index,
              required Object name,
              required Object type,
            }) => '参数 ${index}：${name} (${type})',
          'advanced.arrayArgumentHint' => '数组和 tuple 请输入 JSON',
          'advanced.rawCalldata' => 'Calldata（0x 开头）',
          'advanced.rawWrite' => '将原始 calldata 作为写入交易',
          'advanced.nativeValue' => '附带原生币数量',
          'advanced.executeRead' => '读取合约',
          'advanced.prepareWrite' => '检查并准备写入',
          'advanced.result' => '调用结果',
          'advanced.copyResult' => '复制调用结果',
          'advanced.resultCopied' => '调用结果已复制',
          'advanced.rawResult' => '原始返回值',
          'advanced.transactionHash' => '交易 Hash',
          'advanced.writeRisk' =>
            '合约写入可能转移资产或授权第三方。签名前请仔细核对合约地址、函数、参数和 calldata。',
          'advanced.confirmWriteTitle' => '确认合约写入',
          'advanced.chain' => '网络',
          'advanced.method' => '方法',
          'advanced.value' => '原生币',
          'advanced.gasLimit' => 'Gas Limit',
          'advanced.gasPrice' => 'Gas Price',
          'advanced.estimatedFee' => '预计手续费',
          'advanced.confirmAndSign' => '确认并签名',
          'advanced.invalidAbi' => 'ABI 格式无效',
          'advanced.invalidInput' => '请检查合约地址、函数参数和 calldata',
          'advanced.notContract' => '该地址未检测到合约代码',
          'advanced.callFailed' => '合约调用失败',
          'advanced.walletLocked' => '需要解锁钱包才能签名',
          'advanced.submitted' => '合约交易已提交',
          'about.title' => '关于',
          'about.tagline' => '非托管多链钱包',
          'about.version' =>
            ({required Object version, required Object buildNumber}) =>
                '版本 ${version}（Build ${buildNumber}）',
          'about.versionAndUpdates' => '版本与更新',
          'about.checkUpdate' => '检查更新',
          'about.checkingUpdate' => '正在检查…',
          'about.releaseNotes' => '更新日志',
          'about.github' => 'GitHub',
          'about.transparencyAndSecurity' => '透明与安全',
          'about.dataAndNetwork' => '数据与网络说明',
          'about.openSourceLicenses' => '开源软件许可',
          'about.helpAndLegal' => '帮助与法律',
          'about.feedback' => '问题反馈',
          'about.privacyPolicy' => '隐私政策',
          'about.termsOfUse' => '使用条款',
          'about.openLinkFailed' => '无法打开链接，请稍后重试',
          'about.checkUpdateFailed' => '检查更新失败，请稍后重试',
          'about.updateAvailableTitle' =>
            ({required Object version}) => '发现新版本 ${version}',
          'about.latestVersionTitle' => '已是最新版本',
          'about.latestVersionBody' => '当前安装的版本已经是最新版本。',
          'about.noReleaseTitle' => '暂未发现可用更新',
          'about.noReleaseBody' => 'GitHub 暂无可用的正式发布版本。',
          'about.currentVersion' =>
            ({required Object version}) => '当前版本：${version}',
          'about.publishedAt' => ({required Object date}) => '发布时间：${date}',
          'about.releaseNotesEmpty' => '本次发布暂无更新说明。',
          'about.goToUpdate' => '前往更新',
          'about.close' => '关闭',
          'about.dataLocalTitle' => '本地密钥与数据',
          'about.dataLocalBody' =>
            '助记词和私钥经过加密后保存在本机。Safe Wallet 无法替你找回助记词、私钥或钱包密码。',
          'about.backendTitle' => '不依赖自建私有后端',
          'about.backendBody' =>
            'Safe Wallet 不依赖自建账户系统或私有后端。资产、交易和链上操作会直接请求你选择的 RPC 节点。',
          'about.servicesTitle' => '外部网络服务',
          'about.servicesBody' =>
            '应用会按功能访问 RPC 节点、Chainlist、CoinGecko、DefiLlama、Jupiter、DexScreener、Frankfurter 和 GitHub。第三方 dApp 与服务受其各自隐私政策约束。',
          'about.analyticsTitle' => '无广告与行为追踪',
          'about.analyticsBody' =>
            '当前版本未接入广告、行为分析或崩溃上报 SDK。你访问的 dApp、RPC 节点和第三方数据服务可能自行记录网络请求。',
          'about.privacyLocalBody' => '钱包密钥、钱包账户和地址簿等数据保存在本机；敏感密钥会加密存储。',
          'about.privacyNetworkBody' =>
            '为获取余额、价格、交易状态、网络配置和更新信息，应用会向所选 RPC 及公开数据服务发送必要的网络请求。',
          'about.privacyNoAnalyticsBody' =>
            '当前版本不包含广告或行为分析 SDK，也不会向 Safe Wallet 自建服务器上传助记词、私钥或钱包密码。',
          'about.privacyThirdPartyBody' =>
            '使用 dApp、RPC 或第三方数据服务时，对方可能依据其隐私政策处理 IP 地址、钱包地址和请求内容。',
          'about.privacyChangeBody' => '如果未来的数据处理方式发生变化，本说明将随版本更新。',
          'about.termsSelfCustodyBody' =>
            'Safe Wallet 是非托管钱包。你需要自行保管助记词、私钥和钱包密码，遗失后无法由开发者恢复。',
          'about.termsTransactionBody' => '区块链交易通常不可撤销。提交前请核对地址、网络、金额和手续费。',
          'about.termsRiskBody' => '数字资产价格和链上应用存在风险，本应用提供的内容不构成投资、法律或税务建议。',
          'about.termsThirdPartyBody' =>
            'RPC、dApp、代币和第三方服务由相应提供方负责，Safe Wallet 不控制其可用性或内容。',
          'about.termsWarrantyBody' => '本软件按现状提供。在适用法律允许的范围内，使用者需自行承担使用风险。',
          'errors.unknown' => '操作失败，请稍后重试',
          'errors.walletLocked' => '钱包已锁定，请先解锁',
          'errors.invalidMnemonic' => '助记词格式或校验和无效',
          'errors.invalidPrivateKey' => '私钥格式无效',
          'errors.passwordAttemptLocked' => '密码错误次数过多，请稍后再试',
          'errors.walletPasswordTooShort' => '钱包密码至少需要 8 个字符',
          'errors.walletPasswordTooWeak' => '该密码过于常见，请使用更难猜的密码',
          'errors.invalidRpcUrl' => 'RPC URL 格式无效',
          'errors.rpcUnavailable' => 'RPC 节点不可用，请检查地址或网络',
          'errors.rpcMissingCredential' => 'RPC 凭据缺失，请重新配置节点',
          'errors.rpcInvalidCredential' => 'RPC 凭据无效或已失效',
          'errors.rpcAccessDenied' => 'RPC 拒绝访问，请检查节点权限、IP 或 VPN 设置',
          'errors.rpcRateLimited' => 'RPC 请求过于频繁或额度已用尽',
          'errors.rpcChainMismatch' => 'RPC 节点与当前链不匹配',
          'errors.balanceQueryFailed' => '余额查询失败，请检查网络节点',
          'errors.feeEstimateFailed' => '手续费估算失败，暂不能发送交易',
          'errors.transactionBroadcastFailed' => '交易提交失败，请稍后重试',
          'errors.suiInsufficientBalance' => 'Sui Coin 余额不足',
          'errors.suiInsufficientGas' => 'SUI Gas 余额不足',
          'errors.suiObjectConflict' => 'Sui Coin 对象已被占用或版本已过期，请刷新后重试',
          'errors.suiSimulationFailed' => 'Sui 交易模拟失败，请刷新余额后重试',
          'errors.dappRejected' => '用户已拒绝 dApp 请求',
          'errors.dappUnsupportedMethod' => '当前 dApp 方法暂不支持',
          'errors.dappUnauthorized' => '该 dApp 尚未授权',
          'errors.unsupportedChain' => '当前链暂不支持',
          'errors.securityCheckFailed' => '安全校验失败，请重试',
          _ => null,
        };
  }
}
