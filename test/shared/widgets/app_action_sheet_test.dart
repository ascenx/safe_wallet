import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/widgets/app_action_sheet.dart';

void main() {
  testWidgets('action sheet renders title, subtitle, actions, and drag handle',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AppActionSheet<String>(
          title: '选择操作',
          subtitle: '请选择下一步',
          actions: const [
            AppActionSheetAction<String>(
              value: 'rename',
              icon: AppIcons.edit,
              title: '重命名',
              subtitle: '修改钱包名称',
            ),
            AppActionSheetAction<String>(
              value: 'delete',
              icon: AppIcons.delete,
              title: '删除',
              variant: AppActionSheetActionVariant.danger,
            ),
          ],
        ),
      ),
    );

    expect(find.text('选择操作'), findsOneWidget);
    expect(find.text('请选择下一步'), findsOneWidget);
    expect(find.text('重命名'), findsOneWidget);
    expect(find.text('修改钱包名称'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.byKey(const Key('appActionSheetDragHandle')), findsOneWidget);

    final dangerTitle = tester.widget<Text>(find.text('删除'));
    expect(dangerTitle.style?.color,
        Theme.of(tester.element(find.text('删除'))).colorScheme.error);

    final handlePadding = tester.widget<Padding>(
      find.byKey(const Key('appActionSheetDragHandle')),
    );
    expect(
      handlePadding.padding,
      const EdgeInsets.symmetric(vertical: 12),
    );
  });

  testWidgets('action sheet pops the selected action value', (tester) async {
    String? selected;

    await tester.pumpWidget(
      _app(
        _ActionSheetLauncher(
          onSelected: (value) {
            selected = value;
          },
        ),
      ),
    );

    await tester.tap(find.text('Open actions'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('导出私钥'));
    await tester.pumpAndSettle();

    expect(selected, 'privateKey');
    expect(find.text('导出私钥'), findsNothing);
  });

  testWidgets('show helper can keep the action sheet open on outside tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _ActionSheetLauncher(
          dismissOnTapOutside: false,
          onSelected: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Open actions'));
    await tester.pumpAndSettle();

    expect(find.text('导出助记词'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('导出助记词'), findsOneWidget);
  });

  testWidgets('drag handle and title stay fixed while actions scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AppActionSheet<int>(
          title: '函数',
          actions: [
            for (var index = 0; index < 20; index += 1)
              AppActionSheetAction<int>(
                value: index,
                title: '函数 $index',
              ),
          ],
        ),
      ),
    );

    final handle = find.byKey(const Key('appActionSheetDragHandle'));
    final title = find.text('函数');
    final actionList = find.byKey(const Key('appActionSheetActionList'));
    final scrollable = find.descendant(
      of: actionList,
      matching: find.byType(Scrollable),
    );
    final handleTopBefore = tester.getTopLeft(handle).dy;
    final titleTopBefore = tester.getTopLeft(title).dy;

    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(handle).dy, handleTopBefore);
    expect(tester.getTopLeft(title).dy, titleTopBefore);
    expect(tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(0));
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

final class _ActionSheetLauncher extends StatelessWidget {
  const _ActionSheetLauncher({
    required this.onSelected,
    this.dismissOnTapOutside = true,
  });

  final ValueChanged<String> onSelected;
  final bool dismissOnTapOutside;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () async {
        final value = await showAppActionSheet<String>(
          context,
          dismissOnTapOutside: dismissOnTapOutside,
          title: '导出',
          actions: const [
            AppActionSheetAction<String>(
              value: 'mnemonic',
              icon: AppIcons.key,
              title: '导出助记词',
            ),
            AppActionSheetAction<String>(
              value: 'privateKey',
              icon: AppIcons.password,
              title: '导出私钥',
            ),
          ],
        );
        if (value != null) {
          onSelected(value);
        }
      },
      child: const Text('Open actions'),
    );
  }
}
