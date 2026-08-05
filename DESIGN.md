# Safe Wallet Design Guide

本文档定义 Safe Wallet MVP 的视觉与交互设计规范。后续 Flutter 页面、组件、弹窗和状态页默认遵守本文档；如需要偏离，必须先更新设计规范。

设计基准来自当前首页稿：浅色背景、白色圆角卡片、蓝紫主色、绿色转入状态、红色转出/风险状态、底部三栏导航。

## 1. 设计目标

- 清晰：用户应快速理解当前钱包、当前链、资产、交易方向和操作入口。
- 安全：转账、签名、授权、导出助记词等危险操作必须比普通操作更醒目。
- 克制：界面以资产和操作为主，不使用复杂装饰、重渐变或营销式大标题。
- 一致：所有页面复用同一套颜色、字体、圆角、间距、阴影和图标语言。
- 移动优先：默认以 iOS/Android 手机竖屏为主要体验，不优先考虑平板和桌面。

## 2. 视觉基调

关键词：

- Clean
- Light
- Trustworthy
- Rounded
- Calm Web3

整体风格：

- 背景使用接近白色的冷灰。
- 主要内容放在白色卡片或浅色按钮容器中。
- 主色以蓝紫色表达品牌和当前选中状态。
- 成功、接收、上涨使用绿色。
- 危险、发送、失败、风险使用红色。
- 文字使用高对比黑色和蓝灰辅助色。

## 3. 颜色规范

### 3.1 基础颜色

| Token | Hex | 用途 |
| --- | --- | --- |
| `colorBackground` | `#F8FAFF` | 页面背景 |
| `colorSurface` | `#FFFFFF` | 卡片、底部导航、弹窗 |
| `colorSurfaceSoft` | `#F9FBFF` | 次级卡片、按钮背景 |
| `colorBorder` | `#D6DEEA` | 卡片边框、分割线 |
| `colorDivider` | `#E9EDF5` | 列表分割线 |
| `colorTextPrimary` | `#080A12` | 标题、金额、主要正文 |
| `colorTextSecondary` | `#68738A` | 副标题、地址、时间 |
| `colorTextMuted` | `#8A94AA` | 占位、说明、未选中图标 |

### 3.2 品牌与状态色

| Token | Hex | 用途 |
| --- | --- | --- |
| `colorPrimary` | `#5265FF` | 品牌主色、选中 Tab、主要图标 |
| `colorPrimaryDark` | `#384BEE` | 主色按压态 |
| `colorPrimarySoft` | `#EEF1FF` | 主色浅背景 |
| `colorPurple` | `#725CFF` | 扫码、dApp、次级品牌色 |
| `colorSuccess` | `#18BFA3` | 接收、成功、正向金额 |
| `colorSuccessSoft` | `#E8FAF6` | 成功浅背景 |
| `colorDanger` | `#FF3F62` | 转出、失败、风险 |
| `colorDangerSoft` | `#FFF0F3` | 风险浅背景 |
| `colorWarning` | `#F6A609` | 警告、待确认 |
| `colorWarningSoft` | `#FFF7E6` | 警告浅背景 |

### 3.3 渐变

仅在品牌图标、链图标、Token 图标和少量重点插图中使用渐变。普通按钮、普通卡片、页面背景不使用大面积渐变。

推荐渐变：

- `gradientPrimary`: `#6C7BFF -> #4A5CFF`
- `gradientEthereum`: `#8BA0FF -> #384BEE`
- `gradientSuccess`: `#36D6B6 -> #16B99D`

## 4. 字体规范

### 4.1 字体族

Flutter 默认字体：

- iOS 使用系统字体 `SF Pro`。
- Android 使用系统字体 `Roboto`。
- 不单独引入自定义字体，除非后续品牌设计明确需要。

数字金额：

- 金额、余额、Gas、交易数值使用系统字体，开启等宽数字能力时优先使用 tabular figures。
- 不使用过细字体，金额必须清晰、稳定、可读。

### 4.2 字号与字重

