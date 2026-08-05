import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../application/onboarding_controller.dart';
import 'set_password_page.dart';

final class MnemonicRiskPage extends ConsumerWidget {
  const MnemonicRiskPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(t.onboarding.riskTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            16,
            AppSpacing.pageX,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.onboarding.riskLoss, style: context.appTextStyles.titleLarge),
              const SizedBox(height: 12),
              Text(
                t.onboarding.riskResponsibility,
                style: context.appTextStyles.bodyMedium.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t.onboarding.riskNoBackupGate,
                style: context.appTextStyles.bodySmall,
              ),
              const Spacer(),
              AppButton.primary(
                label: t.onboarding.riskAccepted,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SetPasswordPage(
                        progressLabel: t.onboarding.creatingWallet,
                        onSubmit: (password) {
                          return ref
                              .read(onboardingControllerProvider.notifier)
                              .createWallet(password: password);
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
