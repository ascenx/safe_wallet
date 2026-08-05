import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/widgets/app_bottom_sheet.dart';

void main() {
  testWidgets('bottom sheet renders optional text and action buttons', (
    tester,
  ) async {
    var confirmed = false;
    var canceled = false;

    await tester.pumpWidget(
      _app(
        AppBottomSheet(
          title: '授权请求',
          subtitle: '请确认当前操作',
          confirmTitle: '继续',
          cancelTitle: '返回',
          onConfirm: () {
            confirmed = true;
          },
          onCancel: () {
            canceled = true;
          },
          body: const Text('Sheet body'),
        ),
      ),
    );

    expect(find.text('授权请求'), findsOneWidget);
    expect(find.text('请确认当前操作'), findsOneWidget);
    expect(find.text('Sheet body'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '继续'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '返回'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '继续'));
    await tester.tap(find.widgetWithText(OutlinedButton, '返回'));

    expect(confirmed, isTrue);
    expect(canceled, isTrue);
  });

  testWidgets('bottom sheet hides optional sections when not provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AppBottomSheet(
          body: Text('Only body'),
        ),
      ),
    );

    expect(find.text('Only body'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('bottom sheet uses 12px vertical drag handle spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AppBottomSheet(
          body: Text('Compact body'),
        ),
      ),
    );

    final handlePadding = tester.widget<Padding>(
      find.byKey(const Key('appBottomSheetDragHandle')),
    );

    expect(
      handlePadding.padding,
      const EdgeInsets.symmetric(vertical: 12),
    );
  });

  testWidgets('show helper dismisses on outside tap by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _SheetLauncher(
          dismissOnTapOutside: true,
          buttonLabel: 'Open dismissible',
        ),
      ),
    );

    await tester.tap(find.text('Open dismissible'));
    await tester.pumpAndSettle();

    expect(find.text('Modal body'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Modal body'), findsNothing);
  });

  testWidgets('show helper can keep the sheet open on outside tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _SheetLauncher(
          dismissOnTapOutside: false,
          buttonLabel: 'Open locked',
        ),
      ),
    );

    await tester.tap(find.text('Open locked'));
    await tester.pumpAndSettle();

    expect(find.text('Modal body'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Modal body'), findsOneWidget);
  });
}

Widget _app(Widget child) {
  return TranslationProvider(
    child: MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

final class _SheetLauncher extends StatelessWidget {
  const _SheetLauncher({
    required this.dismissOnTapOutside,
    required this.buttonLabel,
  });

  final bool dismissOnTapOutside;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {
        showAppBottomSheet<void>(
          context,
          dismissOnTapOutside: dismissOnTapOutside,
          body: const Text('Modal body'),
        );
      },
      child: Text(buttonLabel),
    );
  }
}