| Token | Size | Weight | Line Height | 用途 |
| --- | --- | --- | --- | --- |
| `displayAmount` | 34 | 700 | 42 | 首页总资产金额 |
| `titleLarge` | 22 | 700 | 30 | 页面标题 |
| `titleMedium` | 18 | 700 | 26 | 卡片标题、列表标题 |
| `bodyLarge` | 16 | 600 | 24 | 主要列表名称、按钮文字 |
| `bodyMedium` | 15 | 400 | 22 | 普通正文 |
| `bodySmall` | 14 | 400 | 20 | 地址、时间、副信息 |
| `caption` | 12 | 400 | 18 | 标签、辅助说明 |
| `tabLabel` | 13 | 500 | 18 | 底部导航文字 |

规则：

- 字间距保持 `0`。
- 页面内不要使用过大的宣传式标题。
- 金额必须右对齐或在固定区域内稳定显示。
- 长地址使用中间省略，例如 `0x8a3...5f2e`。

## 5. 间距与布局

### 5.1 页面边距

| Token | Value | 用途 |
| --- | --- | --- |
| `spacePageX` | 16 | 页面左右安全边距 |
| `spaceSectionY` | 12 | 区块之间垂直间距 |
| `spaceCardPadding` | 16 | 普通卡片内边距 |
| `spaceCardPaddingLarge` | 20 | 总资产卡片内边距 |
| `spaceListX` | 16 | 列表左右内边距 |
| `spaceListY` | 14 | 列表项上下间距 |

### 5.2 栅格

- 页面采用单列垂直流。
- 顶部栏高度建议 64。
- 底部导航固定在底部，内容区底部预留导航高度。
- 首页快捷操作采用 3 等分布局，卡片间距 12。
- 卡片宽度填满页面安全边距内区域。

### 5.3 安全区

- 顶部尊重系统状态栏。
- 底部导航尊重 Home Indicator 安全区。
- 弹窗、确认页底部按钮不得贴近系统手势区域。

## 6. 圆角规范

| Token | Radius | 用途 |
| --- | --- | --- |
| `radiusSmall` | 8 | 标签、小图标背景 |
| `radiusMedium` | 12 | 输入框、小按钮 |
| `radiusLarge` | 18 | 普通卡片、快捷操作卡片 |
| `radiusXLarge` | 22 | 总资产卡片、交易记录卡片、资产列表卡片 |
| `radiusPill` | 999 | 链选择器、胶囊按钮、底部导航 |
| `radiusCircle` | 999 | Token 图标、交易方向图标 |

规则：

- 同一页面内卡片圆角保持一致。
- 圆角不能导致文字、图标或点击区域拥挤。
- 底部导航使用胶囊形态，但内部 tab 不再额外包卡片。

## 7. 边框与阴影

### 7.1 边框

- 卡片默认使用 1px `colorBorder` 边框。
- 列表项之间使用 1px `colorDivider` 分割线。
- 输入框聚焦时边框使用 `colorPrimary`。
- 错误输入边框使用 `colorDanger`。

### 7.2 阴影

整体使用轻阴影，不使用厚重投影。

推荐阴影：

- `shadowCard`: `0 10 30 rgba(19, 32, 71, 0.06)`
- `shadowFloating`: `0 12 36 rgba(19, 32, 71, 0.10)`
- `shadowIconGlow`: 仅用于主操作图标，颜色跟随图标主色，透明度不超过 `0.16`

规则：

- 普通列表项不单独投影。
- 卡片可同时使用浅边框和轻阴影。
- 危险状态不使用发光阴影，使用红色文案和浅红背景表达。

## 8. 图标规范

### 8.1 图标库与统一入口

- App 的基础功能图标统一使用 `phosphor_flutter`，不混用 Material Icons 或其他通用图标库。
- 页面和业务组件必须通过 `lib/shared/design/app_icons.dart` 中的 `AppIcons` 使用图标。
- 页面不得直接使用 Material 的 `Icons.*`。
- 页面不得直接引用 `PhosphorIconsRegular`、`PhosphorIconsFill` 或其他 Phosphor 权重；具体图标和权重只在 `AppIcons` 中映射。
- 同一语义在不同页面必须使用同一个 `AppIcons` 名称，不能因页面不同随意更换图形。

