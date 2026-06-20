import 'dart:math';

import 'package:flutter/material.dart';

class BehaviorTelemetryService {
  BehaviorTelemetryService._();

  static final BehaviorTelemetryService instance = BehaviorTelemetryService._();

  final Map<TextEditingController, _TextTelemetry> _trackedControllers = {};
  final Map<int, Offset> _pointerPositions = {};
  final Map<int, DateTime> _pointerTimes = {};

  double? _typingSpeedMsPerKey;
  double? _swipeVelocityPxPerMs;
  double? _touchPressure;

  void trackTextController(TextEditingController controller) {
    if (_trackedControllers.containsKey(controller)) return;
    final telemetry = _TextTelemetry(controller);
    _trackedControllers[controller] = telemetry;
  }

  void untrackTextController(TextEditingController controller) {
    final telemetry = _trackedControllers.remove(controller);
    telemetry?.dispose();
  }

  void recordPointerDown(PointerDownEvent event) {
    _pointerPositions[event.pointer] = event.position;
    _pointerTimes[event.pointer] = DateTime.now();
    _recordPressure(event.pressure, event.pressureMax);
  }

  void recordPointerMove(PointerMoveEvent event) {
    final lastPos = _pointerPositions[event.pointer];
    final lastTime = _pointerTimes[event.pointer];
    if (lastPos == null || lastTime == null) {
      _pointerPositions[event.pointer] = event.position;
      _pointerTimes[event.pointer] = DateTime.now();
      _recordPressure(event.pressure);
      return;
    }

    final now = DateTime.now();
    final deltaMs = max(1, now.difference(lastTime).inMilliseconds);
    final distance = (event.position - lastPos).distance;
    final velocity = distance / deltaMs;
    _swipeVelocityPxPerMs = _smooth(_swipeVelocityPxPerMs, velocity);
    _pointerPositions[event.pointer] = event.position;
    _pointerTimes[event.pointer] = now;
    _recordPressure(event.pressure, event.pressureMax);
  }

  void recordPointerUp(PointerUpEvent event) {
    final lastPos = _pointerPositions[event.pointer];
    final lastTime = _pointerTimes[event.pointer];
    if (lastPos != null && lastTime != null) {
      final now = DateTime.now();
      final deltaMs = max(1, now.difference(lastTime).inMilliseconds);
      final distance = (event.position - lastPos).distance;
      final velocity = distance / deltaMs;
      _swipeVelocityPxPerMs = _smooth(_swipeVelocityPxPerMs, velocity);
    }
    _recordPressure(event.pressure, event.pressureMax);
    _pointerPositions.remove(event.pointer);
    _pointerTimes.remove(event.pointer);
  }

  void recordPointerCancel(PointerCancelEvent event) {
    _pointerPositions.remove(event.pointer);
    _pointerTimes.remove(event.pointer);
  }

  void _recordPressure(double pressure, [double pressureMax = 1.0]) {
    if (pressure <= 0) return;
    final normalized = pressureMax > 0 ? (pressure / pressureMax) : pressure;
    final clamped = normalized.clamp(0.0, 1.0);
    _touchPressure = _smooth(_touchPressure, clamped);
  }

  Map<String, dynamic> snapshot() {
    return {
      'typing_speed': _typingSpeedMsPerKey ?? 0.0,
      'swipe_velocity': _swipeVelocityPxPerMs ?? 0.0,
      'touch_pressure': _touchPressure ?? 0.0,
    };
  }

  double _smooth(double? current, double next) {
    const alpha = 0.2;
    if (current == null) return next;
    return (next * alpha) + (current * (1 - alpha));
  }
}

class _TextTelemetry {
  _TextTelemetry(this.controller) {
    _lastLength = controller.text.length;
    _lastTimestamp = DateTime.now();
    controller.addListener(_onTextChanged);
  }

  final TextEditingController controller;
  int _lastLength = 0;
  DateTime _lastTimestamp = DateTime.now();

  void _onTextChanged() {
    final now = DateTime.now();
    final length = controller.text.length;
    final delta = (length - _lastLength).abs();
    if (delta == 0) return;
    final deltaMs = max(1, now.difference(_lastTimestamp).inMilliseconds);
    final sample = deltaMs / delta;
    BehaviorTelemetryService.instance._typingSpeedMsPerKey =
        BehaviorTelemetryService.instance._smooth(
      BehaviorTelemetryService.instance._typingSpeedMsPerKey,
      sample,
    );
    _lastLength = length;
    _lastTimestamp = now;
  }

  void dispose() {
    controller.removeListener(_onTextChanged);
  }
}
