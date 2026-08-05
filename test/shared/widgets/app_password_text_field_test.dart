import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/widgets/app_password_text_field.dart';

void main() {
  testWidgets('password visibility button toggles obscuring', (tester) async {
    final controller = TextEditingController(text: 'secret');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        AppPasswordTextField(
          fieldKey: const Key('passwordInput'),
          visibilityButtonKey: const Key('passwordVisibilityButton'),
          controller: controller,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
      ),
    );

    expect(_passwordField(tester).obscureText, isTrue);
    expect(find.byIcon(AppIcons.visible), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(AppIcons.visible)).size, 20);
    expect(find.byTooltip(t.actions.showPassword), findsOneWidget);

    await tester.tap(find.byKey(const Key('passwordVisibilityButton')));
    await tester.pump();

    expect(_passwordField(tester).obscureText, isFalse);
    expect(find.byIcon(AppIcons.hidden), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(AppIcons.hidden)).size, 20);
    expect(find.byTooltip(t.actions.hidePassword), findsOneWidget);
    expect(controller.text, 'secret');
  });

  testWidgets('multiple password fields control visibility independently', (
    tester,
  ) async {
    final firstController = TextEditingController(text: 'first');
    final secondController = TextEditingController(text: 'second');
    addTearDown(firstController.dispose);
    addTearDown(secondController.dispose);

    await tester.pumpWidget(
      _app(
        Column(
          children: [
            AppPasswordTextField(
              fieldKey: const Key('firstPasswordInput'),
              visibilityButtonKey: const Key('firstVisibilityButton'),
              controller: firstController,
              decoration: const InputDecoration(labelText: 'First'),
            ),
            AppPasswordTextField(
              fieldKey: const Key('secondPasswordInput'),
              visibilityButtonKey: const Key('secondVisibilityButton'),
              controller: secondController,
              decoration: const InputDecoration(labelText: 'Second'),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('firstVisibilityButton')));
    await tester.pump();

    expect(
        _passwordField(tester, key: 'firstPasswordInput').obscureText, false);
    expect(
        _passwordField(tester, key: 'secondPasswordInput').obscureText, true);
  });
}

TextField _passwordField(WidgetTester tester, {String key = 'passwordInput'}) {
  return tester.widget<TextField>(find.byKey(Key(key)));
}

Widget _app(Widget child) {
  return TranslationProvider(
    child: MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: child),
    ),
  );
}
