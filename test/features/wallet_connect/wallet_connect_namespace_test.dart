import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_caip.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_namespace.dart';

void main() {
  const evmAccount = Caip10AccountId(
    chain: Caip2ChainId(namespace: 'eip155', reference: '56'),
    address: '0x9659B6Ed9FAFfa7f3f04E3B0aD5EeE214162acfc',
  );
  final capabilities = WalletConnectCapabilities(
    namespaces: {
      'eip155': WalletConnectNamespaceCapability(
        chains: {
          const Caip2ChainId(namespace: 'eip155', reference: '1'),
          const Caip2ChainId(namespace: 'eip155', reference: '56'),
        },
        methods: {
          'personal_sign',
          'eth_signTypedData_v4',
          'eth_sendTransaction',
        },
        events: {'accountsChanged', 'chainChanged'},
        accounts: {evmAccount},
      ),
    },
  );

  test('approves required namespace only when every item is supported', () {
    final proposal = WalletConnectNamespaceProposal(
      chains: {const Caip2ChainId(namespace: 'eip155', reference: '56')},
      methods: const {'personal_sign', 'eth_sendTransaction'},
      events: const {'accountsChanged'},
    );

    final result = capabilities.validate(
      required: {'eip155': proposal},
      optional: const {},
    );

    expect(result.canApprove, isTrue);
    expect(result.approved['eip155']!.chains, proposal.chains);
    expect(result.approved['eip155']!.accounts, {evmAccount});
  });

  test('rejects unsupported required chain, method, event, and namespace', () {
    final result = capabilities.validate(
      required: {
        'eip155': WalletConnectNamespaceProposal(
          chains: {const Caip2ChainId(namespace: 'eip155', reference: '137')},
          methods: const {'eth_sign'},
          events: const {'message'},
        ),
        'tron': WalletConnectNamespaceProposal(
          chains: {const Caip2ChainId(namespace: 'tron', reference: 'mainnet')},
          methods: const {'tron_signTransaction'},
          events: const {},
        ),
      },
      optional: const {},
    );

    expect(result.canApprove, isFalse);
    expect(
      result.issues.map((issue) => issue.kind),
      containsAll({
        WalletConnectNamespaceIssueKind.unsupportedChain,
        WalletConnectNamespaceIssueKind.unsupportedMethod,
        WalletConnectNamespaceIssueKind.unsupportedEvent,
        WalletConnectNamespaceIssueKind.unsupportedNamespace,
      }),
    );
  });

  test('approves only the supported intersection of optional namespaces', () {
    final result = capabilities.validate(
      required: const {},
      optional: {
        'eip155': WalletConnectNamespaceProposal(
          chains: {
            const Caip2ChainId(namespace: 'eip155', reference: '1'),
            const Caip2ChainId(namespace: 'eip155', reference: '137'),
          },
          methods: const {'personal_sign', 'eth_sign'},
          events: const {'accountsChanged', 'message'},
        ),
        'sui': WalletConnectNamespaceProposal(
          chains: {const Caip2ChainId(namespace: 'sui', reference: 'mainnet')},
          methods: const {'sui_signTransaction'},
          events: const {},
        ),
      },
    );

    expect(result.canApprove, isTrue);
    expect(result.approved.keys, ['eip155']);
    expect(result.approved['eip155']!.chains, {
      const Caip2ChainId(namespace: 'eip155', reference: '1'),
    });
    expect(result.approved['eip155']!.methods, {'personal_sign'});
    expect(result.approved['eip155']!.events, {'accountsChanged'});
  });

  test('filters accounts to approved chains', () {
    final result = capabilities.validate(
      required: {
        'eip155': WalletConnectNamespaceProposal(
          chains: {const Caip2ChainId(namespace: 'eip155', reference: '1')},
          methods: const {'personal_sign'},
          events: const {},
        ),
      },
      optional: const {},
    );

    expect(result.canApprove, isTrue);
    expect(result.approved['eip155']!.accounts, isEmpty);
  });

  test('rejects a required namespace that does not identify any chain', () {
    final result = capabilities.validate(
      required: {
        'eip155': WalletConnectNamespaceProposal(
          chains: const {},
          methods: const {'personal_sign'},
          events: const {},
        ),
      },
      optional: const {},
    );

    expect(result.canApprove, isFalse);
    expect(
      result.issues.single.kind,
      WalletConnectNamespaceIssueKind.unsupportedChain,
    );
  });
}
