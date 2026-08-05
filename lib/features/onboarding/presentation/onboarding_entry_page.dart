import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_buttons.dart';
import 'create_wallet_page.dart';
import 'import_wallet_page.dart';

final class OnboardingEntryPage extends StatelessWidget {
  const OnboardingEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            28,
            AppSpacing.pageX,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.onboarding.entryTitle, style: context.appTextStyles.titleLarge),
              const SizedBox(height: 10),
              Text(t.onboarding.entrySubtitle, style: context.appTextStyles.bodySmall),
              const Spacer(),
              AppButton.primary(
                label: t.onboarding.createWallet,
                icon: const Icon(AppIcons.addCircle),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CreateWalletPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              AppButton.secondary(
                label: t.onboarding.importWallet,
                icon: const Icon(AppIcons.importWallet),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ImportWalletPage(),
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
