# Safe Wallet Architecture Guide

文档日期：2026-06-06

本文档定义 Safe Wallet MVP 的技术架构。后续实现默认遵守本文档；如架构需要调整，应先更新本文档，再修改代码。

相关文档：

- `docs/requirements/mvp-wallet-requirements.md`：产品与功能需求。
- `DESIGN.md`：视觉、组件和页面设计规范。

## 1. 架构目标

- 安全：钱包密钥、签名、解锁会话和敏感数据必须有明确边界。
- 可测：核心业务逻辑不依赖 Flutter Widget 测试才能验证。
- 可扩展：EVM 与 Solana 能并行演进，后续可加入更多链和 dApp 能力。
- 可维护：模块按功能组织，页面、状态、业务逻辑、SDK 调用和本地存储分层清楚。
- 一致：状态管理统一使用 `flutter_riverpod` 3.x。

## 2. 总体架构

采用 Feature-first + Clean-ish Layer + Riverpod 编排。

核心原则：

- Feature-first：按业务模块组织代码，例如 `wallet`、`assets`、`transfer`、`browser`。
- Clean-ish Layer：每个模块内部按 `presentation`、`application`、`domain`、`data` 分层，但不为了形式创建无意义文件。
- Riverpod：负责依赖注入、状态组合、异步状态表达和 UI 状态订阅。
- Repository/Service：承载业务逻辑、链 SDK 调用、本地存储、加密和签名。

数据流：

```text
UI Widget
  -> Riverpod Controller / Notifier
  -> Repository
  -> Service / Client / Storage
  -> web3dart / solana_sdk / hive_ce / crypto
```

反向数据流：

```text
Storage / RPC / SDK result
  -> Repository normalized result
  -> Riverpod state
  -> UI rebuild
```

## 3. 推荐目录结构

```text
lib/
  app/
    app.dart
    app_router.dart
    app_providers.dart
    shell/
      main_shell_page.dart

  features/
    onboarding/
      presentation/
      application/
      domain/
      data/

    home/
      presentation/
      application/

    wallet/
      presentation/
      application/
      domain/
      data/

    chains/
      presentation/
      application/
      domain/
      data/

    nodes/
      presentation/
      application/
      domain/
      data/

    assets/
      presentation/
      application/
      domain/
      data/

    transfer/
      presentation/
      application/
      domain/
      data/

    browser/
      presentation/
      application/
      domain/
      data/

    dapp/
      presentation/
      application/
      domain/
      data/

    settings/
      presentation/
      application/

    address_book/
      presentation/
      application/
      domain/
      data/

    i18n/
      application/

  shared/
    design/
    security/
    storage/
    network/
    crypto/
    chain_clients/
    utils/
```

目录职责：

- `app/`：应用入口、路由、全局 ProviderScope、主 Shell。
- `features/`：业务模块，每个模块只暴露必要 provider、页面和 public model。
- `shared/design/`：对应 `DESIGN.md` 的颜色、圆角、间距、字体 token。
- `shared/security/`：钱包加密、KDF、解锁会话、敏感数据处理。
- `shared/storage/`：`hive_ce` box 初始化、数据表 key、迁移。
- `shared/chain_clients/`：EVM/Solana RPC client 工厂，不放业务状态。

## 4. 分层规则

### 4.1 Presentation

包含页面、组件和纯 UI 状态。

可以做：

- watch provider。
- 调用 controller 方法。
- 展示 AsyncValue loading/error/data。
- 使用 `DESIGN.md` 中的设计 token。
- 使用 `slang` 生成的本地化文案。

不可以做：

- 直接调用 `web3dart` 或 `solana_sdk`。
- 直接读写 `hive_ce`。
- 直接持有 `walletDEK`、私钥、助记词。
- 在 Widget 中写复杂交易构造、Gas 计算、Token 发现逻辑。

### 4.2 Application

包含 Riverpod provider、controller、notifier、use case 编排。

职责：

- 组合当前钱包、当前链、当前节点等状态。
- 调用 repository 完成业务动作。
- 暴露 UI 需要的状态。
- 控制异步状态、刷新、失效和错误映射。

不做：

- 不直接写 SDK 调用细节。
- 不直接处理底层存储格式。
- 不把密钥明文持久化。

### 4.3 Domain

包含核心模型、枚举和业务规则。

示例：

- `WalletAccount`
- `WalletSession`
- `ChainConfig`
- `RpcNode`
- `AssetBalance`
- `TokenInfo`
- `TransactionRequest`
- `DappPermission`
- `AddressBookContact`

规则：

