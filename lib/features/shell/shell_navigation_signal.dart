import 'package:flutter/foundation.dart';

class ShellNavigationSignal {
  const ShellNavigationSignal._();

  static final ValueNotifier<int?> selectedTab = ValueNotifier<int?>(null);

  static void goHome() {
    selectedTab.value = 0;
  }
}
