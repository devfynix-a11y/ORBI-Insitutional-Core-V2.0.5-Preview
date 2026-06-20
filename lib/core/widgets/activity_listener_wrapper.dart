import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../features/auth/state/auth_controller.dart';
import '../security/behavior_telemetry_service.dart';
import '../session/activity_tracker.dart';

/// ActivityListenerWrapper detects any user interaction and resets
/// the session inactivity timer to prevent auto-logout during active use.
///
/// Wrap your app's main content with this widget to enable 1-minute timeout.
class ActivityListenerWrapper extends StatefulWidget {
  final Widget child;

  const ActivityListenerWrapper({required this.child, super.key});

  @override
  State<ActivityListenerWrapper> createState() => _ActivityListenerWrapperState();
}

class _ActivityListenerWrapperState extends State<ActivityListenerWrapper> {
  // Keep this short so inactivity countdown does not continue while typing.
  static const Duration _textEntryHeartbeat = Duration(seconds: 2);
  static const double _swipeMinDx = 72;
  static const double _swipeDirectionBias = 1.25;
  static const Duration _swipeMaxDuration = Duration(milliseconds: 550);
  Timer? _heartbeatTimer;
  final Map<int, Offset> _pointerStartPositions = <int, Offset>{};
  final Map<int, DateTime> _pointerStartTimes = <int, DateTime>{};
  final BehaviorTelemetryService _telemetry =
      BehaviorTelemetryService.instance;

  @override
  void initState() {
    super.initState();
    _heartbeatTimer = Timer.periodic(_textEntryHeartbeat, (_) {
      if (!mounted) return;
      if (_isTypingInEditableField()) {
        _onUserActivity(context);
      }
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _pointerStartPositions[event.pointer] = event.position;
        _pointerStartTimes[event.pointer] = DateTime.now();
        _telemetry.recordPointerDown(event);
        _onUserActivity(context);
      },
      onPointerMove: (event) {
        _telemetry.recordPointerMove(event);
        _onUserActivity(context);
      },
      onPointerUp: (event) {
        _onUserActivity(context);
        _handleSwipeFromPointerEvent(context, event);
        _telemetry.recordPointerUp(event);
        _pointerStartPositions.remove(event.pointer);
        _pointerStartTimes.remove(event.pointer);
      },
      onPointerCancel: (event) {
        _telemetry.recordPointerCancel(event);
        _pointerStartPositions.remove(event.pointer);
        _pointerStartTimes.remove(event.pointer);
      },
      onPointerSignal: (_) => _onUserActivity(context),
      child: widget.child,
    );
  }

  bool _isTypingInEditableField() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final context = focus.context;
    if (context == null) return false;
    return context.widget is EditableText;
  }

  /// Called whenever the user taps or moves on the screen
  void _onUserActivity(BuildContext context) {
    try {
      ActivityTracker.markActivity();
      final auth = context.read<AuthController>();
      auth.registerUserActivity();

      // Reset the inactivity timer if session is active
      if (auth.isAuthenticated) {
        auth.sessionManager.resetInactivityTimer();
      }
    } catch (e) {
      debugPrint('⚠️ Activity listener error: $e');
    }
  }

  void _handleSwipeFromPointerEvent(BuildContext context, PointerUpEvent event) {
    final start = _pointerStartPositions[event.pointer];
    final startedAt = _pointerStartTimes[event.pointer];
    if (start == null || startedAt == null) return;

    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed > _swipeMaxDuration) return;

    final dx = event.position.dx - start.dx;
    final dy = (event.position.dy - start.dy).abs();
    if (dx.abs() < _swipeMinDx) return;
    if (dx.abs() < dy * _swipeDirectionBias) return;

    final auth = context.read<AuthController>();
    final routeName = ModalRoute.of(context)?.settings.name;
    final navigator = Navigator.of(context);
    final swipeRight = dx > 0;

    // Auth flow: left = Signup, right = Login (works on root-login too).
    if (!auth.isAuthenticated) {
      final onSignup = routeName == '/signup';
      if (!swipeRight && !onSignup) {
        navigator.pushReplacementNamed('/signup');
        return;
      }
      if (swipeRight && onSignup) {
        navigator.pushReplacementNamed('/login');
        return;
      }
      return;
    }

    // Non-auth routes: swipe-right behaves like back navigation.
    if (swipeRight && navigator.canPop()) {
      navigator.maybePop();
    }
  }
}
