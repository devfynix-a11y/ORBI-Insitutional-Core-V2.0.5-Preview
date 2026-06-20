import 'package:flutter/foundation.dart';

/// Global app activity signal used by UI layers that need to react to
/// user interactions across all routes.
class ActivityTracker {
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static void markActivity() {
    tick.value = tick.value + 1;
  }
}