图标采用三层结构：

| 层级 | 职责 | 示例 |
| --- | --- | --- |
| 原始层 | Phosphor 提供的具体图形和权重，仅允许在 `app_icons.dart` 中使用 | `PhosphorIconsRegular.wallet`、`PhosphorIconsFill.star` |
| 语义层 | 用产品语义命名，隔离页面与具体图标库 | `AppIcons.wallet`、`AppIcons.security`、`AppIcons.favoriteSelected` |
| 组件层 | 根据组件状态选择语义图标、尺寸和颜色 | 底部导航、按钮、列表项、状态提示 |

### 8.2 图标尺寸

基础尺寸统一使用 `AppIconSize`：

| Token | Size | 用途 |
| --- | --- | --- |
| `AppIconSize.small` | 16 | 标签、紧凑型辅助信息 |
| `AppIconSize.action` | 20 | 输入框尾部操作、列表行操作、小按钮 |
| `AppIconSize.standard` | 24 | 页面常规图标、底部导航、普通按钮 |
| `AppIconSize.prominent` | 32 | 重点操作、空状态和强调型状态图标 |

规则：

- 新增或重构组件时优先使用上述尺寸 token，不在页面散落新的图标尺寸。
- 触控区域不得等同于图标尺寸；可点击图标的最小触控区域为 44 × 44。
- Token Logo、链 Logo、dApp Logo 和特殊展示型图标按对应组件规范设置尺寸，不受通用功能图标尺寸限制。
- 组件规范已明确特殊尺寸时可覆盖基础 token，例如快捷操作图标 34 到 40；该尺寸应收敛在组件内部，不由调用页面重复指定。

### 8.3 风格、权重与状态

- 默认使用 Phosphor `Regular`，保持线性、圆角且克制的视觉风格。
- 底部导航、收藏、单选等具有明确“选中/未选中”状态的图标，默认使用 `Regular`，选中时可切换为 `Fill`。
- 成功、危险等需要更强辨识度的状态图标可以使用 `Fill`，但必须在 `AppIcons` 中提供明确的语义名称。
- 不随意混用 `Bold`、`Thin`、`Light`、`Duotone` 等权重；确有新增权重需求时，先更新本规范和 `AppIcons` 映射。
- 未选中和次要图标使用 `colorTextMuted`；选中和主要操作使用 `colorPrimary`；成功、警告、危险图标分别使用对应状态色。
- 颜色用于表达语义和状态，不依靠图标填充方式作为唯一状态提示。

### 8.4 品牌 Logo 与通用图标边界

- 区块链、Token、dApp、DEX、聚合器和协议必须优先使用其官方品牌 Logo 或项目内已收录的本地资源。
- 不使用 Phosphor 的通用图标替代可获得的品牌 Logo，也不使用品牌 Logo 表达通用操作。
- Token Logo 使用圆形容器，尺寸 42 到 48；链选择器中的链 Logo 尺寸 24。
- 如 Token 或站点没有可用 Logo，使用统一的占位组件，可根据符号首字母或链类型生成占位图标。
- Logo 背景应保证可读性，避免纯黑或强饱和大面积色块破坏整体视觉平衡。

### 8.5 语义命名与新增流程

新增图标时按以下顺序处理：

1. 先确认 `AppIcons` 是否已有相同语义，优先复用，不按图形外观重复命名。
2. 缺少语义时，在 `AppIcons` 中添加业务含义明确的名称，并映射到合适的 Phosphor 图标和权重。
3. 页面或组件只引用新增的语义名称，并使用 `AppIconSize` 或组件内部尺寸。
4. 新增选中态时成对提供默认和选中语义，例如 `favorite` 与 `favoriteSelected`。
5. 必要时补充防回归测试；生产代码必须继续通过 `test/shared/design/no_material_icons_test.dart` 的检查。

推荐：

```dart
const Icon(
  AppIcons.security,
  size: AppIconSize.standard,
  color: AppColors.primary,
)
```

禁止：

