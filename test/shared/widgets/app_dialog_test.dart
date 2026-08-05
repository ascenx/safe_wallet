import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_colors.dart';
import 'package:safe_wallet/shared/design/app_text_styles.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/widgets/app_dialog.dart';

void main() {
  testWidgets('app dialog uses wallet dialog styling and action callbacks', (
    tester,
  ) async {
    var canceled = false;
    var confirmed = false;

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                AppDialog.show<void>(
                  context: context,
                  title: 'Create wallet',
                  content: const Text('Dialog body'),
                  cancelTitle: 'Back',
                  confirmTitle: 'Create',
                  cancelCallback: () {
                    canceled = true;
                    Navigator.of(context).pop();
                  },
                  confirmCallback: () {
                    confirmed = true;
                    Navigator.of(context).pop();
                  },
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    final title = tester.widget<Text>(find.text('Create wallet'));
    final cancelButton = find.widgetWithText(OutlinedButton, 'Back');
    final confirmButton = find.widgetWithText(FilledButton, 'Create');
    final cancel = tester.widget<OutlinedButton>(cancelButton);

    expect(dialog.backgroundColor, AppColors.background);
    expect(title.style, AppTextStyles.titleMedium);
    expect(title.textAlign, TextAlign.center);
    expect(find.text('Dialog body'), findsOneWidget);
    expect(tester.getSize(cancelButton).height, 40);
    expect(tester.getSize(confirmButton).height, 40);
    expect(
        cancel.style?.side?.resolve(<WidgetState>{})?.color, AppColors.border);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(canceled, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('app dialog hides missing optional actions', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                AppDialog.show<void>(
                  context: context,
                  title: 'Info',
                  content: const Text('Only content'),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Only content'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('app dialog supports keyed danger confirm action', (
    tester,
  ) async {
    var confirmed = false;

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                AppDialog.show<void>(
                  context: context,
                  title: 'Delete',
                  content: const Text('Danger body'),
                  confirmKey: const Key('dangerConfirmButton'),
                  confirmTitle: 'Delete',
                  confirmVariant: AppDialogActionVariant.danger,
                  confirmCallback: () {
                    confirmed = true;
                    Navigator.of(context).pop();
                  },
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final confirmButton = find.byKey(const Key('dangerConfirmButton'));
    final confirm = tester.widget<FilledButton>(
      find.descendant(
        of: confirmButton,
        matching: find.byType(FilledButton),
      ),
    );

    expect(confirm.style?.backgroundColor?.resolve(<WidgetState>{}),
        AppColors.danger);

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('app dialog can keep disabled actions visible', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                AppDialog.show<void>(
                  context: context,
                  title: 'Saving',
                  content: const Text('Saving body'),
                  showCancel: true,
                  showConfirm: true,
                  cancelTitle: 'Back',
                  confirmTitle: 'Save',
                  confirmKey: const Key('savingConfirmButton'),
                  confirmChild: const SizedBox.square(
                    key: Key('savingConfirmChild'),
                    dimension: 18,
                  ),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final cancelButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Back'),
    );
    final confirmButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('savingConfirmButton')),
        matching: find.byType(FilledButton),
      ),
    );

    expect(find.byKey(const Key('savingConfirmChild')), findsOneWidget);
    expect(cancelButton.onPressed, isNull);
    expect(confirmButton.onPressed, isNull);
  });

  testWidgets('app dialog supports custom stateful builders', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                AppDialog.showBuilder<void>(
                  context: context,
                  builder: (_) => const AppDialog(
                    title: 'Custom',
                    content: Text('Custom body'),
                  ),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('Custom body'), findsOneWidget);
  });

  testWidgets('app dialog keeps 32 horizontal screen margins', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                AppDialog.show<void>(
                  context: context,
                  title: 'Wide',
                  content: const Text('Dialog body'),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final dialogFinder = find.ancestor(
      of: find.text('Wide'),
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.type == MaterialType.card,
      ),
    );

    expect(tester.getTopLeft(dialogFinder).dx, 32);
    expect(tester.getTopRight(dialogFinder).dx, 358);
    expect(tester.getSize(dialogFinder).width, 326);
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
