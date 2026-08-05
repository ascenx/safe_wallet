import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/staking/application/tron_staking_dashboard_controller.dart';
import 'package:safe_wallet/features/staking/domain/tron_staking_models.dart';
import 'package:safe_wallet/features/staking/data/tron_staking_fee_service.dart';
import 'package:safe_wallet/features/staking/domain/tron_staking_action.dart';
import 'package:safe_wallet/features/staking/application/tron_staking_action_controller.dart';
import 'package:safe_wallet/features/staking/presentation/tron_staking_page.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

void main() {
  testWidgets('renders the complete TRX staking dashboard', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('TRX 质押'), findsOneWidget);
    expect(find.text('20 TRX'), findsOneWidget);
    expect(find.text('Bandwidth 质押'), findsOneWidget);
    expect(find.text('5 TRX'), findsWidgets);
    expect(find.text('Energy 质押'), findsOneWidget);
    expect(find.text('7 TRX'), findsOneWidget);
    expect(find.text('TRON Power'), findsOneWidget);
    expect(find.text('12'), findsWidgets);
    expect(find.text('可用 3800 / 5000 · 已用 1200'), findsOneWidget);
    expect(find.text('可用 6500 / 9000 · 已用 2500'), findsOneWidget);
    expect(find.byKey(const Key('tronStakeButton')), findsOneWidget);
    expect(find.byKey(const Key('tronUnstakeButton')), findsOneWidget);
    expect(find.byKey(const Key('tronDelegateButton')), findsOneWidget);
    expect(find.byKey(const Key('tronVoteButton')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('解押中'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('解押中'), findsOneWidget);
    expect(find.text('解押中总额：2 TRX'), findsOneWidget);
    expect(find.text('当前可提取：1 TRX'), findsOneWidget);
    expect(find.text('最近到期：2026-08-16'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('可领取奖励'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('可领取奖励'), findsOneWidget);
  });

  testWidgets('stake flow validates amount and shows a confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tronStakeButton')));
    await tester.pumpAndSettle();

    expect(find.text('质押 TRX'), findsOneWidget);
    expect(find.text('Bandwidth'), findsWidgets);
    expect(find.text('Energy'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('tronStakingAmountField')),
      '1.5',
    );
    await tester.tap(find.byKey(const Key('tronStakingContinueButton')));
    await tester.pumpAndSettle();

    expect(find.text('确认质押'), findsOneWidget);
    expect(find.text('1.5 TRX'), findsOneWidget);
    expect(find.text('18.5 TRX'), findsOneWidget);
    expect(find.text('Bandwidth'), findsWidgets);
    expect(find.byKey(const Key('confirmTronStakingAction')), findsOneWidget);
  });

  testWidgets('stake flow rejects amounts below the protocol minimum', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tronStakeButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('tronStakingAmountField')),
      '0.5',
    );
    await tester.tap(find.byKey(const Key('tronStakingContinueButton')));
    await tester.pumpAndSettle();

    expect(find.text('质押 TRX'), findsOneWidget);
    expect(find.text('请输入有效的 TRX 数量，最多 6 位小数'), findsOneWidget);
    expect(find.text('确认质押'), findsNothing);
  });

  testWidgets('stake form provides a maximum amount action', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tronStakeButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tronStakingMaxButton')));
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const Key('tronStakingAmountField')),
    );
    expect(field.controller?.text, '20');
  });

  testWidgets('unstake form shows the dynamic availability date and slots', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tronUnstakeButton')));
    await tester.pumpAndSettle();

    expect(find.text('预计 2026-08-16 可提取'), findsOneWidget);
    expect(find.text('剩余可发起解押次数：31'), findsOneWidget);
  });

  testWidgets('stake confirmation reserves balance for a burned fee', (
    tester,
  ) async {
    await tester.pumpWidget(_app(feeSun: BigInt.from(234000)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tronStakeButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tronStakingMaxButton')));
    await tester.tap(find.byKey(const Key('tronStakingContinueButton')));
    await tester.pumpAndSettle();

    expect(find.text('可用 TRX 余额不足'), findsOneWidget);
    expect(find.text('确认质押'), findsNothing);
  });

  testWidgets('delegation flow validates the receiver and confirms resources', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tronDelegateButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('tronDelegateAddressField')),
      'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
    );
    await tester.enterText(
      find.byKey(const Key('tronDelegateAmountField')),
      '2',
    );
    await tester.tap(find.byKey(const Key('tronDelegateContinueButton')));
    await tester.pumpAndSettle();

    expect(find.text('确认资源委托'), findsOneWidget);
    expect(find.text('2 TRX'), findsOneWidget);
    expect(find.text('TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj'), findsOneWidget);
  });

  testWidgets(
    'disables delegation locking when the chain does not support it',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tronDelegateButton')));
      await tester.pumpAndSettle();

      final lockSwitch = tester.widget<SwitchListTile>(
        find.byKey(const Key('tronDelegateLockSwitch')),
      );
      expect(lockSwitch.onChanged, isNull);
      expect(find.text('当前网络不支持锁定委托'), findsOneWidget);
    },
  );

  testWidgets('locked delegation confirmation shows the block lock period', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(dashboardController: _LockableDashboardController.new),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tronDelegateButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('tronDelegateAddressField')),
      'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
    );
    await tester.enterText(
      find.byKey(const Key('tronDelegateAmountField')),
      '2',
    );
    await tester.tap(find.byKey(const Key('tronDelegateLockSwitch')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('tronDelegateLockPeriodField')),
      '1000',
    );
    await tester.tap(find.byKey(const Key('tronDelegateContinueButton')));
    await tester.pumpAndSettle();

    expect(find.text('确认资源委托'), findsOneWidget);
    expect(find.text('锁定周期（区块）'), findsOneWidget);
    expect(find.text('1000 个区块'), findsOneWidget);
  });

  testWidgets('vote flow prevents allocating more than TRON Power', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tronVoteButton')));
    await tester.pumpAndSettle();
    final voteField = find.byKey(
      const Key('tronWitnessVote-TQn9Y2khEsLJW1ChVWFMSMeRDow5KcbLSE'),
    );
    await tester.enterText(voteField, '13');
    await tester.pump();

    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '继续'),
    );
    expect(continueButton.onPressed, isNull);

    await tester.enterText(voteField, '7');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '继续'));
    await tester.pumpAndSettle();

    expect(find.text('确认投票分配'), findsOneWidget);
  });

  testWidgets('locked outgoing delegation shows expiry and cannot undelegate', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(dashboardController: _LockedDashboardController.new),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('已委托给 TXLAQ6...qcdj'),
      300,
      scrollable: find.byType(Scrollable),
    );

    expect(
      find.text('${_localDate(_lockedDelegationExpiresAt)} 到期'),
      findsOneWidget,
    );
    expect(find.text('取消委托'), findsNothing);
  });

  testWidgets('pull to refresh reloads the on-chain dashboard', (tester) async {
    await tester.pumpWidget(
      _app(dashboardController: _RefreshingDashboardController.new),
    );
    await tester.pumpAndSettle();
    expect(find.text('20 TRX'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();

    expect(find.text('21 TRX'), findsOneWidget);
  });

  testWidgets('refresh failure keeps the last successful dashboard visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(dashboardController: _RefreshErrorDashboardController.new),
    );
    await tester.pumpAndSettle();
    expect(find.text('20 TRX'), findsOneWidget);

    await tester.tap(find.byKey(const Key('refreshTronStaking')));
    await tester.pumpAndSettle();

    expect(find.text('20 TRX'), findsOneWidget);
    expect(find.text('质押数据加载失败，请检查 TRON 节点后重试'), findsNothing);
    expect(find.byKey(const Key('retryTronStakingDashboard')), findsNothing);
  });

  group('English localization', () {
    setUp(() async {
      await LocaleSettings.setLocale(AppLocale.en);
    });

    tearDown(() async {
      await LocaleSettings.setLocale(AppLocale.zh);
    });

    testWidgets('renders the staking dashboard in English', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('TRX Staking'), findsOneWidget);
      expect(find.text('Available balance'), findsOneWidget);
      expect(find.text('Delegate resources'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Claimable reward'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Claimable reward'), findsOneWidget);
    });
  });

  testWidgets('zero withdraw and reward states expose no enabled action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(dashboardController: _ZeroActionsDashboardController.new),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('可领取奖励'),
      300,
      scrollable: find.byType(Scrollable),
    );

    expect(find.textContaining('提取 '), findsNothing);
    expect(find.text('取消全部解押'), findsNothing);
    final claimButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '领取奖励'),
    );
    expect(claimButton.onPressed, isNull);
  });

  testWidgets('narrow screen and enlarged text do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, -2400), 1200);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a specific error when no resource can be delegated', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(dashboardController: _NoDelegatableDashboardController.new),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tronDelegateButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('tronDelegateAddressField')),
      'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
    );
    await tester.enterText(
      find.byKey(const Key('tronDelegateAmountField')),
      '2',
    );
    await tester.tap(find.byKey(const Key('tronDelegateContinueButton')));
    await tester.pumpAndSettle();

    expect(find.text('当前没有可委托的质押资源'), findsOneWidget);
    expect(find.text('当前链上状态不允许执行该操作'), findsNothing);
  });

  testWidgets('dashboard error state exposes a retry action', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tronStakingDashboardControllerProvider.overrideWith(
            _ErrorDashboardController.new,
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TronStakingPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('质押数据加载失败，请检查 TRON 节点后重试'), findsOneWidget);
    expect(find.byKey(const Key('retryTronStakingDashboard')), findsOneWidget);
  });

  testWidgets('initial load retry shows progress and can recover dashboard', (
    tester,
  ) async {
    _retryDashboardBuildCalls = 0;
    _retryDashboardCompleter = Completer<TronStakingDashboardState>();
    await tester.pumpWidget(
      _app(dashboardController: _RetryDashboardController.new),
    );
    await tester.pumpAndSettle();
    expect(find.text('质押数据加载失败，请检查 TRON 节点后重试'), findsOneWidget);

    await tester.tap(find.byKey(const Key('retryTronStakingDashboard')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('质押数据加载失败，请检查 TRON 节点后重试'), findsNothing);

    _retryDashboardCompleter.complete(_state);
    await tester.pumpAndSettle();

    expect(find.text('20 TRX'), findsOneWidget);
    expect(find.byKey(const Key('retryTronStakingDashboard')), findsNothing);
  });
}