```dart
const Icon(Icons.security);
const Icon(PhosphorIconsRegular.shieldCheck);
```

### 8.6 交易方向图标

- 接收：`AppIcons.receive`，绿色向左下箭头，圆形浅绿背景。
- 转出：`AppIcons.send`，红色或绿色向右上箭头；颜色按交易方向和具体组件语义决定。
- 扫码：`AppIcons.scan`，使用紫色。
- 同类交易方向在交易列表、历史记录和确认结果中必须保持图形语义一致。

## 9. 组件规范

### 9.1 顶部栏

结构：

- 左侧：钱包头像或品牌图标 + 钱包名称 + 下拉箭头。
- 右侧：当前链选择器。

规格：

- 高度：64。
- 左侧图标：34。
- 钱包名称字号：18，字重 700。
- 链选择器高度：34 到 38。
- 链选择器圆角：`radiusPill`。
- 链选择器边框：`colorBorder`。

行为：

- 点击钱包名称打开钱包/账户切换。
- 点击链选择器打开链切换列表。
- 当前链变化后，资产、交易、Gas、dApp 链上下文必须刷新。

### 9.2 总资产卡片

用途：首页核心资产概览。

规格：

- 高度建议 136 到 148。
- 圆角：`radiusXLarge`。
- 内边距：`spaceCardPaddingLarge`。
- 背景：`colorSurface`。
- 边框：1px `colorBorder`。
- 右侧可放当前链或品牌插图。

内容：

- 标签：`总资产估值` + 可见/隐藏图标。
- 主金额：`displayAmount`。
- 折算余额：`bodyMedium`，颜色 `colorTextMuted`。
- 隐藏资产时金额显示为 `••••••`，保持原布局高度。

### 9.3 快捷操作卡片

三个默认操作：

- 接收
- 转账
- 扫码

规格：

- 三等分排列。
- 高度：82 到 92。
- 圆角：`radiusLarge`。
- 图标尺寸：34 到 40。
- 文字字号：16，字重 600。
- 图标与文字间距：8。

状态：

- 默认背景 `colorSurface`。
- 按压时背景 `colorSurfaceSoft`。
- 禁用时图标和文字使用 `colorTextMuted`，透明度不低于 0.45。

### 9.4 信息卡片

用于交易记录、资产列表、节点列表、授权站点列表。

规格：

- 圆角：`radiusXLarge`。
- 内边距：16。
- 标题行高度：36 到 44。
- 列表项高度：64 到 76。
- 分割线从内容区起始，不穿过图标区域。

标题行：

- 左侧标题字号 18，字重 700。
- 右侧操作字号 14，颜色 `colorTextSecondary`。
- 右侧可带 20 尺寸图标。

### 9.5 交易记录列表项

结构：

- 左侧交易方向图标。
- 中间：交易类型 + 地址摘要。
- 右侧：金额 + 时间。

规格：

- 左侧图标尺寸：34 到 38。
- 交易类型字号：15 到 16，字重 600。
- 地址字号：14，颜色 `colorTextSecondary`。
- 金额字号：15 到 16，字重 600。
- 时间字号：13 到 14，颜色 `colorTextSecondary`。

颜色：

- 接收金额使用 `colorSuccess`，带 `+`。
- 转出金额使用 `colorDanger`，带 `-`。
- 待确认使用 `colorWarning`。
- 失败使用 `colorDanger`。

### 9.6 资产列表项

结构：

- 左侧 Token 图标。
- 中间：Token 名称 + Symbol。
- 右侧：Token 数量 + 估值 + 进入箭头。

规格：

- 行高：72 到 78。
- Token 图标：42。
- 名称字号：16，字重 600。
- Symbol 字号：14，颜色 `colorTextSecondary`。
- 数量字号：15，颜色 `colorTextPrimary`。
- 估值字号：15，颜色 `colorTextPrimary`。
- 进入箭头颜色：`colorTextMuted`。

规则：

- 数量和估值右对齐。
- 余额加载失败时显示错误状态，不显示为 0。
- 隐藏 Token 后不在资产列表出现。
- 发现的 Token 可使用低优先级样式或单独分组。

