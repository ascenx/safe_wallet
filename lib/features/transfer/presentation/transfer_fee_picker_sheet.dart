import 'package:flutter/material.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_brand_colors.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_drag_handle.dart';
import '../application/fee_estimate_provider.dart';
import '../domain/transaction_request.dart';

Future<FeeEstimate?> showTransferFeePickerSheet(
  BuildContext context, {
  required FeeEstimate feeEstimate,
  required TransactionRequest request,
}) {
  return showModalBottomSheet<FeeEstimate>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: context.appColors.surface,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.xLarge),
      ),
    ),
    builder: (_) => TransferFeePickerSheet(
      feeEstimate: feeEstimate,
      request: request,
    ),
  );
}

final class TransferFeePickerSheet extends StatefulWidget {
  const TransferFeePickerSheet({
    required this.feeEstimate,
    required this.request,
    super.key,
  });

  final FeeEstimate feeEstimate;
  final TransactionRequest request;

  @override
  State<TransferFeePickerSheet> createState() => _TransferFeePickerSheetState();
}

final class _TransferFeePickerSheetState extends State<TransferFeePickerSheet> {
  late FeeSpeed _selectedSpeed;
  late final TextEditingController _primaryController;
  late final TextEditingController _secondaryController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedSpeed = widget.feeEstimate.speed;
    _primaryController = TextEditingController(text: _initialPrimaryValue());
    _secondaryController =
        TextEditingController(text: _initialSecondaryValue());
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pageX,
          0,
          AppSpacing.pageX,
          20 + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppDragHandle(),
            Text(t.transfer.feeSettings, style: context.appTextStyles.titleLarge),
            const SizedBox(height: 16),
            for (final option in widget.feeEstimate.options)
              if (option.speed != FeeSpeed.custom) ...[
                _FeeOptionRow(
                  key: ValueKey('feeOption:${option.speed.name}'),
                  speed: option.speed,
                  value: _optionValue(option),
                  hint: _optionHint(option),
                  selected: _selectedSpeed == option.speed,
                  onTap: () {
                    Navigator.of(context).pop(
                      widget.feeEstimate.selectSpeed(option.speed),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            if (_supportsCustomFee)
              _FeeOptionRow(
                key: const Key('feeOption:custom'),
                speed: FeeSpeed.custom,
                value: _customSummary(),
                hint: t.transfer.feeCustomHint,
                selected: _selectedSpeed == FeeSpeed.custom,
                onTap: () {
                  setState(() {
                    _selectedSpeed = FeeSpeed.custom;
                    _error = null;
                  });
                },
              ),
            if (_supportsCustomFee && _selectedSpeed == FeeSpeed.custom) ...[
              const SizedBox(height: 16),
              ..._customFields(),
              if (_feeAdvisory != null) ...[
                const SizedBox(height: 8),
                Text(
                  _feeAdvisory!,
                  key: const Key('customFeeAdvisory'),
                  style: context.appTextStyles.caption.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  key: const Key('customFeeError'),
                  style: context.appTextStyles.caption.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              AppButton.primary(
                key: const Key('applyCustomFee'),
                label: t.transfer.applyFee,
                onPressed: _applyCustomFee,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _customFields() {
    return switch (widget.feeEstimate.model) {
      FeeModel.eip1559 => [
          _numberField(
            key: const Key('customMaxFeeGwei'),
            controller: _primaryController,
            label: t.transfer.maxFeeGwei,
          ),
          const SizedBox(height: 12),
          _numberField(
            key: const Key('customPriorityFeeGwei'),
            controller: _secondaryController,
            label: t.transfer.priorityFeeGwei,
          ),
        ],
      FeeModel.legacy => [
          _numberField(
            key: const Key('customGasPriceGwei'),
            controller: _primaryController,
            label: t.transfer.gasPriceGwei,
          ),
        ],
      FeeModel.solana => [
          _numberField(
            key: const Key('customSolanaPriorityFee'),
            controller: _primaryController,
            label: t.transfer.priorityFeeSol,
          ),
        ],
      FeeModel.bitcoin => [
          _numberField(
            key: const Key('customBitcoinFeeRate'),
            controller: _primaryController,
            label: t.transfer.bitcoinFeeRate,
          ),
        ],
      FeeModel.tron => [
          _numberField(
            key: const Key('customTronFeeLimit'),
            controller: _primaryController,
            label: t.transfer.tronFeeLimit,
          ),
        ],
      FeeModel.sui => const [],
    };
  }

  bool get _supportsCustomFee => widget.feeEstimate.model != FeeModel.sui;

  Widget _numberField({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      key: key,
      controller: controller,
      autocorrect: false,
      enableSuggestions: false,
      spellCheckConfiguration: SpellCheckConfiguration.disabled(),
      onChanged: (_) {
        setState(() => _error = null);
      },
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }

  void _applyCustomFee() {
    try {
      final estimate = switch (widget.feeEstimate.model) {
        FeeModel.eip1559 => _customEip1559(),
        FeeModel.legacy => _customLegacy(),
        FeeModel.solana => _customSolana(),
        FeeModel.bitcoin => _customBitcoin(),
        FeeModel.tron => _customTron(),
        FeeModel.sui => throw StateError('Sui gas budget is simulation-based'),
      };
      Navigator.of(context).pop(estimate);
    } on _FeeInputException catch (error) {
      setState(() => _error = error.message);
    } on ArgumentError {
      setState(() => _error = t.transfer.invalidFee);
    }
  }

  FeeEstimate _customEip1559() {
    final maxFee = _requiredUnits(_primaryController.text, 9);
    final priority = _requiredUnits(_secondaryController.text, 9);
    if (maxFee < priority) {
      throw _FeeInputException(t.transfer.maxFeeBelowPriority);
    }
    return widget.feeEstimate.withEvmCustomFee(
      maxFeePerGasWei: maxFee,
      maxPriorityFeePerGasWei: priority,
    );
  }

  FeeEstimate _customLegacy() {
    return widget.feeEstimate.withLegacyCustomGasPrice(
      gasPriceWei: _requiredUnits(_primaryController.text, 9),
    );
  }

  FeeEstimate _customSolana() {
    final limit = widget.feeEstimate.computeUnitLimit;
    if (limit == null || limit <= 0) {
      throw _FeeInputException(t.transfer.invalidFee);
    }
    return widget.feeEstimate.withSolanaCustomPriorityFee(
      totalPriorityFeeLamports: _requiredUnits(
        _primaryController.text,
        9,
        allowZero: true,
      ),
      computeUnitLimit: limit,
    );
  }

  FeeEstimate _customBitcoin() {
    final rate = double.tryParse(_primaryController.text.trim());
    final vbytes = widget.feeEstimate.transactionVbytes;
    if (rate == null || !rate.isFinite || rate <= 0 || vbytes == null) {
      throw _FeeInputException(t.transfer.invalidFee);
    }
    return widget.feeEstimate.withBitcoinCustomFeeRate(
      satsPerVbyte: rate,
      transactionVbytes: vbytes,
    );
  }

  FeeEstimate _customTron() {
    final feeLimit = _requiredUnits(_primaryController.text, 6);
    if (feeLimit < widget.feeEstimate.estimatedFeeInBaseUnits) {
      throw _FeeInputException(t.transfer.feeLimitBelowEstimate);
    }
    return widget.feeEstimate.withTronFeeLimit(
      feeLimitSun: feeLimit,
    );
  }

  String _initialPrimaryValue() {
    return switch (widget.feeEstimate.model) {
      FeeModel.eip1559 =>
        _formatUnits(widget.feeEstimate.maxFeePerGasWei ?? BigInt.zero, 9),
      FeeModel.legacy =>
        _formatUnits(widget.feeEstimate.gasPriceWei ?? BigInt.zero, 9),
      FeeModel.solana => _formatUnits(
          widget.feeEstimate.priorityFeeInBaseUnits ?? BigInt.zero,
          9,
        ),
      FeeModel.bitcoin => widget.feeEstimate.satsPerVbyte?.toString() ?? '',
      FeeModel.tron =>
        _formatUnits(widget.feeEstimate.feeLimitSun ?? BigInt.zero, 6),
      FeeModel.sui => '',
    };
  }

  String _initialSecondaryValue() {
    if (widget.feeEstimate.model != FeeModel.eip1559) {
      return '';
    }
    return _formatUnits(
      widget.feeEstimate.maxPriorityFeePerGasWei ?? BigInt.zero,
      9,
    );
  }

  String _optionValue(FeeOption option) {
    return switch (widget.feeEstimate.model) {
      FeeModel.eip1559 =>
        '${_formatUnits(option.maxFeePerGasWei ?? BigInt.zero, 9)} Gwei',
      FeeModel.legacy =>
        '${_formatUnits(option.gasPriceWei ?? BigInt.zero, 9)} Gwei',
      FeeModel.solana =>
        '${_formatUnits(option.priorityFeeInBaseUnits ?? BigInt.zero, 9)} SOL',
      FeeModel.bitcoin => '${_formatRate(option.satsPerVbyte)} sat/vB',
      FeeModel.tron =>
        '${_formatUnits(option.feeInBaseUnits, 6)} ${widget.feeEstimate.feeAssetSymbol}',
      FeeModel.sui =>
        '${_formatUnits(option.feeInBaseUnits, 9)} ${widget.feeEstimate.feeAssetSymbol}',
    };
  }

  String _customSummary() {
    return switch (widget.feeEstimate.model) {
      FeeModel.eip1559 || FeeModel.legacy => 'Gwei',
      FeeModel.solana => 'SOL',
      FeeModel.bitcoin => 'sat/vB',
      FeeModel.tron => 'TRX',
      FeeModel.sui => 'SUI',
    };
  }

  String _optionHint(FeeOption option) {
    final blocks = option.confirmationBlocks;
    if (widget.feeEstimate.model == FeeModel.bitcoin && blocks != null) {
      return '${t.transfer.approximately} $blocks ${t.transfer.blocks}';
    }
    return _speedHint(option.speed);
  }

  String? get _feeAdvisory {
    if (widget.feeEstimate.model != FeeModel.eip1559) {
      return null;
    }
    final maxFee = _parseUnits(_primaryController.text, 9);
    final priority = _parseUnits(_secondaryController.text, 9);
    final baseFee = widget.feeEstimate.baseFeePerGasWei;
    if (maxFee == null || priority == null || baseFee == null) {
      return null;
    }
    if (maxFee < baseFee + priority) {
      return t.transfer.feeTooLow;
    }
    final standardMax = widget.feeEstimate.options
        .where((option) => option.speed == FeeSpeed.standard)
        .map((option) => option.maxFeePerGasWei)
        .whereType<BigInt>()
        .firstOrNull;
    final reference = standardMax ?? widget.feeEstimate.maxFeePerGasWei;
    if (reference != null && maxFee > reference * BigInt.from(5)) {
      return t.transfer.feeVeryHigh;
    }
    return null;
  }
}

final class _FeeOptionRow extends StatelessWidget {
  const _FeeOptionRow({
    required this.speed,
    required this.value,
    required this.hint,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final FeeSpeed speed;
  final String value;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected
              ? context.brandColors.primarySoft
              : context.appColors.surfaceSoft,
          borderRadius: AppRadius.mediumBorder,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : context.appColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: AppRadius.mediumBorder,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_speedLabel(speed), style: context.appTextStyles.bodyMedium),
                      const SizedBox(height: 2),
                      Text(hint, style: context.appTextStyles.caption),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  value,
                  style: context.appTextStyles.bodySmall.copyWith(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _speedLabel(FeeSpeed speed) {
  return switch (speed) {
    FeeSpeed.economy => t.transfer.feeEconomy,
    FeeSpeed.standard => t.transfer.feeStandard,
    FeeSpeed.fast => t.transfer.feeFast,
    FeeSpeed.custom => t.transfer.feeCustom,
  };
}

String _speedHint(FeeSpeed speed) {
  return switch (speed) {
    FeeSpeed.economy => t.transfer.feeEconomyHint,
    FeeSpeed.standard => t.transfer.feeStandardHint,
    FeeSpeed.fast => t.transfer.feeFastHint,
    FeeSpeed.custom => t.transfer.feeCustomHint,
  };
}

BigInt _requiredUnits(
  String input,
  int decimals, {
  bool allowZero = false,
}) {
  final value = _parseUnits(input, decimals);
  if (value == null ||
      (allowZero ? value < BigInt.zero : value <= BigInt.zero)) {
    throw _FeeInputException(t.transfer.invalidFee);
  }
  return value;
}

BigInt? _parseUnits(String input, int decimals) {
  final normalized = input.trim();
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(normalized)) {
    return null;
  }
  final parts = normalized.split('.');
  final fraction = parts.length == 1 ? '' : parts[1];
  if (fraction.length > decimals) {
    return null;
  }
  final base = BigInt.from(10).pow(decimals);
  return BigInt.parse(parts[0]) * base +
      BigInt.parse((fraction.padRight(decimals, '0')).isEmpty
          ? '0'
          : fraction.padRight(decimals, '0'));
}

String _formatUnits(BigInt value, int decimals) {
  final base = BigInt.from(10).pow(decimals);
  final whole = value ~/ base;
  final fraction = (value % base)
      .toString()
      .padLeft(decimals, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? '$whole' : '$whole.$fraction';
}

String _formatRate(double? value) {
  if (value == null) {
    return '0';
  }
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

final class _FeeInputException implements Exception {
  const _FeeInputException(this.message);

  final String message;
}
