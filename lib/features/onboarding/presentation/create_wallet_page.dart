import 'package:flutter/material.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_buttons.dart';
import 'mnemonic_risk_page.dart';

final class CreateWalletPage extends StatelessWidget {
  const CreateWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.onboarding.createWallet)),
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
              Text(t.onboarding.createBody, style: context.appTextStyles.bodySmall),
              const Spacer(),
              AppButton.primary(
                label: t.actions.kContinue,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MnemonicRiskPage(),
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
