import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/wallet_connect/application/wallet_connect_controller.dart';
import 'package:safe_wallet/features/wallet_connect/data/wallet_connect_gateway.dart';

void main() {
  test(
    'pairing URI and Project ID are not emitted when transport fails',
    () async {
      const pairingUri = 'wc:topic@2?symKey=super-secret-pairing-key';
      const projectId = 'private-project-id-for-test';
      final container = ProviderContainer(
        overrides: [
          walletConnectGatewayProvider.overrideWithValue(_FailingGateway()),
          walletConnectProjectIdProvider.overrideWithValue(projectId),
        ],
      );
      addTearDown(container.dispose);

      final logs = await _captureLogs(() async {
        final controller = container.read(
          walletConnectControllerProvider.notifier,
        );
        await controller.initialize();
        await controller.pair(pairingUri);
      });

      expect(logs, isNot(contains(pairingUri)));
      expect(logs, isNot(contains('super-secret-pairing-key')));
      expect(logs, isNot(contains(projectId)));
    },
  );
}

final class _FailingGateway extends UnsupportedWalletConnectGateway {
  @override
  Future<void> initialize(WalletConnectConfiguration configuration) async {}

  @override
  Future<void> pair(Uri uri) {
    throw StateError(uri.toString());
  }
}

Future<String> _captureLogs(Future<void> Function() action) async {
  final buffer = StringBuffer();
  final previousDebugPrint = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null) {
      buffer.writeln(message);
    }
  };
  try {
    await runZoned(
      action,
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => buffer.writeln(line),
      ),
    );
  } finally {
    debugPrint = previousDebugPrint;
  }
  return buffer.toString();
}
