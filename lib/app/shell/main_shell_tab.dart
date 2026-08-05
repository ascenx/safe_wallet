import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MainShellTab {
  home,
  browser,
  settings,
}

final mainShellTabProvider =
    NotifierProvider<MainShellTabController, MainShellTab>(
  MainShellTabController.new,
);

final class MainShellTabController extends Notifier<MainShellTab> {
  @override
  MainShellTab build() {
    return MainShellTab.home;
  }

  void select(MainShellTab tab) {
    state = tab;
  }
}
