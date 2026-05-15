import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeDetector {
  static const double _shakeThreshold = 12.0;
  static const int _shakesRequired = 2;
  static const Duration _shakeWindow = Duration(milliseconds: 700);

  int _shakeCount = 0;
  DateTime? _firstShakeTime;
  StreamSubscription<UserAccelerometerEvent>? _subscription;

  void start(VoidCallback onShake) {
    _subscription =
        userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      final magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      if (magnitude > _shakeThreshold) {
        final now = DateTime.now();

        if (_firstShakeTime == null) {
          _firstShakeTime = now;
          _shakeCount = 1;
        } else if (now.difference(_firstShakeTime!) <= _shakeWindow) {
          _shakeCount++;
          if (_shakeCount >= _shakesRequired) {
            _shakeCount = 0;
            _firstShakeTime = null;
            onShake();
          }
        } else {
          // Window expired — restart count from this shake.
          _firstShakeTime = now;
          _shakeCount = 1;
        }
      }
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _shakeCount = 0;
    _firstShakeTime = null;
  }
}
