import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/application/onboarding_controller.dart';
import '../features/onboarding/presentation/onboarding_entry_page.dart';
import '../features/settings/application/launch_lock_setting.dart';
import '../features/wallet/application/wallet_session_controller.dart';
import '../features/wallet/presentation/app_unlock_page.dart';
import '../i18n/generated/translations.g.dart';
import '../shared/design/app_text_styles.dart';
import 'shell/main_shell_page.dart';

final class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingState = ref.watch(onboardingControllerProvider);
    final launchLockSetting = ref.watch(launchLockSettingProvider);
    final walletSession = ref.watch(walletSessionControllerProvider);
    final isWalletUnlocked = walletSession.value?.isUnlocked == true;

    return onboardingState.when(
      data: (state) {
        final account = state.account;
        if (account != null) {
          final requiresLaunchUnlock = launchLockSetting.hasValue
              ? launchLockSetting.value ?? true
              : true;
          if (requiresLaunchUnlock && !isWalletUnlocked) {
            return AppUnlockPage(account: account);
          }
          return const MainShellPage();
        }
        return const OnboardingEntryPage();
      },
      error: (error, stackTrace) => const OnboardingEntryPage(),
      loading: () => const _WalletLoadingPage(),
    );
  }
}

final class _WalletLoadingPage extends StatelessWidget {
  const _WalletLoadingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 14),
              Text(
                t.onboarding.loadingWallet,
                style: context.appTextStyles.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
