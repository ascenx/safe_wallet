

<p align="center">
  <img src="assets/common/logo.svg" width="96" alt="Safe Wallet logo">
</p>

<h1 align="center">Safe Wallet</h1>

<p align="center">
  A security-focused, self-custodial multichain wallet built with Flutter.
</p>

<p align="center">
  English | <a href="README.zh-CN.md">简体中文</a>
</p>

> [!IMPORTANT]
> For better supply-chain security, review the source code and build Safe Wallet yourself whenever possible. Alternatively, use APKs automatically built from tagged releases by this repository's GitHub Actions and published on [GitHub Releases](../../releases), and verify them against the provided `SHA256SUMS` file.

## Overview

Safe Wallet is a Flutter wallet for managing locally controlled accounts and assets across EVM networks, Bitcoin, TRON, Solana, and Sui. It includes wallet creation and import, portfolio views, transfers, an address book, transaction history, QR scanning, a dApp browser, and WalletConnect integration.

Private keys and recovery phrases are encrypted on the device. Safe Wallet does not provide a custodial backend and cannot recover lost credentials or reverse transactions.

## Preview

| Portfolio | dApp browser | Advanced tools | Settings |
| --- | --- | --- | --- |
| <img src="images/home.png" width="220" alt="Safe Wallet portfolio screen"> | <img src="images/browser.png" width="220" alt="Safe Wallet dApp browser screen"> | <img src="images/advanced.png" width="220" alt="Safe Wallet advanced tools screen"> | <img src="images/settings.png" width="220" alt="Safe Wallet settings screen"> |

## Features

- Create and import self-custodial wallets
- View assets, receive funds, and send transactions across supported chains
- Manage custom tokens, networks, and RPC endpoints
- Browse dApps with EVM, Solana, and Sui wallet providers
- Connect to compatible dApps through Reown WalletKit (WalletConnect) on EVM and Solana
- Call EVM contracts and wrap or unwrap native tokens
- Recover rent from eligible Solana token accounts
- Stake TRX on TRON
- Use an address book, QR scanner, and local transaction history
- Switch between English and Simplified Chinese

## Supported networks

Safe Wallet ships with the following default networks. Users may add compatible custom EVM networks and RPC endpoints.

| Ecosystem | Default networks | Core wallet operations | In-app dApp provider | WalletConnect |
| --- | --- | :---: | :---: | :---: |
| EVM | Ethereum, BNB Smart Chain, Polygon, Arbitrum, Optimism, Base, HyperEVM | Yes | Yes | Yes |
| Bitcoin | Mainnet | Yes | No | No |
| TRON | Mainnet | Yes | No | No |
| Solana | Mainnet, Devnet | Yes | Yes | Yes |
| Sui | Mainnet, Testnet, Devnet | Yes | Yes (Wallet Standard) | No |

“Core wallet operations” covers account management, portfolio display, receiving, and transfers. Features can vary by chain and RPC provider.

## Security model

Safe Wallet is designed around local key custody and short-lived authorization:

- Wallet secrets are encrypted with AES-256-GCM.
- Password-derived keys use PBKDF2-HMAC-SHA256 with 600,000 iterations.
- Wallet passwords are never persisted.
- The in-memory data-encryption-key session expires immediately after 15 minutes.
- Biometric unlock relies on platform secure storage.
- High-risk operations require password re-authentication.
- Sensitive clipboard contents are cleared after a short timeout.
- Android uses `FLAG_SECURE` and disables backups; iOS applies capture shielding and no-backup protection.
- Production RPC endpoints must use HTTPS; plain HTTP is limited to loopback development endpoints.

These controls reduce risk but do not guarantee security. Device compromise, malicious dependencies, insecure RPC providers, phishing, and implementation defects remain possible threats.

## Platform status

Android and iOS are the only supported release targets. macOS, Windows, Linux, and Web runners are intentionally not included or validated.

## Getting started

### Requirements

- Flutter `>=3.41.0`
- Dart `>=3.11.0 <4.0.0`
- Platform toolchains required by Flutter for your target device

The current development baseline is Flutter `3.41.7` with Dart `3.11.5`.

### Run locally

```bash
flutter pub get
flutter run
```

### Build an Android APK

Build a release APK from the reviewed source code:

```bash
flutter pub get
flutter build apk --release
```

To include a Reown project ID for WalletConnect:

```bash
flutter build apk --release \
  --dart-define=REOWN_PROJECT_ID=your_project_id
```

Build outputs are written to `build/app/outputs/flutter-apk/app-release.apk`. For an APK intended for distribution, configure your own release keystore in `android/key.properties` by following Flutter's [Android signing guide](https://docs.flutter.dev/deployment/android#sign-the-app). Never commit the keystore, signing passwords, or `key.properties`.

As an alternative to building locally, APKs for tagged releases are automatically built by GitHub Actions and published on [GitHub Releases](../../releases) together with a `SHA256SUMS` file for integrity verification.

When localization source files change, regenerate translations with:

```bash
dart run slang
```

## WalletConnect configuration

Safe Wallet uses Reown WalletKit. You can provide a Reown project ID at build time:

```bash
flutter run --dart-define=REOWN_PROJECT_ID=your_project_id
```

The app can start without this value, and a project ID may be entered later in Settings. WalletConnect sessions currently support EVM and Solana namespaces; Bitcoin, TRON, and Sui proposals are rejected.

## Verification

Before submitting a change, run the checks relevant to it:

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Behavior changes and bug fixes should include a focused regression test whenever practical.

## Architecture

The codebase follows a feature-first structure with domain, data, application, and presentation layers where appropriate. Riverpod is used for state management and dependency wiring.

```text
lib/
├── app/                # Bootstrap, routing, lifecycle, and app shell
├── features/           # Feature modules and chain integrations
└── shared/             # Shared security, networking, storage, and UI code
test/                   # Unit and widget tests
integration_test/       # End-to-end and integration coverage
```

Read [ARCHITECTURE.md](ARCHITECTURE.md) and [DESIGN.md](DESIGN.md) for more context.

## Contributing

Contributions are welcome.

1. Fork the repository and create a focused branch.
2. Add or update tests for behavioral changes.
3. Run formatting, analysis, and relevant tests.
4. Open a pull request describing the problem, approach, and verification performed.

Never commit private keys, recovery phrases, real RPC credentials, or funded test accounts. Repository-specific collaboration guidance is available in [AGENTS.md](AGENTS.md).

## Reporting security issues

Do **not** disclose suspected vulnerabilities in a public issue. Use GitHub's private vulnerability reporting or open a private Security Advisory for this repository. Include affected versions, reproduction steps, impact, and any suggested mitigation without exposing real secrets or funds.

## Documentation

- [Architecture](ARCHITECTURE.md)
- [Design notes](DESIGN.md)

## License and third-party notices

Safe Wallet's original source code is released under the [MIT License](LICENSE).

Safe Wallet includes Reown WalletKit components distributed under the WalletConnect Community License. Portions © 2025 Reown, Inc. All Rights Reserved. Review [NOTICE](NOTICE), the [WalletConnect Community License](https://pub.dev/packages/reown_walletkit/license), and its commercial-use thresholds before distributing the application. That license applies independently to the Reown components and is not replaced by the project's MIT License.

## Disclaimer

This software is provided "as is", without warranty of any kind. Cryptocurrency transactions are irreversible, and self-custody places responsibility for keys, backups, transaction review, and software provenance on the user. Use at your own risk.