- Domain 不依赖 Flutter。
- Domain 不依赖具体存储或 SDK。
- Domain 类型优先不可变。

### 4.4 Data

包含 repository 实现、DTO、storage adapter、SDK adapter。

职责：

- 调用 `web3dart`、`solana_sdk`。
- 读写 `hive_ce`。
- 调用加密 service。
- 把底层异常转换为业务错误。

规则：

- Data 层错误不能直接把底层堆栈暴露给 UI。
- Data 层返回 domain model 或 application 可理解的 result。

## 5. Riverpod 使用规范

### 5.1 Provider 类型选择

使用规则：

- `Provider`：无状态依赖，例如 repository、service、client factory。
- `NotifierProvider` / `@riverpod class`：同步可变状态，例如当前链、当前钱包、语言设置。
- `AsyncNotifierProvider` / `@riverpod class`：异步状态，例如资产、交易记录、Token 发现、节点测试。
- `FutureProvider`：只用于简单只读异步数据，复杂流程用 AsyncNotifier。
- `StreamProvider`：只用于真实流式数据，例如后续 WebSocket 区块订阅。

避免：

- 不用 `ChangeNotifierProvider` 承载核心业务状态。
- 不用 `StateProvider` 承载跨页面核心状态。
- 不在 provider 中创建难以测试的全局单例。

### 5.2 Code Generation

推荐使用 `riverpod_annotation` 与 `riverpod_generator`。

原因：

- provider 命名稳定。
- family 参数类型更清晰。
- 依赖关系更容易测试和重构。
- 大项目里减少手写 provider 样板代码。

约定：

- provider 文件以 `_provider.dart` 或 `_controller.dart` 结尾。
- 生成文件使用 `part '*.g.dart';`。
- 一个 provider 文件只服务一个清晰模块，不堆大量无关 provider。

## 6. 全局 Provider 设计

### 6.1 App 层

建议 provider：

```text
appBootstrapProvider
appRouterProvider
mainShellTabProvider
```

职责：

- 初始化本地存储。
- 初始化国际化。
- 决定进入 onboarding、unlock 或 main shell。
- 管理底部三栏：首页、浏览器、设置。

### 6.2 钱包会话

建议 provider：

```text
walletSessionControllerProvider
selectedWalletProvider
walletRepositoryProvider
walletCryptoServiceProvider
```

状态：

```text
unknown
noWallet
locked
unlocked
expired
```

规则：

- `walletSessionControllerProvider` 是解锁态的唯一入口。
- `walletDEK` 只能存在于内存会话中，不进入 UI。
- 用户密码和 `passwordKEK` 使用后立即丢弃。
- 15 分钟免密码只缓存 `walletDEK`。
- 超时、主动锁定、切换钱包、退出应用后清空 `walletDEK`。
- 导出助记词、导出私钥、删除钱包、修改密码必须重新输入密码。

### 6.3 链与节点

建议 provider：

```text
chainRepositoryProvider
availableChainsProvider
selectedChainControllerProvider

rpcNodeRepositoryProvider
selectedRpcNodeProvider
rpcNodeTestControllerProvider

evmClientProvider(chainId)
solanaClientProvider(clusterOrChainId)
```

规则：

- 当前链变化后，资产、Gas、dApp 当前链信息必须刷新。
- 当前节点变化后，所有依赖 RPC 的 provider 必须刷新。
- EVM RPC 必须校验 Chain ID。
- Solana RPC 必须校验基础链状态。
- UI 不直接创建 RPC client。

### 6.4 资产与 Token

建议 provider：

```text
assetRepositoryProvider
assetPortfolioProvider
assetRefreshControllerProvider

tokenRepositoryProvider
tokenDiscoveryControllerProvider
hiddenTokensProvider
```

依赖：

```text
assetPortfolioProvider
  watches walletSession
  watches selectedWallet
  watches selectedChain
  watches selectedRpcNode
```

规则：

- 钱包锁定时，资产 provider 返回 locked 或清空敏感上下文。
- 余额加载失败不能显示为 0。
- Token 发现使用内置列表、手动添加、RPC Transfer 日志扫描。
- Token 发现失败不能影响内置 Token 和手动 Token 显示。

### 6.5 转账

建议 provider：

```text
transferDraftControllerProvider
feeEstimateProvider
transactionConfirmControllerProvider
transactionBroadcastControllerProvider
```

职责：

- 校验地址。
- 校验金额和余额。
- 预估 Gas 或 Solana fee。
- 组装确认数据。
- 调用钱包会话签名能力。
- 广播交易。

规则：