Widget _app({
  BigInt? feeSun,
  TronStakingDashboardController Function()? dashboardController,
}) {
  return ProviderScope(
    overrides: [
      tronStakingDashboardControllerProvider.overrideWith(
        dashboardController ?? _TestDashboardController.new,
      ),
      tronStakingFeeServiceProvider.overrideWithValue(
        _FakeFeeService(feeSun ?? BigInt.zero),
      ),
      tronStakingActionClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 8, 2),
      ),
    ],
    child: TranslationProvider(
      child: MaterialApp(theme: buildAppTheme(), home: const TronStakingPage()),
    ),
  );
}

final class _FakeFeeService implements TronStakingFeeService {
  _FakeFeeService(this.feeSun);

  final BigInt feeSun;

  @override
  Future<TronStakingFeeEstimate> estimateFee({
    required String apiBaseUrl,
    required String ownerAddress,
    required TronStakingAction action,
    Map<String, String> headers = const {},
  }) async {
    return TronStakingFeeEstimate(
      burnedSun: feeSun,
      bandwidth: 300,
      availableBandwidth: 600,
    );
  }
}

final class _TestDashboardController extends TronStakingDashboardController {
  @override
  Future<TronStakingDashboardState> build() async => _state;

  @override
  Future<BigInt> getMaxDelegatableSun(TronResourceType resource) async =>
      BigInt.from(3000000);
}