### 9.7 底部导航

默认三项：

- 首页
- 浏览器
- 设置

规格：

- 高度：78 到 86，不含系统安全区。
- 背景：`colorSurface`。
- 圆角：`radiusPill`。
- 外边距：左右 12 到 16，底部 8 到 12。
- 图标尺寸：28。
- 文案字号：13。

状态：

- 选中：图标和文字 `colorPrimary`。
- 未选中：图标和文字 `colorTextMuted`。
- 不使用选中背景块，保持轻量。

## 10. 表单与输入

输入框规格：

- 高度：48 到 54。
- 圆角：`radiusMedium`。
- 背景：`colorSurface`。
- 边框：1px `colorBorder`。
- 内边距：水平 14 到 16。
- 字号：15 到 16。

适用场景：

- 转账地址。
- 转账金额。
- RPC URL。
- 节点名称。
- dApp URL。
- 钱包密码。

状态：

- 聚焦：边框 `colorPrimary`。
- 错误：边框 `colorDanger`，下方错误文案使用 `colorDanger`。
- 禁用：背景 `colorSurfaceSoft`，文字 `colorTextMuted`。

### 10.1 选项选择器

- 全项目所有用户可交互的有限选项选择器，包括服务商、网络、鉴权方式、资产类型、调用方式、ABI 模板和合约函数，统一使用自定义底部弹窗选择器。
- 生产代码禁止使用 `DropdownButton`、`DropdownButtonFormField` 或浏览器式下拉菜单；该规则由 `test/shared/widgets/no_dropdown_button_test.dart` 自动检查。
- 表单入口使用 `AppPickerField`，展示字段标题、当前值和向下箭头；点击后使用 `showAppActionSheet` 打开底部弹窗。
- 底部弹窗必须有明确标题，选项使用整行可点击卡片，当前选项通过 `colorPrimarySoft` 背景和 `colorPrimary` 边框表示。
- 不使用孤立的勾选圆点、紧凑下拉列表或悬浮菜单表达当前选项。
- 新增同类选择控件时优先复用现有底部弹窗组件；确需例外时必须先更新本规范。
- 节点配置面向用户只提供一个 `URL` 字段，不暴露“基础 RPC URL”和“完整私有 Endpoint”等内部数据模型差异。
- 私有 Endpoint 的识别、拆分、脱敏和安全存储由系统自动完成，用户只需粘贴服务商提供的 URL。
- 用户可见的参数方式使用“无需参数”“Query 参数”“Path 参数”“HTTP Header”等任务导向文案，不展示内部存储模式名称。

## 11. 按钮规范

### 11.1 主按钮

- 高度：52。
- 圆角：`radiusMedium` 或 `radiusPill`，按页面密度选择。
- 背景：`colorPrimary`。
- 文字：白色，16，字重 700。
- 按压：`colorPrimaryDark`。
- 禁用：`#CBD3E5`。

### 11.2 次按钮

- 高度：48 到 52。
- 背景：`colorPrimarySoft`。
- 文字：`colorPrimary`。
- 边框：无或 1px `#DDE4FF`。

### 11.3 危险按钮

- 背景：`colorDanger`。
- 文字：白色。
- 用于删除钱包、确认高风险签名、导出私钥确认等最终动作。

## 12. 安全与风险 UI

风险等级：

| 等级 | 颜色 | 使用场景 |
| --- | --- | --- |
| Info | `colorPrimary` | 普通说明、链切换提示 |
| Warning | `colorWarning` | 节点不可用、Gas 异常、未知 Token |
| Danger | `colorDanger` | 无法解析交易、无限授权、导出私钥、删除钱包 |

规则：

- 助记词、私钥、授权、签名、交易确认必须有清晰的风险说明。
- 危险操作按钮必须和普通按钮视觉区分。
- 交易确认页必须突出链、收款地址、金额、Gas、合约地址和风险提示。
- 无法解析的 dApp 交易不得展示成普通确认。
- 红色只用于真实风险或负向金额，不用于装饰。

## 13. 页面结构规范

### 13.1 首页

顺序：

