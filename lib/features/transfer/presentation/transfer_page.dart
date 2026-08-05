import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/errors/transfer_error.dart';
import '../../../shared/errors/wallet_error.dart';
import '../../../shared/utils/token_amount.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading_state.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../address_book/presentation/contact_picker_sheet.dart';
import '../../assets/application/asset_portfolio_provider.dart';
import '../../assets/data/asset_repository.dart';
import '../../assets/domain/asset_balance.dart';
import '../../assets/presentation/widgets/token_icon.dart';
import '../../chains/domain/chain_config.dart';
import '../application/fee_estimate_provider.dart';
import '../application/transaction_confirm_controller.dart';
import '../application/transaction_history_provider.dart';
import '../application/transfer_draft_controller.dart';
import '../domain/transaction_record.dart';
import '../domain/transaction_request.dart';
import 'transaction_confirm_page.dart';
import 'transfer_asset_picker_sheet.dart';

final class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({
    this.initialRecipient,
    this.initialContractAddress,
    this.initialAmount,
    this.initialMemo,
    super.key,
  });

  final String? initialRecipient;
  final String? initialContractAddress;
  final String? initialAmount;
  final String? initialMemo;

  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

final class _TransferPageState extends ConsumerState<TransferPage> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  String? _selectedAssetKey;
  bool _hideZeroBalances = false;
  String? _formError;
  bool _isEstimating = false;
  bool _isMaxMode = false;
  FeeEstimate? _maxFeeEstimate;

  @override
  void initState() {
    super.initState();
    _recipientController.text =
        widget.initialRecipient ??
        ref.read(transferDraftControllerProvider).prefilledRecipient ??
        '';
    _amountController.text = widget.initialAmount ?? '';
    _memoController.text = widget.initialMemo ?? '';
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final portfolioValue = ref.watch(assetPortfolioProvider);
    final requestFuture = ref.watch(assetPortfolioRequestProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.transfer.title)),
      body: SafeArea(
        child: portfolioValue.when(
          data: (portfolio) {
            if (portfolio.status == AssetPortfolioStatus.locked) {
              return const AppErrorState(error: WalletError.walletLocked());
            }
            if (portfolio.status == AssetPortfolioStatus.error) {
              return AppErrorState(message: t.home.assetLoadError);
            }
            final balances = portfolio.balances
                .where((balance) => balance.status == AssetBalanceStatus.loaded)
                .toList();
            if (balances.isEmpty) {
              return AppEmptyState(message: t.transfer.noAssets);
            }
            final selectedAsset = _selectedAsset(balances);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageX,
                16,
                AppSpacing.pageX,
                24,
              ),
              children: [
                Semantics(
                  button: true,
                  label: t.transfer.selectedAsset,
                  child: InkWell(
                    key: const Key('transferAssetSelector'),
                    borderRadius: AppRadius.mediumBorder,
                    onTap: _isEstimating
                        ? null
                        : () => _showAssetPicker(
                            balances: balances,
                            selectedAsset: selectedAsset,
                          ),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: t.transfer.selectedAsset,
                        enabled: !_isEstimating,
                      ),
                      child: Row(
                        children: [
                          TokenIcon(
                            symbol: selectedAsset.token.symbol,
                            logoUri: selectedAsset.token.logoUri,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  selectedAsset.token.symbol,
                                  style: context.appTextStyles.bodyLarge,
                                ),
                                Text(
                                  selectedAsset.token.name,
                                  style: context.appTextStyles.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            selectedAsset.formattedBalance ??
                                selectedAsset.balance ??
                                '0',
                            style: context.appTextStyles.bodyMedium,
                          ),
                          const SizedBox(width: 4),
                          const Icon(AppIcons.chevronDown),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                  autocorrect: false,
                  controller: _recipientController,
                  enabled: !_isEstimating,
                  onChanged: (_) => _clearMaxMode(),
                  decoration: InputDecoration(
                    labelText: t.transfer.recipientLabel,
                    suffixIcon: IconButton(
                      onPressed: _isEstimating
                          ? null
                          : () async {
                              final requestContext = await requestFuture;
                              if (!context.mounted || requestContext == null) {
                                return;
                              }
                              final recipient = await showContactPickerSheet(
                                context,
                                chainType: requestContext.chain.chainType,
                                currentWalletId: requestContext.account.id,
                              );
                              if (!mounted) {
                                return;
                              }
                              if (recipient != null) {
                                setState(() {
                                  _recipientController.text = recipient.address;
                                  _formError = null;
                                  _isMaxMode = false;
                                  _maxFeeEstimate = null;
                                });
                              }
                            },
                      icon: const Icon(AppIcons.contacts),
                      tooltip: t.transfer.selectContact,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                  autocorrect: false,
                  controller: _amountController,
                  enabled: !_isEstimating,
                  onChanged: (_) => _clearMaxMode(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: t.transfer.amountLabel,
                    suffixIcon: TextButton(
                      onPressed: _isEstimating
                          ? null
                          : () => _applyMaxAmount(selectedAsset, requestFuture),
                      child: Text(t.transfer.max),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${t.transfer.balance}: '
                  '${selectedAsset.formattedBalance ?? selectedAsset.balance ?? '0'} '
                  '${selectedAsset.token.symbol}',
                  style: context.appTextStyles.caption,
                ),
                if (_maxFeeEstimate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${t.transfer.maximumFee}: '
                    '${formatTokenAmount(_maxFeeEstimate!.feeInBaseUnits, decimals: selectedAsset.token.decimals)} ${_maxFeeEstimate!.feeAssetSymbol}',
                    style: context.appTextStyles.caption,
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                  autocorrect: false,
                  controller: _memoController,
                  enabled: !_isEstimating,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: selectedAsset.token.requiresMemo
                        ? t.transfer.memoRequiredLabel
                        : t.transfer.memoLabel,
                    helperText: selectedAsset.token.requiresMemo
                        ? t.transfer.memoRequiredHelper
                        : t.transfer.memoOptionalHelper,
                  ),
                ),
                if (_formError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _formError!,
                    style: context.appTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                AppButton.primary(
                  label: t.transfer.next,
                  onPressed: _isEstimating
                      ? null
                      : () => _continue(selectedAsset, requestFuture),
                  icon: _isEstimating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.forward),
                ),
              ],
            );
          },
          error: (error, stackTrace) =>
              AppErrorState(message: t.home.assetLoadError),
          loading: () => AppLoadingState(message: t.home.loadingAssets),
        ),
      ),
    );
  }

  AssetBalance _selectedAsset(List<AssetBalance> balances) {
    final selectedKey = _selectedAssetKey;
    if (selectedKey == null) {
      final initialContractAddress = widget.initialContractAddress;
      if (initialContractAddress != null) {
        return balances.firstWhere(
          (balance) =>
              balance.token.contractAddress?.toLowerCase() ==
              initialContractAddress.toLowerCase(),
          orElse: () => balances.first,
        );
      }
      return balances.first;
    }
    return balances.firstWhere(
      (balance) => _assetKey(balance) == selectedKey,
      orElse: () => balances.first,
    );
  }

  Future<void> _showAssetPicker({
    required List<AssetBalance> balances,
    required AssetBalance selectedAsset,
  }) async {
    final selected = await showTransferAssetPickerSheet(
      context,
      balances: balances,
      selectedAssetKey: transferAssetKey(selectedAsset),
      hideZeroBalances: _hideZeroBalances,
      onHideZeroBalancesChanged: (value) {
        if (mounted) {
          setState(() {
            _hideZeroBalances = value;
          });
        }
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    final selectedAssetKey = transferAssetKey(selected);
    final assetChanged = selectedAssetKey != transferAssetKey(selectedAsset);
    setState(() {
      _selectedAssetKey = selectedAssetKey;
      if (assetChanged) {
        _amountController.clear();
      }
      _formError = null;
      _isMaxMode = false;
      _maxFeeEstimate = null;
    });
  }

  void _clearMaxMode() {
    if (!_isMaxMode && _maxFeeEstimate == null) {
      return;
    }
    setState(() {
      _isMaxMode = false;
      _maxFeeEstimate = null;
    });
  }

  Future<void> _applyMaxAmount(
    AssetBalance selectedAsset,
    Future<AssetPortfolioRequest?> requestFuture,
  ) async {
    final rawBalance = BigInt.tryParse(selectedAsset.balance ?? '');
    if (rawBalance == null) {
      setState(() {
        _formError = t.transfer.unavailableBalance;
      });
      return;
    }
    if (selectedAsset.token.contractAddress != null) {
      setState(() {
        _amountController.text = formatTokenAmount(
          rawBalance,
          decimals: selectedAsset.token.decimals,
        );
        _formError = null;
        _isMaxMode = true;
        _maxFeeEstimate = null;
      });
      return;
    }

    setState(() {
      _formError = null;
      _isEstimating = true;
    });
    try {
      final requestContext = await requestFuture;
      if (requestContext == null) {
        throw const TransferDraftValidationException(
          TransferDraftValidationFailure.unavailableBalance,
        );
      }
      final quote = await _quoteNativeMax(
        selectedAsset: selectedAsset,
        requestContext: requestContext,
        rawBalance: rawBalance,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _amountController.text = quote.request.amount;
        _isMaxMode = true;
        _maxFeeEstimate = quote.feeEstimate;
      });
    } on TransferDraftValidationException catch (error) {
      if (mounted) {
        setState(() {
          _formError = _draftErrorLabel(error.failure);
        });
      }
    } on TransferError catch (error) {
      if (mounted) {
        setState(() {
          _formError = error.code == 'insufficient_balance'
              ? t.transfer.insufficientBalance
              : t.transfer.feeFailed;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _formError = t.errors.unknown;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEstimating = false;
        });
      }
    }
  }

  Future<_MaxTransferQuote> _quoteNativeMax({
    required AssetBalance selectedAsset,
    required AssetPortfolioRequest requestContext,
    required BigInt rawBalance,
  }) async {
    var candidate = requestContext.chain.chainType == ChainType.bitcoin
        ? rawBalance
        : BigInt.one;
    for (var attempt = 0; attempt < 4; attempt += 1) {
      final request = ref
          .read(transferDraftControllerProvider.notifier)
          .prepareRequest(
            chain: requestContext.chain,
            asset: selectedAsset,
            recipient: _recipientController.text,
            amount: formatTokenAmount(
              candidate,
              decimals: selectedAsset.token.decimals,
            ),
            memo: _memoController.text,
          );
      final feeEstimate = await ref.read(
        feeEstimateProvider(
          FeeEstimateRequest(
            chain: requestContext.chain,
            rpcNode: requestContext.rpcNode,
            fromAddress: requestContext.account.addressForChainType(
              requestContext.chain.chainType,
            ),
            request: request,
            isMaxTransfer: true,
          ),
        ).future,
      );
      final nextCandidate = rawBalance - feeEstimate.feeInBaseUnits;
      if (nextCandidate <= BigInt.zero) {
        throw const TransferError.insufficientBalance();
      }
      if (nextCandidate == candidate) {
        return _MaxTransferQuote(request: request, feeEstimate: feeEstimate);
      }
      candidate = nextCandidate;
    }
    throw const TransferError.feeEstimateFailed();
  }

  Future<void> _continue(
    AssetBalance selectedAsset,
    Future<AssetPortfolioRequest?> requestFuture,
  ) async {
    setState(() {
      _formError = null;
      _isEstimating = true;
    });

    try {
      final requestContext = await requestFuture;
      if (requestContext == null) {
        throw const TransferDraftValidationException(
          TransferDraftValidationFailure.unavailableBalance,
        );
      }
      late TransactionRequest request;
      late FeeEstimate fee;
      final rawBalance = BigInt.tryParse(selectedAsset.balance ?? '');
      if (_isMaxMode &&
          selectedAsset.token.contractAddress == null &&
          rawBalance != null) {
        final quote = await _quoteNativeMax(
          selectedAsset: selectedAsset,
          requestContext: requestContext,
          rawBalance: rawBalance,
        );
        request = quote.request;
        fee = quote.feeEstimate;
        _amountController.text = request.amount;
        _maxFeeEstimate = fee;
      } else {
        request = ref
            .read(transferDraftControllerProvider.notifier)
            .prepareRequest(
              chain: requestContext.chain,
              asset: selectedAsset,
              recipient: _recipientController.text,
              amount: _amountController.text,
              memo: _memoController.text,
            );
        fee = await ref.read(
          feeEstimateProvider(
            FeeEstimateRequest(
              chain: requestContext.chain,
              rpcNode: requestContext.rpcNode,
              fromAddress: requestContext.account.addressForChainType(
                requestContext.chain.chainType,
              ),
              request: request,
            ),
          ).future,
        );
      }
      final confirmation = ref
          .read(transactionConfirmControllerProvider)
          .buildConfirmation(
            chain: requestContext.chain,
            account: requestContext.account,
            request: request,
            feeEstimate: fee,
            availableBalanceInBaseUnits: BigInt.tryParse(
              selectedAsset.balance ?? '',
            ),
          );
      var historicalRecipients = <String>[];
      try {
        final history = await ref
            .read(transactionHistoryRepositoryProvider)
            .list(chainId: requestContext.chain.chainId);
        historicalRecipients = history
            .where(
              (record) =>
                  record.direction == TransactionDirection.outgoing &&
                  record.toAddress != null,
            )
            .map((record) => record.toAddress!)
            .toList(growable: false);
      } catch (_) {
        // An unavailable history must not prevent a transfer confirmation.
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TransactionConfirmPage(
            chain: requestContext.chain,
            rpcNode: requestContext.rpcNode,
            account: requestContext.account,
            request: request,
            feeEstimate: fee,
            confirmation: confirmation,
            historicalRecipients: historicalRecipients,
          ),
        ),
      );
    } on TransferDraftValidationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _formError = _draftErrorLabel(error.failure);
      });
    } on TransferError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _formError = error.code == 'insufficient_balance'
            ? t.transfer.insufficientBalance
            : t.transfer.feeFailed;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _formError = t.errors.unknown;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isEstimating = false;
        });
      }
    }
  }

  String _draftErrorLabel(TransferDraftValidationFailure failure) {
    return switch (failure) {
      TransferDraftValidationFailure.invalidAddress =>
        t.transfer.invalidAddress,
      TransferDraftValidationFailure.invalidAmount => t.transfer.invalidAmount,
      TransferDraftValidationFailure.insufficientBalance =>
        t.transfer.insufficientBalance,
      TransferDraftValidationFailure.unavailableBalance =>
        t.transfer.unavailableBalance,
      TransferDraftValidationFailure.missingMemo => t.transfer.memoRequired,
    };
  }

  String _assetKey(AssetBalance balance) {
    return transferAssetKey(balance);
  }
}

final class _MaxTransferQuote {
  const _MaxTransferQuote({required this.request, required this.feeEstimate});

  final TransactionRequest request;
  final FeeEstimate feeEstimate;
}
