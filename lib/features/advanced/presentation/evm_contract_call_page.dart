import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_icons.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_action_sheet.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_picker_field.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/risk_notice.dart';
import '../../assets/application/asset_portfolio_provider.dart';
import '../../chains/application/available_chains_provider.dart';
import '../../chains/domain/chain_config.dart';
import '../../nodes/application/selected_rpc_node_provider.dart';
import '../../transfer/application/transaction_history_provider.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/presentation/signing_password_sheet.dart';
import '../application/evm_contract_call_controller.dart';
import '../data/evm_contract_call_gateway.dart';
import '../domain/evm_contract_abi.dart';

enum _ContractInputMode { standard, customAbi, manual, raw }

enum _StandardAbi { erc20, erc721, erc1155 }

final class EvmContractCallPage extends ConsumerStatefulWidget {
  const EvmContractCallPage({super.key});

  @override
  ConsumerState<EvmContractCallPage> createState() =>
      _EvmContractCallPageState();
}

final class _EvmContractCallPageState
    extends ConsumerState<EvmContractCallPage> {
  final _contractController = TextEditingController();
  final _abiController = TextEditingController();
  final _manualSignatureController = TextEditingController();
  final _manualOutputsController = TextEditingController();
  final _rawCalldataController = TextEditingController(text: '0x');
  final _nativeValueController = TextEditingController(text: '0');
  final _argumentControllers = <TextEditingController>[];

  _ContractInputMode _mode = _ContractInputMode.standard;
  _StandardAbi _standardAbi = _StandardAbi.erc20;
  late EvmContractAbi _abi;
  EvmContractFunction? _function;
  bool _manualRead = true;
  bool _manualPayable = false;
  bool _rawWrite = false;
  bool _isBusy = false;
  String? _selectedNetworkId;
  String? _error;
  EvmContractReadResult? _readResult;
  String? _transactionHash;

  @override
  void initState() {
    super.initState();
    _setAbi(EvmContractAbi.erc20);
  }

  @override
  void dispose() {
    _contractController.dispose();
    _abiController.dispose();
    _manualSignatureController.dispose();
    _manualOutputsController.dispose();
    _rawCalldataController.dispose();
    _nativeValueController.dispose();
    _disposeArgumentControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contextValue = ref.watch(assetPortfolioRequestValueProvider);
    final currentRequest = contextValue.value;
    final networksValue = ref.watch(availableChainsProvider);
    final networks = networksValue.value
            ?.where((chain) => chain.chainType == ChainType.evm)
            .toList(growable: false) ??
        const <ChainConfig>[];
    final selectedNetwork = _selectedNetwork(networks, currentRequest?.chain);
    final selectedRpcNode = selectedNetwork == null
        ? null
        : currentRequest?.chain == selectedNetwork
            ? currentRequest?.rpcNode
            : ref.watch(selectedResolvedRpcNodeProvider(selectedNetwork)).value;
    final request = currentRequest == null ||
            selectedNetwork == null ||
            selectedRpcNode == null
        ? null
        : AssetPortfolioRequest(
            account: currentRequest.account,
            chain: selectedNetwork,
            rpcNode: selectedRpcNode,
          );
    final strings = context.t.advanced;
    final hasWallet = request != null && request.account.evmAddress.isNotEmpty;
    final canExecute = hasWallet && !_isBusy;
    final isWrite = _isWrite;

    return Scaffold(
      appBar: AppBar(title: Text(strings.contractCall)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            AppSpacing.sectionY,
            AppSpacing.pageX,
            AppSpacing.pageX,
          ),
          children: [
            if (currentRequest == null ||
                currentRequest.account.evmAddress.isEmpty) ...[
              RiskNotice(
                level: RiskLevel.warning,
                message: strings.walletRequired,
              ),
            ],
            const SizedBox(height: AppSpacing.sectionY),
            AppSectionCard(
              padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
              borderRadius: AppRadius.xLargeBorder,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppPickerField(
                    key: const Key('evmContractNetworkPicker'),
                    label: strings.chain,
                    value: selectedNetwork?.name ?? strings.chain,
                    leading: const Icon(AppIcons.network),
                    onTap: _isBusy || selectedNetwork == null
                        ? null
                        : () => _showNetworkSheet(
                              networks,
                              selectedNetwork,
                            ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('evmContractAddressInput'),
                    controller: _contractController,
                    autocorrect: false,
                    enableSuggestions: false,
                    spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                    decoration: InputDecoration(
                      labelText: strings.contractAddress,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppPickerField(
                    key: const Key('evmContractModePicker'),
                    label: strings.callMode,
                    value: _modeLabel(_mode),
                    leading: Icon(_modeIcon(_mode)),
                    onTap: _isBusy ? null : _showModeSheet,
                  ),
                  const SizedBox(height: 14),
                  ..._modeFields(),
                ],
              ),
            ),
            if (_mode != _ContractInputMode.raw && _function != null) ...[
              const SizedBox(height: AppSpacing.sectionY),
              _FunctionCard(
                function: _function!,
                argumentControllers: _argumentControllers,
                onFunctionChanged: _selectFunction,
                functions: _abi.functions,
              ),
            ],
            if (isWrite) ...[
              const SizedBox(height: AppSpacing.sectionY),
              RiskNotice(level: RiskLevel.danger, message: strings.writeRisk),
            ],
            if (_showsNativeValue) ...[
              const SizedBox(height: AppSpacing.sectionY),
              TextField(
                key: const Key('evmContractNativeValueInput'),
                controller: _nativeValueController,
                autocorrect: false,
                enableSuggestions: false,
                spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      '${strings.nativeValue} (${selectedNetwork?.symbol ?? 'ETH'})',
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sectionY),
            AppButton.primary(
              key: const Key('evmContractExecuteButton'),
              label: isWrite ? strings.prepareWrite : strings.executeRead,
              icon: _isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isWrite ? AppIcons.send : AppIcons.search, size: 18),
              onPressed: canExecute ? () => _execute(request) : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sectionY),
              Text(
                _error!,
                key: const Key('evmContractCallError'),
                style:
                    context.appTextStyles.bodySmall.copyWith(color: AppColors.danger),
              ),
            ],
            if (_readResult != null) ...[
              const SizedBox(height: AppSpacing.sectionY),
              _ResultCard(result: _readResult!),
            ],
            if (_transactionHash != null) ...[
              const SizedBox(height: AppSpacing.sectionY),
              AppSectionCard(
                padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
                borderRadius: AppRadius.xLargeBorder,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.submitted, style: context.appTextStyles.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      '${strings.transactionHash}: $_transactionHash',
                      key: const Key('evmContractTransactionHash'),
                      style: context.appTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _modeFields() {
    final strings = context.t.advanced;
    return switch (_mode) {
      _ContractInputMode.standard => [
          AppPickerField(
            key: const Key('evmStandardAbiPicker'),
            label: strings.standardTemplate,
            value: _standardLabel(_standardAbi),
            leading: const Icon(AppIcons.article),
            onTap: _isBusy ? null : _showStandardAbiSheet,
          ),
        ],
      _ContractInputMode.customAbi => [
          TextField(
            key: const Key('evmCustomAbiInput'),
            controller: _abiController,
            minLines: 6,
            maxLines: 12,
            autocorrect: false,
            enableSuggestions: false,
            spellCheckConfiguration: SpellCheckConfiguration.disabled(),
            decoration: InputDecoration(labelText: strings.abiJson),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppButton.secondary(
              label: strings.parseAbi,
              icon: const Icon(AppIcons.code, size: 18),
              onPressed: _parseCustomAbi,
            ),
          ),
        ],
      _ContractInputMode.manual => [
          TextField(
            key: const Key('evmManualSignatureInput'),
            controller: _manualSignatureController,
            autocorrect: false,
            enableSuggestions: false,
            spellCheckConfiguration: SpellCheckConfiguration.disabled(),
            decoration: InputDecoration(labelText: strings.manualSignature),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('evmManualOutputsInput'),
            controller: _manualOutputsController,
            autocorrect: false,
            enableSuggestions: false,
            spellCheckConfiguration: SpellCheckConfiguration.disabled(),
            decoration: InputDecoration(labelText: strings.outputTypes),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.readFunction),
            value: _manualRead,
            onChanged: (value) {
              setState(() {
                _manualRead = value;
                if (value) {
                  _manualPayable = false;
                }
              });
            },
          ),
          if (!_manualRead)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.payableFunction),
              value: _manualPayable,
              onChanged: (value) {
                setState(() {
                  _manualPayable = value;
                });
              },
            ),
          SizedBox(
            width: double.infinity,
            child: AppButton.secondary(
              label: strings.buildFunction,
              icon: const Icon(AppIcons.tools, size: 18),
              onPressed: _buildManualFunction,
            ),
          ),
        ],
      _ContractInputMode.raw => [
          TextField(
            key: const Key('evmRawCalldataInput'),
            controller: _rawCalldataController,
            minLines: 3,
            maxLines: 8,
            autocorrect: false,
            enableSuggestions: false,
            spellCheckConfiguration: SpellCheckConfiguration.disabled(),
            decoration: InputDecoration(labelText: strings.rawCalldata),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.rawWrite),
            value: _rawWrite,
            onChanged: (value) {
              setState(() {
                _rawWrite = value;
              });
            },
          ),
        ],
    };
  }

  bool get _isWrite => _mode == _ContractInputMode.raw
      ? _rawWrite
      : !(_function?.isRead ?? true);

  bool get _showsNativeValue => _mode == _ContractInputMode.raw
      ? _rawWrite
      : (_function?.isPayable ?? false);

  void _changeMode(_ContractInputMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _readResult = null;
      _transactionHash = null;
      if (mode == _ContractInputMode.standard) {
        _setAbi(_abiForStandard(_standardAbi));
      } else {
        _function = null;
        _disposeArgumentControllers();
      }
    });
  }

  void _selectStandardAbi(_StandardAbi standard) {
    setState(() {
      _standardAbi = standard;
      _setAbi(_abiForStandard(standard));
    });
  }

  void _parseCustomAbi() {
    try {
      final abi = EvmContractAbi.parse(_abiController.text);
      setState(() {
        _setAbi(abi);
        _error = null;
      });
    } catch (_) {
      setState(() {
        _error = context.t.advanced.invalidAbi;
      });
    }
  }

  void _buildManualFunction() {
    try {
      final function = EvmContractAbi.manualFunction(
        signature: _manualSignatureController.text,
        outputTypes: _manualOutputsController.text,
        isRead: _manualRead,
        payable: _manualPayable,
      );
      setState(() {
        _abi = EvmContractAbi.parse(_singleFunctionAbi(function));
        _selectFunction(_abi.functions.single, notify: false);
        _error = null;
      });
    } catch (_) {
      setState(() {
        _error = context.t.advanced.invalidAbi;
      });
    }
  }

  String _singleFunctionAbi(EvmContractFunction function) {
    final mutability = function.isRead
        ? 'view'
        : (function.isPayable ? 'payable' : 'nonpayable');
    return '[{"type":"function","name":"${function.name}",'
        '"stateMutability":"$mutability",'
        '"inputs":[${function.inputs.asMap().entries.map((entry) => '{"name":"arg${entry.key}","type":"${entry.value.type}"}').join(',')}],'
        '"outputs":[${function.outputs.asMap().entries.map((entry) => '{"name":"result${entry.key}","type":"${entry.value.type}"}').join(',')}]}]';
  }

  void _setAbi(EvmContractAbi abi) {
    _abi = abi;
    _selectFunction(abi.readFunctions.firstOrNull ?? abi.functions.first,
        notify: false);
  }

  void _selectFunction(
    EvmContractFunction function, {
    bool notify = true,
  }) {
    void update() {
      _function = function;
      _disposeArgumentControllers();
      for (var index = 0; index < function.inputs.length; index += 1) {
        _argumentControllers.add(TextEditingController());
      }
      _nativeValueController.text = '0';
      _readResult = null;
      _transactionHash = null;
    }

    if (notify) {
      setState(update);
    } else {
      update();
    }
  }

  void _disposeArgumentControllers() {
    for (final controller in _argumentControllers) {
      controller.dispose();
    }
    _argumentControllers.clear();
  }

  Future<void> _execute(AssetPortfolioRequest request) async {
    final function = _function;
    try {
      final calldata = _mode == _ContractInputMode.raw
          ? _rawCalldataController.text.trim()
          : function!.encodeCall(
              _argumentControllers
                  .map((controller) => controller.text)
                  .toList(),
            );
      final contractAddress = _contractController.text.trim();
      setState(() {
        _isBusy = true;
        _error = null;
        _readResult = null;
        _transactionHash = null;
      });
      final controller = ref.read(evmContractCallControllerProvider);
      if (!_isWrite) {
        final result = await controller.read(
          context: request,
          contractAddress: contractAddress,
          calldata: calldata,
          function: function,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _readResult = result;
        });
        return;
      }

      final valueWei = _parseUnits(_nativeValueController.text, 18);
      if (valueWei == null || valueWei < BigInt.zero) {
        throw const FormatException('Invalid native value');
      }
      final preparation = await controller.prepareWrite(
        context: request,
        contractAddress: contractAddress,
        calldata: calldata,
        valueWei: valueWei,
      );
      if (!mounted) {
        return;
      }
      final confirmed = await _confirmWrite(
        request,
        preparation,
        function?.signature,
      );
      if (!mounted || !confirmed) {
        return;
      }

      final cache = ref.read(sessionKeyCacheProvider);
      SigningPasswordAuthorization? authorization;
      if (!cache.hasKey(request.account.id, now: DateTime.now().toUtc())) {
        authorization = await showSigningPasswordSheet(context);
        if (!mounted || authorization == null) {
          return;
        }
      }
      final hash = await controller.submitWrite(
        context: request,
        preparation: preparation,
        functionSignature: function?.signature,
        signingPassword: authorization?.password,
        rememberSigningPassword: authorization?.rememberPassword ?? true,
      );
      ref.invalidate(transactionHistoryProvider(request.chain.chainId));
      ref.invalidate(transactionHistoryProvider(null));
      ref.invalidate(recentTransactionsProvider);
      if (!mounted) {
        return;
      }
      setState(() {
        _transactionHash = hash;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _localizedError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<bool> _confirmWrite(
    AssetPortfolioRequest request,
    EvmContractWritePreparation preparation,
    String? signature,
  ) async {
    final strings = context.t.advanced;
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: strings.confirmWriteTitle,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RiskNotice(level: RiskLevel.danger, message: strings.writeRisk),
            const SizedBox(height: 12),
            _ConfirmationLine(label: strings.chain, value: request.chain.name),
            _ConfirmationLine(
              label: strings.contractAddress,
              value: preparation.contractAddress,
            ),
            _ConfirmationLine(
              label: strings.method,
              value: signature ?? strings.modeRaw,
            ),
            _ConfirmationLine(
              label: strings.value,
              value:
                  '${_formatUnits(preparation.valueWei, 18)} ${request.chain.symbol}',
            ),
            _ConfirmationLine(
              label: strings.gasLimit,
              value: preparation.gasLimit.toString(),
            ),
            _ConfirmationLine(
              label: strings.gasPrice,
              value: '${_formatUnits(preparation.gasPriceWei, 9)} Gwei',
            ),
            _ConfirmationLine(
              label: strings.estimatedFee,
              value:
                  '${_formatUnits(preparation.estimatedFeeWei, 18)} ${request.chain.symbol}',
            ),
            _ConfirmationLine(
              label: 'Calldata',
              value: preparation.calldata,
            ),
          ],
        ),
      ),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmTitle: strings.confirmAndSign,
      confirmCallback: () => Navigator.of(context).pop(true),
    );
    return confirmed == true;
  }

  String _localizedError(Object error) {
    final strings = context.t.advanced;
    if (error is EvmContractCallException) {
      return switch (error.code) {
        'notContract' => strings.notContract,
        'walletLocked' => strings.walletLocked,
        'unsupportedChain' => strings.callFailed,
        _ => strings.callFailed,
      };
    }
    if (error is EvmContractAbiException || error is FormatException) {
      return strings.invalidInput;
    }
    return strings.callFailed;
  }

  String _modeLabel(_ContractInputMode mode) {
    final strings = context.t.advanced;
    return switch (mode) {
      _ContractInputMode.standard => strings.modeStandard,
      _ContractInputMode.customAbi => strings.modeCustomAbi,
      _ContractInputMode.manual => strings.modeManual,
      _ContractInputMode.raw => strings.modeRaw,
    };
  }

  String _standardLabel(_StandardAbi standard) {
    final strings = context.t.advanced;
    return switch (standard) {
      _StandardAbi.erc20 => strings.erc20,
      _StandardAbi.erc721 => strings.erc721,
      _StandardAbi.erc1155 => strings.erc1155,
    };
  }

  IconData _modeIcon(_ContractInputMode mode) {
    return switch (mode) {
      _ContractInputMode.standard => AppIcons.article,
      _ContractInputMode.customAbi => AppIcons.paste,
      _ContractInputMode.manual => AppIcons.tools,
      _ContractInputMode.raw => AppIcons.code,
    };
  }

  Future<void> _showNetworkSheet(
    List<ChainConfig> networks,
    ChainConfig selectedNetwork,
  ) async {
    final network = await showAppActionSheet<ChainConfig>(
      context,
      title: context.t.advanced.chain,
      actions: [
        for (final network in networks)
          AppActionSheetAction<ChainConfig>(
            value: network,
            title: network.name,
            icon: AppIcons.network,
            isSelected: network == selectedNetwork,
          ),
      ],
    );
    if (!mounted || network == null || network == selectedNetwork) {
      return;
    }
    setState(() {
      _selectedNetworkId = network.id;
      _error = null;
      _readResult = null;
      _transactionHash = null;
    });
  }

  Future<void> _showModeSheet() async {
    final mode = await showAppActionSheet<_ContractInputMode>(
      context,
      title: context.t.advanced.callMode,
      actions: [
        for (final mode in _ContractInputMode.values)
          AppActionSheetAction<_ContractInputMode>(
            value: mode,
            title: _modeLabel(mode),
            icon: _modeIcon(mode),
            isSelected: mode == _mode,
          ),
      ],
    );
    if (!mounted || mode == null || mode == _mode) {
      return;
    }
    _changeMode(mode);
  }

  Future<void> _showStandardAbiSheet() async {
    final standard = await showAppActionSheet<_StandardAbi>(
      context,
      title: context.t.advanced.standardTemplate,
      actions: [
        for (final standard in _StandardAbi.values)
          AppActionSheetAction<_StandardAbi>(
            value: standard,
            title: _standardLabel(standard),
            icon: AppIcons.article,
            isSelected: standard == _standardAbi,
          ),
      ],
    );
    if (!mounted || standard == null || standard == _standardAbi) {
      return;
    }
    _selectStandardAbi(standard);
  }

  ChainConfig? _selectedNetwork(
    List<ChainConfig> networks,
    ChainConfig? currentChain,
  ) {
    final selectedId = _selectedNetworkId;
    if (selectedId != null) {
      return networks.where((chain) => chain.id == selectedId).firstOrNull;
    }
    if (currentChain?.chainType == ChainType.evm) {
      final currentId = currentChain!.id;
      final matchingCurrent =
          networks.where((chain) => chain.id == currentId).firstOrNull;
      if (matchingCurrent != null) {
        return matchingCurrent;
      }
    }
    return networks.firstOrNull;
  }
}