final class _ErrorDashboardController extends TronStakingDashboardController {
  @override
  Future<TronStakingDashboardState> build() async {
    throw StateError('offline');
  }
}

late Completer<TronStakingDashboardState> _retryDashboardCompleter;
var _retryDashboardBuildCalls = 0;

final class _RetryDashboardController extends TronStakingDashboardController {
  @override
  Future<TronStakingDashboardState> build() async {
    _retryDashboardBuildCalls += 1;
    if (_retryDashboardBuildCalls == 1) {
      throw StateError('offline');
    }
    return _retryDashboardCompleter.future;
  }
}

final class _LockedDashboardController extends TronStakingDashboardController {
  @override
  Future<TronStakingDashboardState> build() async => _copyState(
    delegations: [
      TronDelegation(
        direction: TronDelegationDirection.outgoing,
        counterpartyAddress: 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
        bandwidthSun: BigInt.from(1000000),
        energySun: BigInt.zero,
        bandwidthExpiresAt: _lockedDelegationExpiresAt,
      ),
    ],
  );
}

final _lockedDelegationExpiresAt = DateTime.utc(2030, 8, 16, 20);

String _localDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

final class _LockableDashboardController
    extends TronStakingDashboardController {
  @override
  Future<TronStakingDashboardState> build() async =>
      _copyState(overview: _copyOverview(maxDelegateLockPeriod: 864000));

  @override
  Future<BigInt> getMaxDelegatableSun(TronResourceType resource) async =>
      BigInt.from(3000000);
}

final class _RefreshingDashboardController
    extends TronStakingDashboardController {
  @override
  Future<TronStakingDashboardState> build() async => _state;

  @override
  Future<void> refresh() async {
    state = AsyncData(
      _copyState(
        overview: _copyOverview(availableBalanceSun: BigInt.from(21000000)),
      ),
    );
  }
}

final class _RefreshErrorDashboardController
    extends TronStakingDashboardController {
  @override
  Future<TronStakingDashboardState> build() async => _state;

  @override
  Future<void> refresh() async {
    state = AsyncError<TronStakingDashboardState>(
      StateError('offline'),
      StackTrace.current,
    );
  }
}

