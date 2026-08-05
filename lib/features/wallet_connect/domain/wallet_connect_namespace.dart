import 'wallet_connect_caip.dart';

final class WalletConnectNamespaceProposal {
  const WalletConnectNamespaceProposal({
    required this.chains,
    required this.methods,
    required this.events,
  });

  final Set<Caip2ChainId> chains;
  final Set<String> methods;
  final Set<String> events;
}

final class WalletConnectNamespaceCapability {
  const WalletConnectNamespaceCapability({
    required this.chains,
    required this.methods,
    required this.events,
    required this.accounts,
  });

  final Set<Caip2ChainId> chains;
  final Set<String> methods;
  final Set<String> events;
  final Set<Caip10AccountId> accounts;
}

final class WalletConnectApprovedNamespace {
  const WalletConnectApprovedNamespace({
    required this.chains,
    required this.methods,
    required this.events,
    required this.accounts,
  });

  final Set<Caip2ChainId> chains;
  final Set<String> methods;
  final Set<String> events;
  final Set<Caip10AccountId> accounts;
}

enum WalletConnectNamespaceIssueKind {
  unsupportedNamespace,
  unsupportedChain,
  unsupportedMethod,
  unsupportedEvent,
}

final class WalletConnectNamespaceIssue {
  const WalletConnectNamespaceIssue({
    required this.kind,
    required this.namespace,
    required this.value,
  });

  final WalletConnectNamespaceIssueKind kind;
  final String namespace;
  final String value;
}

final class WalletConnectNamespaceValidation {
  const WalletConnectNamespaceValidation({
    required this.approved,
    required this.issues,
  });

  final Map<String, WalletConnectApprovedNamespace> approved;
  final List<WalletConnectNamespaceIssue> issues;

  bool get canApprove => issues.isEmpty;
}

final class WalletConnectCapabilities {
  const WalletConnectCapabilities({required this.namespaces});

  final Map<String, WalletConnectNamespaceCapability> namespaces;

  WalletConnectNamespaceValidation validate({
    required Map<String, WalletConnectNamespaceProposal> required,
    required Map<String, WalletConnectNamespaceProposal> optional,
  }) {
    final approved = <String, WalletConnectApprovedNamespace>{};
    final issues = <WalletConnectNamespaceIssue>[];

    for (final entry in required.entries) {
      final capability = namespaces[entry.key];
      if (capability == null) {
        issues.add(
          WalletConnectNamespaceIssue(
            kind: WalletConnectNamespaceIssueKind.unsupportedNamespace,
            namespace: entry.key,
            value: entry.key,
          ),
        );
        continue;
      }
      _collectRequiredIssues(
        namespace: entry.key,
        proposal: entry.value,
        capability: capability,
        issues: issues,
      );
      approved[entry.key] = _approvedIntersection(entry.value, capability);
    }

    for (final entry in optional.entries) {
      final capability = namespaces[entry.key];
      if (capability == null) {
        continue;
      }
      final intersection = _approvedIntersection(entry.value, capability);
      if (intersection.chains.isNotEmpty && intersection.methods.isNotEmpty) {
        approved[entry.key] = intersection;
      }
    }

    return WalletConnectNamespaceValidation(
      approved: Map.unmodifiable(approved),
      issues: List.unmodifiable(issues),
    );
  }

  static void _collectRequiredIssues({
    required String namespace,
    required WalletConnectNamespaceProposal proposal,
    required WalletConnectNamespaceCapability capability,
    required List<WalletConnectNamespaceIssue> issues,
  }) {
    if (proposal.chains.isEmpty) {
      issues.add(
        WalletConnectNamespaceIssue(
          kind: WalletConnectNamespaceIssueKind.unsupportedChain,
          namespace: namespace,
          value: namespace,
        ),
      );
    }
    for (final chain in proposal.chains.difference(capability.chains)) {
      issues.add(
        WalletConnectNamespaceIssue(
          kind: WalletConnectNamespaceIssueKind.unsupportedChain,
          namespace: namespace,
          value: chain.toString(),
        ),
      );
    }
    for (final method in proposal.methods.difference(capability.methods)) {
      issues.add(
        WalletConnectNamespaceIssue(
          kind: WalletConnectNamespaceIssueKind.unsupportedMethod,
          namespace: namespace,
          value: method,
        ),
      );
    }
    for (final event in proposal.events.difference(capability.events)) {
      issues.add(
        WalletConnectNamespaceIssue(
          kind: WalletConnectNamespaceIssueKind.unsupportedEvent,
          namespace: namespace,
          value: event,
        ),
      );
    }
  }

  static WalletConnectApprovedNamespace _approvedIntersection(
    WalletConnectNamespaceProposal proposal,
    WalletConnectNamespaceCapability capability,
  ) {
    final chains = proposal.chains.intersection(capability.chains);
    return WalletConnectApprovedNamespace(
      chains: Set.unmodifiable(chains),
      methods: Set.unmodifiable(
        proposal.methods.intersection(capability.methods),
      ),
      events: Set.unmodifiable(proposal.events.intersection(capability.events)),
      accounts: Set.unmodifiable(
        capability.accounts.where((account) => chains.contains(account.chain)),
      ),
    );
  }
}
