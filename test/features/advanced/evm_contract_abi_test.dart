import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/advanced/domain/evm_contract_abi.dart';

void main() {
  test('parses ABI functions into read and write groups', () {
    final abi = EvmContractAbi.parse('''
[
  {
    "type": "function",
    "name": "balanceOf",
    "stateMutability": "view",
    "inputs": [{"name": "account", "type": "address"}],
    "outputs": [{"name": "balance", "type": "uint256"}]
  },
  {
    "type": "function",
    "name": "transfer",
    "stateMutability": "nonpayable",
    "inputs": [
      {"name": "to", "type": "address"},
      {"name": "amount", "type": "uint256"}
    ],
    "outputs": [{"name": "success", "type": "bool"}]
  }
]
''');

    expect(abi.readFunctions.map((item) => item.signature), [
      'balanceOf(address)',
    ]);
    expect(abi.writeFunctions.map((item) => item.signature), [
      'transfer(address,uint256)',
    ]);
  });

  test('encodes address and integer arguments for a contract call', () {
    final function = EvmContractAbi.erc20.functions.firstWhere(
      (item) => item.signature == 'transfer(address,uint256)',
    );

    final calldata = function.encodeCall([
      '0x1111111111111111111111111111111111111111',
      '42',
    ]);

    expect(calldata, startsWith('0xa9059cbb'));
    expect(calldata.length, 138);
  });

  test('decodes and formats a uint256 return value', () {
    final function = EvmContractAbi.erc20.functions.firstWhere(
      (item) => item.signature == 'balanceOf(address)',
    );
    final encoded = '0x${BigInt.from(42).toRadixString(16).padLeft(64, '0')}';

    expect(function.decodeResult(encoded), ['42']);
  });

  test('builds a manual read function from its canonical signature', () {
    final function = EvmContractAbi.manualFunction(
      signature: 'ownerOf(uint256)',
      outputTypes: 'address',
      isRead: true,
    );

    expect(function.signature, 'ownerOf(uint256)');
    expect(function.isRead, isTrue);
    expect(function.inputs.single.type, 'uint256');
    expect(function.outputs.single.type, 'address');
  });

  test('parses JSON arrays for array ABI arguments', () {
    final abi = EvmContractAbi.parse('''
[
  {
    "type": "function",
    "name": "balanceOfBatch",
    "stateMutability": "view",
    "inputs": [
      {"name": "accounts", "type": "address[]"},
      {"name": "ids", "type": "uint256[]"}
    ],
    "outputs": [{"name": "balances", "type": "uint256[]"}]
  }
]
''');
    final function = abi.functions.single;

    final calldata = function.encodeCall([
      '["0x1111111111111111111111111111111111111111"]',
      '[1]',
    ]);

    expect(calldata, startsWith('0x4e1273f4'));
  });
}
