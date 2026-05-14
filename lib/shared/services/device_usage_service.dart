import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceUsageService {
  static const MethodChannel _channel = MethodChannel('risha_v01/device_usage');

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> isUsageAccessGranted() async {
    if (!_isSupported) {
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>('isUsageAccessGranted') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openUsageAccessSettings() async {
    if (!_isSupported) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('openUsageAccessSettings');
    } catch (_) {
      // Ignore settings launch failures.
    }
  }

  Future<int?> getTodayUsageMillis() async {
    if (!_isSupported) {
      return null;
    }

    try {
      return await _channel.invokeMethod<int>('getTodayUsageMillis');
    } catch (_) {
      return null;
    }
  }

  Future<int?> getActiveUsageMillisSince(DateTime startAt) async {
    if (!_isSupported) {
      return null;
    }

    try {
      return await _channel.invokeMethod<int>('getActiveUsageMillisSince', {
        'startEpochMs': startAt.millisecondsSinceEpoch,
      });
    } catch (_) {
      return null;
    }
  }

  Future<bool> startUsageRest({
    required DateTime endsAt,
    String? childName,
  }) async {
    if (!_isSupported) {
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>('startUsageRest', {
            'endsAtEpochMs': endsAt.millisecondsSinceEpoch,
            'childName': childName,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<DeviceUsageRestState?> getUsageRestState() async {
    if (!_isSupported) {
      return null;
    }

    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getUsageRestState',
      );
      if (raw == null) {
        return null;
      }
      return DeviceUsageRestState.fromMap(raw);
    } catch (_) {
      return null;
    }
  }

  Future<bool> stopUsageRestIfExpired() async {
    if (!_isSupported) {
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>('stopUsageRestIfExpired') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> configureUsageRestMonitor({
    required bool enabled,
    required DateTime cycleStartedAt,
    required String cycleDate,
    required int cycleCount,
    required Duration threshold,
    required Duration restDuration,
    required int maxCyclesPerDay,
    String? childName,
  }) async {
    if (!_isSupported) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('configureUsageRestMonitor', {
        'enabled': enabled,
        'cycleStartedAtEpochMs': cycleStartedAt.millisecondsSinceEpoch,
        'cycleDate': cycleDate,
        'cycleCount': cycleCount,
        'thresholdMillis': threshold.inMilliseconds,
        'restDurationMillis': restDuration.inMilliseconds,
        'maxCyclesPerDay': maxCyclesPerDay,
        'childName': childName,
      });
    } catch (_) {
      // Native monitor is best-effort; Flutter foreground checks still run.
    }
  }

  Future<void> triggerUsageRestPrompt() async {
    if (!_isSupported) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('triggerUsageRestPrompt');
    } catch (_) {
      // Best-effort; background monitor will eventually trigger it anyway.
    }
  }

  Future<Map<String, dynamic>?> getUsageRestMonitorConfig() async {
    if (!_isSupported) {
      return null;
    }

    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getUsageRestMonitorConfig',
      );
      if (raw == null) {
        return null;
      }
      return raw.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return null;
    }
  }

  Future<DeviceUsageDebugSnapshot> getDebugSnapshot({
    DateTime? cycleStartedAt,
  }) async {
    final startAt = cycleStartedAt ?? DateTime.now();
    final hasUsageAccess = await isUsageAccessGranted();
    final usageMillis = hasUsageAccess
        ? await getActiveUsageMillisSince(startAt)
        : null;
    final restState = await getUsageRestState();
    return DeviceUsageDebugSnapshot(
      isSupported: _isSupported,
      hasUsageAccess: hasUsageAccess,
      cycleStartedAt: startAt,
      activeUsage: usageMillis == null
          ? null
          : Duration(milliseconds: usageMillis),
      restState: restState,
    );
  }
}

class DeviceUsageDebugSnapshot {
  const DeviceUsageDebugSnapshot({
    required this.isSupported,
    required this.hasUsageAccess,
    required this.cycleStartedAt,
    required this.activeUsage,
    required this.restState,
  });

  final bool isSupported;
  final bool hasUsageAccess;
  final DateTime cycleStartedAt;
  final Duration? activeUsage;
  final DeviceUsageRestState? restState;
}

class DeviceUsageRestState {
  const DeviceUsageRestState({
    required this.active,
    required this.startedAt,
    required this.endsAt,
    this.childName,
  });

  final bool active;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final String? childName;

  static DeviceUsageRestState fromMap(Map<Object?, Object?> map) {
    return DeviceUsageRestState(
      active: map['active'] == true,
      startedAt: _readDateTime(map['startedAtEpochMs']),
      endsAt: _readDateTime(map['endsAtEpochMs']),
      childName: (map['childName'] as String?)?.trim(),
    );
  }

  static DateTime? _readDateTime(Object? value) {
    final epochMs = switch (value) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()),
      _ => null,
    };
    if (epochMs == null || epochMs <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(epochMs);
  }
}