final class _FunctionCard extends StatelessWidget {
  const _FunctionCard({
    required this.function,
    required this.functions,
    required this.argumentControllers,
    required this.onFunctionChanged,
  });

  final EvmContractFunction function;
  final List<EvmContractFunction> functions;
  final List<TextEditingController> argumentControllers;
  final ValueChanged<EvmContractFunction> onFunctionChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.advanced;
    return AppSectionCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
      borderRadius: AppRadius.xLargeBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPickerField(
            key: const Key('evmContractFunctionPicker'),
            label: strings.function,
            value: _functionLabel(context, function),
            leading: Icon(function.isRead ? AppIcons.search : AppIcons.send),
            onTap: () => _showFunctionSheet(context),
          ),
          for (var index = 0; index < function.inputs.length; index += 1) ...[
            const SizedBox(height: 12),
            TextField(
              key: Key('evmContractArgument$index'),
              controller: argumentControllers[index],
              autocorrect: false,
              enableSuggestions: false,
              spellCheckConfiguration: SpellCheckConfiguration.disabled(),
              decoration: InputDecoration(
                labelText: strings.argument(
                  index: index + 1,
                  name: function.inputs[index].name.isEmpty
                      ? 'arg$index'
                      : function.inputs[index].name,
                  type: function.inputs[index].type,
                ),
                helperText: function.inputs[index].type.contains('[') ||
                        function.inputs[index].type.startsWith('tuple')
                    ? strings.arrayArgumentHint
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _functionLabel(
    BuildContext context,
    EvmContractFunction item,
  ) {
    final strings = context.t.advanced;
    return '${item.isRead ? strings.readBadge : strings.writeBadge} · '
        '${item.signature}';
  }

  Future<void> _showFunctionSheet(BuildContext context) async {
    final strings = context.t.advanced;
    final selected = await showAppActionSheet<EvmContractFunction>(
      context,
      title: strings.function,
      actions: [
        for (final item in functions)
          AppActionSheetAction<EvmContractFunction>(
            value: item,
            title: _functionLabel(context, item),
            icon: item.isRead ? AppIcons.search : AppIcons.send,
            isSelected: item == function,
          ),
      ],
    );
    if (!context.mounted || selected == null || selected == function) {
      return;
    }
    onFunctionChanged(selected);
  }
}

final class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final EvmContractReadResult result;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.advanced;
    final rawResultText = '${strings.rawResult}: ${result.rawValue}';
    return AppSectionCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
      borderRadius: AppRadius.xLargeBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.result, style: context.appTextStyles.titleMedium),
          if (result.decodedValues.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var index = 0; index < result.decodedValues.length; index += 1)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: SelectableText(
                      '${index + 1}. ${result.decodedValues[index]}',
                      style: context.appTextStyles.bodySmall,
                    ),
                  ),
                  IconButton(
                    key: Key('evmContractCopyResult$index'),
                    tooltip: strings.copyResult,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(AppIcons.copy, size: 18),
                    onPressed: () => _copyResult(
                      context,
                      result.decodedValues[index],
                    ),
                  ),
                ],
              ),
          ],
          const SizedBox(height: 8),
          Text(rawResultText, style: context.appTextStyles.caption),
        ],
      ),
    );
  }

  Future<void> _copyResult(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    AppToast.show(
      context,
      message: context.t.advanced.resultCopied,
      variant: AppToastVariant.success,
    );
  }
}

final class _ConfirmationLine extends StatelessWidget {
  const _ConfirmationLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.appTextStyles.caption),
          const SizedBox(height: 2),
          SelectableText(value, style: context.appTextStyles.bodySmall),
        ],
      ),
    );
  }
}

EvmContractAbi _abiForStandard(_StandardAbi standard) {
  return switch (standard) {
    _StandardAbi.erc20 => EvmContractAbi.erc20,
    _StandardAbi.erc721 => EvmContractAbi.erc721,
    _StandardAbi.erc1155 => EvmContractAbi.erc1155,
  };
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
  final paddedFraction = fraction.padRight(decimals, '0');
  return BigInt.parse(parts[0]) * base +
      BigInt.parse(paddedFraction.isEmpty ? '0' : paddedFraction);
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