- UI 不直接签名。
- 签名前必须展示确认数据。
- EVM 默认 EIP-1559，不支持时 fallback Legacy。
- fallback 必须发生在用户确认前。
- 交易失败原因要映射为用户可理解错误。

### 6.6 浏览器与 dApp

建议 provider：

```text
dappCatalogProvider
dappFavoritesControllerProvider
dappRecentVisitsControllerProvider
dappPermissionControllerProvider
dappRequestControllerProvider
```

职责：

- 浏览器首页展示常用 DEX/dApp。
- 管理收藏和最近访问。
- 管理 dApp 域名授权。
- 处理连接钱包、签名、交易请求。

规则：

- 未授权 dApp 不能获取地址。
- 授权按域名保存。
- 签名和交易必须弹出全局确认。
- 无法解析的交易显示高风险提示。

### 6.7 设置与地址簿

建议 provider：

```text
settingsControllerProvider
addressBookRepositoryProvider
addressBookControllerProvider
localeControllerProvider
```

职责：

- 钱包管理入口。
- 网络管理入口。
- 地址簿增删改查。
- 多语言设置。
- 安全设置入口。

规则：

- 地址簿保存前必须校验链类型和地址格式。
- 转账页选择联系人时必须过滤当前链可用地址。
- 语言状态由 Riverpod 管理并持久化。
- UI 文案全部走 `slang`。

## 7. Repository 与 Service 边界

### 7.1 Repository

Repository 面向业务，返回 domain model。

示例：

```text
WalletRepository
ChainRepository
RpcNodeRepository
AssetRepository
TokenRepository
TransferRepository
DappRepository
AddressBookRepository
SettingsRepository
```

Repository 可以依赖：

- storage。
- SDK adapter。
- security service。
- network client。

Repository 不依赖：

- Widget。
- BuildContext。
- 页面 controller。

### 7.2 Service

Service 面向底层能力。

示例：

```text
WalletCryptoService
MnemonicService
KeyDerivationService
SessionKeyCache
EvmClientService
SolanaClientService
EvmTokenDiscoveryService
EvmGasService
DappProviderBridgeService
```

规则：

- Service 尽量小而专一。
- 加密、签名、派生、RPC 调用不要混在同一个 service。
- Service 可被 fake/mock 替换。

## 8. 模块架构

### 8.1 Onboarding

包含：

- 创建钱包。
- 导入钱包。
- 助记词风险说明。
- 设置密码。

依赖：

- `WalletRepository`
- `MnemonicService`
- `WalletCryptoService`

输出：

- 创建或导入成功后进入主 App 首页。

### 8.2 Home

包含：

- 当前钱包名称。
- 当前链选择器。
- 总资产卡片。
- 接收、转账、扫码。
- 最近交易。
- 资产列表。

依赖：

- `selectedWalletProvider`
- `selectedChainControllerProvider`
- `assetPortfolioProvider`
- `transactionHistoryProvider`

规则：

- 首页遵守 `DESIGN.md`。
- 最近交易和资产列表不直接访问 storage。

### 8.3 Wallet

包含：

- 钱包列表。
- 钱包切换。
- 钱包重命名。
- 导出助记词/私钥。
- 删除钱包。

规则：

- 高风险操作必须重新输入密码。
- `walletDEK` 只由会话 controller 管理。

### 8.4 Chains 与 Nodes

包含：

- 链列表。
- 当前链。
- RPC 节点列表。
- RPC 测试。
- 自定义节点。

规则：

- 链配置与节点配置分开存储。
- 当前节点按链保存。
- 节点测试结果不等于当前节点切换，用户确认后才切换。

### 8.5 Assets

包含：

- 原生币余额。
- ERC20/SPL Token 余额。
- EVM Token 发现。
- Token 隐藏状态。

规则：

- 余额查询按链分派到 EVM 或 Solana service。
- EVM Token 发现是 best-effort。
- 失败状态必须和 0 余额区分。

### 8.6 Transfer

包含：

- 地址输入。
- 地址簿选择。
- 金额输入。
- Fee/Gas 预估。
- 确认页。
- 签名和广播。

规则：

- 转账流程通过 controller 编排。
- 签名只能通过 wallet session 访问解密能力。
- 交易确认数据使用 domain model 表达，避免 UI 拼散字段。

### 8.7 Browser 与 dApp

包含：

- 浏览器首页。
- 默认 DEX/dApp 列表。
- 收藏和最近访问。
- WebView 或内置浏览器页面。
- dApp 授权、签名、交易请求。

规则：

- 浏览器首页与 dApp provider bridge 分离。
- dApp 权限按域名保存。
- dApp 请求链切换必须用户确认。

