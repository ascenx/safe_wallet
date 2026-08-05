import 'package:flutter_riverpod/flutter_riverpod.dart';

final launchUnlockControllerProvider =
    NotifierProvider<LaunchUnlockController, bool>(
  LaunchUnlockController.new,
);

final class LaunchUnlockController extends Notifier<bool> {
  @override
  bool build() => false;

  void markUnlocked() {
    state = true;
  }

  void reset() {
    state = false;
  }
}
