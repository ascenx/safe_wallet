import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/dapp/application/dapp_permission_controller.dart';
import 'package:safe_wallet/features/dapp/data/dapp_permission_repository.dart';

void main() {
  group('DappPermissionController', () {
    test('persistent approval is stored by domain wallet and chain', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(repository);
      final grantedAt = DateTime.utc(2026, 6, 6, 12);

      final permission = await container
          .read(dappPermissionControllerProvider.notifier)
          .approve(
            domain: 'app.uniswap.org',
            walletId: 'wallet-1',
            chainId: '1',
            address: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
            now: grantedAt,
            persistent: true,
          );

      final stored = await repository.permissionFor(
        domain: 'app.uniswap.org',
        walletId: 'wallet-1',
        chainId: '1',
      );

      expect(stored, permission);
      expect(permission.domain, 'https://app.uniswap.org');
      expect(permission.walletId, 'wallet-1');
      expect(permission.chainId, '1');
      expect(permission.grantedAt, grantedAt);
      expect(permission.lastUsedAt, grantedAt);
      expect(permission.expiresAt, grantedAt.add(const Duration(days: 30)));
    });

    test('approval defaults to the current session only', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(repository);
      final controller = container.read(
        dappPermissionControllerProvider.notifier,
      );

      final permission = await controller.approve(
        domain: 'app.uniswap.org',
        walletId: 'wallet-1',
        chainId: '1',
        address: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
      );

      expect(permission.expiresAt, isNull);
      expect(
        await repository.permissionFor(
          domain: 'app.uniswap.org',
          walletId: 'wallet-1',
          chainId: '1',
        ),
        isNull,
      );
      expect(
        await controller.permissionFor(
          domain: 'app.uniswap.org',
          walletId: 'wallet-1',
          chainId: '1',
        ),
        permission,
      );
    });

    test('session-only approval is available without persistence', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(repository);
      final controller = container.read(
        dappPermissionControllerProvider.notifier,
      );

      final permission = await controller.approve(
        domain: 'app.uniswap.org',
        walletId: 'wallet-1',
        chainId: '1',
        address: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
        persistent: false,
      );

      expect(
        await repository.permissionFor(
          domain: 'app.uniswap.org',
          walletId: 'wallet-1',
          chainId: '1',
        ),
        isNull,
      );
      expect(
        await controller.permissionFor(
          domain: 'app.uniswap.org',
          walletId: 'wallet-1',
          chainId: '1',
        ),
        permission,
      );
    });

    test('permissions are isolated by scheme host and port', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(repository);
      final controller = container.read(
        dappPermissionControllerProvider.notifier,
      );

      final permission = await controller.approve(
        domain: 'https://app.example.com:8443/swap',
        walletId: 'wallet-1',
        chainId: '1',
        address: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
      );

      expect(permission.domain, 'https://app.example.com:8443');
      expect(
        await controller.permissionFor(
          domain: 'https://app.example.com:8443/other',
          walletId: 'wallet-1',
          chainId: '1',
        ),
        permission,
      );
      expect(
        await controller.permissionFor(
          domain: 'https://app.example.com',
          walletId: 'wallet-1',
          chainId: '1',
        ),
        isNull,
      );
      expect(
        await controller.permissionFor(
          domain: 'http://app.example.com:8443',
          walletId: 'wallet-1',
          chainId: '1',
        ),
        isNull,
      );
    });

    test('expired persistent approval is rejected and removed', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(repository);
      final controller = container.read(
        dappPermissionControllerProvider.notifier,
      );
      final grantedAt = DateTime.utc(2026, 6, 1);
      await controller.approve(
        domain: 'app.uniswap.org',
        walletId: 'wallet-1',
        chainId: '1',
        address: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
        now: grantedAt,
        persistent: true,
      );

      final permission = await controller.permissionFor(
        domain: 'app.uniswap.org',
        walletId: 'wallet-1',
        chainId: '1',
        now: grantedAt.add(const Duration(days: 31)),
      );

      expect(permission, isNull);
      expect(await repository.listAll(), isEmpty);
    });

    test('rejection returns a rejected decision without persistence', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(repository);

      final decision = await container
          .read(dappPermissionControllerProvider.notifier)
          .reject(
            domain: 'app.uniswap.org',
            walletId: 'wallet-1',
            chainId: '1',
          );

      final stored = await repository.permissionFor(
        domain: 'app.uniswap.org',
        walletId: 'wallet-1',
        chainId: '1',
      );

      expect(decision, DappPermissionDecision.rejected);
      expect(stored, isNull);
    });

    test('clear all removes stored dApp permissions', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(repository);
      final controller = container.read(
        dappPermissionControllerProvider.notifier,
      );

      await controller.approve(
        domain: 'app.uniswap.org',
        walletId: 'wallet-1',
        chainId: '1',
        address: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
        persistent: true,
      );
      await controller.approve(
        domain: 'app.curve.fi',
        walletId: 'wallet-1',
        chainId: '1',
        address: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
        persistent: true,
      );

      await controller.clearAll();

      expect(
        await repository.permissionFor(
          domain: 'app.uniswap.org',
          walletId: 'wallet-1',
          chainId: '1',
        ),
        isNull,
      );
      expect(
        await repository.permissionFor(
          domain: 'app.curve.fi',
          walletId: 'wallet-1',
          chainId: '1',
        ),
        isNull,
      );
      expect(container.read(dappPermissionControllerProvider).value, isEmpty);
    });

    test('revoke removes one stored dApp permission', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(repository);
      final controller = container.read(
        dappPermissionControllerProvider.notifier,
      );

      final uniswap = await controller.approve(
        domain: 'app.uniswap.org',
        walletId: 'wallet-1',
        chainId: '1',
        address: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
        persistent: true,
      );
      await controller.approve(
        domain: 'app.curve.fi',
        walletId: 'wallet-1',
        chainId: '1',
        address: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
        persistent: true,
      );

      await controller.revoke(uniswap.id);

      expect(
        await repository.permissionFor(
          domain: 'app.uniswap.org',
          walletId: 'wallet-1',
          chainId: '1',
        ),
        isNull,
      );
      expect(
        await repository.permissionFor(
          domain: 'app.curve.fi',
          walletId: 'wallet-1',
          chainId: '1',
        ),
        isNotNull,
      );
      expect(
        container
            .read(dappPermissionControllerProvider)
            .value
            ?.map((permission) => permission.domain),
        ['https://app.curve.fi'],
      );
    });
  });
}

ProviderContainer _container(DappPermissionRepository repository) {
  final container = ProviderContainer(
    overrides: [dappPermissionRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}