1. 顶部栏。
2. 总资产卡片。
3. 快捷操作。
4. 最近交易。
5. 资产列表。
6. 底部导航。

规则：

- 首页第一屏应能看到总资产、三个核心操作和最近交易开头。
- 最近交易和资产列表可按内容滚动。
- 底部导航固定，不随列表滚走。

### 13.2 转账页

结构：

- 顶部返回 + 标题。
- 当前链和 Token 选择。
- 收款地址输入。
- 金额输入。
- 余额与最大值按钮。
- Gas 预估。
- 下一步主按钮。

规则：

- 地址错误、余额不足、Gas 失败必须阻止进入确认。
- 金额、手续费、总扣款必须在确认页再次展示。

### 13.3 节点管理页

结构：

- 链选择。
- 当前节点卡片。
- 默认节点列表。
- 自定义节点列表。
- 新增节点入口。

规则：

- 节点状态使用可读标签：可用、测试中、失败、链 ID 不匹配。
- 当前节点必须有明显选中标识。
- 删除当前节点前必须先切换或自动回默认节点。

### 13.4 dApp 浏览器

结构：

- 顶部 URL 或站点标题。
- 页面内容。
- 底部或顶部浏览控制。
- 钱包连接状态入口。

规则：

- dApp 请求连接、签名、交易时使用底部弹窗或独立确认页。
- 授权弹窗必须显示站点域名、请求链、请求账户。
- 用户拒绝后要回传拒绝结果。

## 14. 空状态、加载与错误

加载：

- 使用轻量骨架屏或行内 loading，不使用全屏阻塞，除非是启动解锁。

空状态：

- 文案简短，提供下一步操作。
- 资产为空不等于加载失败。

错误：

- 说明发生了什么。
- 说明用户可以怎么处理。
- 不显示底层堆栈。
- 不泄露私钥、助记词、RPC 鉴权信息。

## 15. 动效规范

- 页面切换使用平台默认过渡。
- 卡片按压缩放不超过 0.98。
- 列表刷新使用系统刷新控件。
- 弹窗出现时间 180 到 240ms。
- 不使用持续循环的装饰动画，除非是加载态。

## 16. Flutter 落地建议

建议建立设计 token 文件：

- `lib/shared/design/app_colors.dart`
- `lib/shared/design/app_spacing.dart`
- `lib/shared/design/app_radius.dart`
- `lib/shared/design/app_text_styles.dart`
- `lib/shared/design/app_shadows.dart`

组件命名建议：

- `WalletTopBar`
- `ChainSelectorChip`
- `BalanceSummaryCard`
- `QuickActionCard`
- `SectionCard`
- `TransactionListItem`
- `AssetListItem`
- `WalletBottomNavigation`
- `RiskNotice`
- `PrimaryButton`
- `SecondaryButton`
- `DangerButton`

实现规则：

- 页面不得直接写散落的颜色 hex，应使用设计 token。
- 页面不得直接写散落的大量圆角和间距，应使用 `AppRadius`、`AppSpacing`。
- 所有用户可见文案必须走 `slang` 国际化。
- 核心页面状态通过 Riverpod 管理。
- Token 图标、链图标、交易方向图标尺寸必须稳定，不能因加载状态改变布局。

## 17. 当前首页设计摘要

首页视觉参数：

- 页面背景：`#F8FAFF`。
- 内容左右边距：16。
- 卡片背景：`#FFFFFF`。
- 卡片边框：`#D6DEEA`。
- 总资产卡片圆角：22。
- 普通区块卡片圆角：22。
- 快捷操作卡片圆角：18。
- 底部导航圆角：999。
- 主色：`#5265FF`。
- 接收色：`#18BFA3`。
- 转出色：`#FF3F62`。
- 辅助文字：`#68738A`。
- 未选中图标：`#8A94AA`。

首页必须保持：

- 顶部钱包选择与链选择并列。
- 总资产为第一优先级内容。
- 接收、转账、扫码为第一屏核心操作。
- 最近交易在资产列表之前。
- 资产列表支持管理代币入口。
- 底部导航包含首页、浏览器、设置。
