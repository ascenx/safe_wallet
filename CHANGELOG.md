# Changelog

All notable changes to Safe Wallet will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [1.0.1] - 2026-10-14

### Added

- Scan recipient QR codes directly from the transfer form while preserving
  the selected asset, amount, and memo. Invalid or mismatched-network
  addresses are rejected.

### Fixed

- Include compute-budget instructions in Solana transfer fee simulations so
  the estimated compute-unit limit covers the complete transaction.

## [1.0.0] - 2026-08-06

### Added

- Self-custodial wallet creation and import with encrypted local key storage.
- Core wallet operations for EVM networks, Bitcoin, TRON, Solana, and Sui.
- Asset portfolios, transfers, receiving, transaction history, address book,
  and QR scanning.
- In-app dApp providers for EVM, Solana, and Sui Wallet Standard.
- Reown WalletKit integration for EVM and Solana WalletConnect sessions.
- Custom EVM networks, RPC endpoints, and token management.
- EVM contract calls, wrapped native tokens, Solana rent recovery, and TRON
  staking tools.
- English and Simplified Chinese localization.
- Android and iOS platform support.

### Security

- AES-256-GCM encryption for wallet secrets.
- PBKDF2-HMAC-SHA256 password derivation with 600,000 iterations.
- Fifteen-minute in-memory wallet key sessions and password re-authentication
  for high-risk operations.
- Biometric unlock backed by platform secure storage.
- Sensitive clipboard expiration, screen-capture protection, backup exclusion,
  and production RPC transport restrictions.

### Documentation

- Added English and Simplified Chinese project documentation.
- Added architecture, design, contribution guidance, security disclosures, and
  third-party licensing notices for the initial open-source release.