final class _ZeroActionsDashboardController
    extends TronStakingDashboardController {
  @override
  Future<TronStakingDashboardState> build() async => _copyState(
    overview: _copyOverview(
      pendingUnfreezes: const [],
      withdrawableSun: BigInt.zero,
      rewardSun: BigInt.zero,
    ),
  );
}

final class _NoDelegatableDashboardController
    extends TronStakingDashboardController {
  @override
  Future<TronStakingDashboardState> build() async => _state;

  @override
  Future<BigInt> getMaxDelegatableSun(TronResourceType resource) async =>
      BigInt.zero;
}

TronStakingDashboardState _copyState({
  TronStakingOverview? overview,
  List<TronDelegation>? delegations,
}) {
  return TronStakingDashboardState(
    wallets: _state.wallets,
    networks: _state.networks,
    selectedWalletId: _state.selectedWalletId,
    selectedNetworkId: _state.selectedNetworkId,
    rpcNode: _state.rpcNode,
    overview: overview ?? _state.overview,
    delegations: delegations ?? _state.delegations,
    witnesses: _state.witnesses,
  );
}

TronStakingOverview _copyOverview({
  BigInt? availableBalanceSun,
  List<TronPendingUnfreeze>? pendingUnfreezes,
  BigInt? withdrawableSun,
  BigInt? rewardSun,
  int? maxDelegateLockPeriod,
}) {
  final overview = _state.overview!;
  return TronStakingOverview(
    availableBalanceSun: availableBalanceSun ?? overview.availableBalanceSun,
    bandwidthStakedSun: overview.bandwidthStakedSun,
    energyStakedSun: overview.energyStakedSun,
    bandwidthLimit: overview.bandwidthLimit,
    bandwidthUsed: overview.bandwidthUsed,
    energyLimit: overview.energyLimit,
    energyUsed: overview.energyUsed,
    tronPower: overview.tronPower,
    votes: overview.votes,
    pendingUnfreezes: pendingUnfreezes ?? overview.pendingUnfreezes,
    availableUnfreezeCount: overview.availableUnfreezeCount,
    withdrawableSun: withdrawableSun ?? overview.withdrawableSun,
    rewardSun: rewardSun ?? overview.rewardSun,
    unfreezeDelayDays: overview.unfreezeDelayDays,
    cancelAllUnfreezeSupported: overview.cancelAllUnfreezeSupported,
    delegateResourceSupported: overview.delegateResourceSupported,
    maxDelegateLockPeriod:
        maxDelegateLockPeriod ?? overview.maxDelegateLockPeriod,
  );
}

final _state = TronStakingDashboardState(
  wallets: [_wallet],
  networks: [defaultChains.firstWhere((chain) => chain.id == 'tron-mainnet')],
  selectedWalletId: _wallet.id,
  selectedNetworkId: 'tron-mainnet',
  rpcNode: _node,
  overview: TronStakingOverview(
    availableBalanceSun: BigInt.from(20000000),
    bandwidthStakedSun: BigInt.from(5000000),
    energyStakedSun: BigInt.from(7000000),
    bandwidthLimit: 5000,
    bandwidthUsed: 1200,
    energyLimit: 9000,
    energyUsed: 2500,
    tronPower: 12,
    votes: const [],
    pendingUnfreezes: [
      TronPendingUnfreeze(
        resource: TronResourceType.bandwidth,
        amountSun: BigInt.from(2000000),
        expiresAt: DateTime.utc(2026, 8, 16),
      ),
    ],
    availableUnfreezeCount: 31,
    withdrawableSun: BigInt.from(1000000),
    rewardSun: BigInt.from(500000),
    unfreezeDelayDays: 14,
    cancelAllUnfreezeSupported: true,
    delegateResourceSupported: true,
  ),
  delegations: [
    TronDelegation(
      direction: TronDelegationDirection.outgoing,
      counterpartyAddress: 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
      bandwidthSun: BigInt.from(1000000),
      energySun: BigInt.zero,
    ),
  ],
  witnesses: const [
    TronWitness(
      address: 'TQn9Y2khEsLJW1ChVWFMSMeRDow5KcbLSE',
      voteCount: 100,
      url: 'https://sr.example',
      isActive: true,
    ),
  ],
);

final _wallet = WalletAccount(
  id: 'wallet-tron',
  name: 'Tron Wallet',
  evmAddress: '',
  solanaAddress: '',
  tronAddress: 'TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH',
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 1),
);

const _node = RpcNode(
  id: 'tron-node',
  chainId: 'tron-mainnet',
  name: 'TronGrid',
  url: 'https://api.trongrid.io',
  nodeType: RpcNodeType.defaultNode,
  isSelected: true,
  lastTestStatus: RpcNodeTestStatus.available,
);
