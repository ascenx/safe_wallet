import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_colors.dart';
import 'package:safe_wallet/shared/design/app_radius.dart';
import 'package:safe_wallet/shared/design/app_spacing.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/errors/wallet_error.dart';
import 'package:safe_wallet/shared/widgets/app_buttons.dart';
import 'package:safe_wallet/shared/widgets/app_error_state.dart';
import 'package:safe_wallet/shared/widgets/app_section_card.dart';
import 'package:safe_wallet/shared/widgets/risk_notice.dart';

void main() {
  testWidgets('risk levels use expected colors', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            RiskNotice(level: RiskLevel.info, message: 'Info'),
            RiskNotice(level: RiskLevel.warning, message: 'Warning'),
            RiskNotice(level: RiskLevel.danger, message: 'Danger'),
          ],
        ),
      ),
    );

    expect(_boxColor(tester, find.text('Info')), AppColors.primarySoft);
    expect(_boxColor(tester, find.text('Warning')), AppColors.warningSoft);
    expect(_boxColor(tester, find.text('Danger')), AppColors.dangerSoft);
  });

  testWidgets('danger button is visually distinct from primary',
      (tester) async {
    await tester.pumpWidget(
      _app(
        Row(
          children: [
            AppButton.primary(label: 'Primary', onPressed: () {}),
            AppButton.danger(label: 'Danger', onPressed: () {}),
          ],
        ),
      ),
    );

    final primary = tester.widget<FilledButton>(find.widgetWithText(
      FilledButton,
      'Primary',
    ));
    final danger = tester.widget<FilledButton>(find.widgetWithText(
      FilledButton,
      'Danger',
    ));

    expect(
        primary.style?.backgroundColor, isNot(danger.style?.backgroundColor));
  });

  testWidgets('app button defaults to 52 height and allows override',
      (tester) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            AppButton.primary(label: 'Default', onPressed: () {}),
            AppButton.secondary(
              label: 'Compact',
              height: 40,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.widgetWithText(FilledButton, 'Default')).height,
        52);
    expect(
        tester.getSize(find.widgetWithText(OutlinedButton, 'Compact')).height,
        40);
  });

  testWidgets('text app button uses neutral border and primary text color',
      (tester) async {
    await tester.pumpWidget(
      _app(
        AppButton.text(label: 'Text Action', onPressed: () {}),
      ),
    );

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Text Action'),
    );

    expect(
        button.style?.side?.resolve(<WidgetState>{})?.color, AppColors.border);
    expect(button.style?.foregroundColor?.resolve(<WidgetState>{}),
        AppColors.textPrimary);
  });

  testWidgets('app button can render a custom child', (tester) async {
    await tester.pumpWidget(
      _app(
        AppButton.primary(
          label: 'Loading',
          onPressed: () {},
          child: const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading'), findsNothing);
  });

  testWidgets('app button can render a leading icon', (tester) async {
    await tester.pumpWidget(
      _app(
        AppButton.primary(
          label: 'Create',
          icon: const Icon(AppIcons.add),
          onPressed: () {},
        ),
      ),
    );

    expect(find.byIcon(AppIcons.add), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create'), findsOneWidget);
  });

  testWidgets('app button labels are limited to one line', (tester) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            AppButton.primary(label: 'Primary', onPressed: () {}),
            AppButton.secondary(label: 'Secondary', onPressed: () {}),
            AppButton.danger(
              label: 'Danger',
              icon: const Icon(AppIcons.delete),
              onPressed: () {},
            ),
            AppButton.text(
              label: 'Text',
              icon: const Icon(AppIcons.edit),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    final labels = tester.widgetList<Text>(
      find.descendant(
        of: find.byType(AppButton),
        matching: find.byType(Text),
      ),
    );

    expect(labels, hasLength(4));
    expect(labels.every((label) => label.maxLines == 1), isTrue);
  });

  testWidgets('error state shows localized safe message', (tester) async {
    await tester.pumpWidget(
      _app(const AppErrorState(error: WalletError.walletLocked())),
    );

    expect(find.text('钱包已锁定，请先解锁'), findsOneWidget);
  });

  testWidgets('error state can show localized message directly',
      (tester) async {
    await tester.pumpWidget(
      _app(const AppErrorState(message: '网络列表读取失败')),
    );

    expect(find.text('网络列表读取失败'), findsOneWidget);
  });

  testWidgets('section card preserves caller card styling', (tester) async {
    await tester.pumpWidget(
      _app(
        const AppSectionCard(
          padding: EdgeInsets.all(AppSpacing.cardPaddingLarge),
          borderRadius: AppRadius.xLargeBorder,
          borderColor: AppColors.primary,
          child: Text('Section'),
        ),
      ),
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find.ancestor(
        of: find.text('Section'),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;
    final padding = tester.widget<Padding>(
      find
          .ancestor(
            of: find.text('Section'),
            matching: find.byType(Padding),
          )
          .first,
    );

    expect(decoration.borderRadius, AppRadius.xLargeBorder);
    expect(decoration.border?.top.color, AppColors.primary);
    expect(padding.padding, const EdgeInsets.all(AppSpacing.cardPaddingLarge));
  });
}

Widget _app(Widget child) {
  return TranslationProvider(
    child: MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: child),
    ),
  );
}

Color? _boxColor(WidgetTester tester, Finder textFinder) {
  final decoratedBox = find.ancestor(
    of: textFinder,
    matching: find.byType(DecoratedBox),
  );
  final widget = tester.widget<DecoratedBox>(decoratedBox.first);
  final decoration = widget.decoration as BoxDecoration;
  return decoration.color;
}
