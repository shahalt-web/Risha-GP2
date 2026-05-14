import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceSleepLockService {
  static const MethodChannel _channel = MethodChannel(
    'risha_v01/device_sleep_lock',
  );

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> syncSleepLockConfig({
    required String childId,
    String? childName,
    required bool configured,
    required bool enabled,
    required int sleepHour,
    required int sleepMinute,
  }) async {
    if (!_isSupported) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('syncSleepLockConfig', {
        'childId': childId.trim(),
        'childName': childName?.trim(),
        'configured': configured,
        'enabled': enabled,
        'sleepHour': sleepHour,
        'sleepMinute': sleepMinute,
      });
    } catch (_) {
      // Ignore native sync failures to avoid blocking Flutter flow.
    }
  }

  Future<void> clearSleepLockConfig() async {
    if (!_isSupported) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('clearSleepLockConfig');
    } catch (_) {
      // Ignore native cleanup failures.
    }
  }

  Future<bool> isOverlayPermissionGranted() async {
    if (!_isSupported) {
      return true;
    }

    try {
      return await _channel.invokeMethod<bool>('isOverlayPermissionGranted') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openOverlayPermissionSettings() async {
    if (!_isSupported) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('openOverlayPermissionSettings');
    } catch (_) {
      // Ignore settings launch failures.
    }
  }

  Future<void> refreshSleepLock() async {
    if (!_isSupported) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('refreshSleepLock');
    } catch (_) {
      // Ignore refresh failures.
    }
  }
}