### 8.8 Settings

包含：

- 设置首页。
- 钱包管理入口。
- 网络管理入口。
- 地址簿入口。
- 多语言设置入口。
- 安全设置入口。

规则：

- 设置页只是入口聚合，具体业务逻辑放到对应 feature。
- 语言切换通过 `localeControllerProvider`。

## 9. 本地存储架构

使用 `hive_ce` 保存结构化数据。

建议 box：

```text
walletsBox
chainsBox
rpcNodesBox
tokensBox
transactionsBox
dappPermissionsBox
dappCatalogBox
browserStateBox
addressBookBox
settingsBox
```

规则：

- 敏感数据必须先独立加密再写入 box。
- `shared_preferences` 只用于非关键偏好，且应通过统一设置服务读取。
- 任何页面不得直接读写 box。
- box key 和数据版本必须集中定义。
- 后续 schema 变化必须提供迁移策略。

## 10. 安全架构

密钥分层：

```text
用户密码
  -> KDF
  -> passwordKEK
  -> 解密 encryptedWalletDEK
  -> walletDEK
  -> 解密助记词/私钥
```

运行时规则：

- UI 不接触用户密码以外的密钥材料。
- 用户密码只在输入和解锁流程中短暂存在。
- `passwordKEK` 使用后立即丢弃。
- `walletDEK` 只存在于 `SessionKeyCache`。
- 15 分钟免密码只复用 `walletDEK`。
- App 锁定后，所有需要签名/解密的 provider 返回 locked。

Provider 失效规则：

- `walletSession` 从 unlocked 变为 locked/expired 时，资产、转账、dApp 签名相关 provider 必须失效或返回 locked。
- `selectedWallet` 改变时，资产、交易、地址上下文、dApp 授权上下文必须刷新。
- `selectedChain` 改变时，资产、Gas、Token、dApp chain context 必须刷新。
- `selectedRpcNode` 改变时，链上请求 provider 必须刷新。

## 11. 错误处理

错误类型建议：

```text
WalletError
ChainError
RpcError
AssetError
TransferError
DappError
StorageError
SecurityError
```

规则：

- Repository 捕获底层异常并转换为业务错误。
- UI 显示本地化后的用户文案。
- 日志不得包含助记词、私钥、密码、`walletDEK`、`passwordKEK`。
- RPC 错误要保留可调试 code，但不要直接展示堆栈。
- 余额查询失败不能显示为 0。

## 12. 测试架构

测试优先级：

1. Domain 规则单元测试。
2. Repository fake service 测试。
3. Riverpod provider 状态流测试。
4. Widget 测试验证关键页面状态。

必须支持 Provider override：

```text
ProviderScope(
  overrides: [
    walletRepositoryProvider.overrideWithValue(fakeWalletRepository),
    assetRepositoryProvider.overrideWithValue(fakeAssetRepository),
  ],
  child: App(),
)
```

重点测试：

- 创建/导入钱包后进入主 App 首页。
- 钱包锁定后依赖解锁态的 provider 失效。
- 当前链/节点变化后资产和 Gas 刷新。
- EVM Token 发现流程。
- 转账确认与签名广播流程。
- dApp 授权、拒绝、签名请求。
- 地址簿选择收款地址。
- 多语言状态持久化。
- 敏感数据不明文写入本地存储和日志。

## 13. 开发约束

- 新页面必须在对应 feature 下创建，不直接堆到 `lib/` 根目录。
- 新业务状态必须通过 Riverpod 管理。
- 新 SDK 调用必须封装到 service 或 repository。
- 新本地数据必须通过 repository/storage adapter 访问。
- 新用户可见文案必须走 `slang`。
- 新 UI 必须使用 `shared/design` token。
- 不允许在 Widget 中直接持有私钥、助记词、`walletDEK`。
- 不允许为了快速实现绕过钱包会话 controller 签名。

## 14. MVP 实施顺序

建议按以下顺序落地：

1. App shell、Riverpod 根配置、设计 token、`slang` 基础配置。
2. 本地存储初始化和 repository 基础接口。
3. 钱包创建、导入、加密存储、解锁会话。
4. 主 App 三栏：首页、浏览器、设置。
5. 链配置、节点管理、RPC client factory。
6. 资产查询、Token 管理、EVM Token 发现。
7. 转账、Gas/fee 预估、交易确认、签名广播。
8. 浏览器首页、dApp 授权、EVM Provider 基础适配。
9. 地址簿、多语言设置、安全设置。
10. 错误处理、缓存刷新、测试补齐。
