import 'dart:async';

import 'package:risha_v01/shared/services/email_notification_service.dart';
import 'package:risha_v01/shared/services/local_notification_service.dart';

class BackgroundStartupCoordinator {
  BackgroundStartupCoordinator({
    LocalNotificationService? localNotificationService,
    EmailNotificationService? emailNotificationService,
    Duration initialDelay = const Duration(minutes: 1),
    Duration notificationSyncDelay = const Duration(seconds: 45),
    Duration emailSyncDelay = const Duration(seconds: 45),
  }) : _localNotificationService =
           localNotificationService ?? LocalNotificationService.instance,
       _emailNotificationService =
           emailNotificationService ?? EmailNotificationService(),
       _initialDelay = initialDelay,
       _notificationSyncDelay = notificationSyncDelay,
       _emailSyncDelay = emailSyncDelay;

  final LocalNotificationService _localNotificationService;
  final EmailNotificationService _emailNotificationService;
  final Duration _initialDelay;
  final Duration _notificationSyncDelay;
  final Duration _emailSyncDelay;

  Timer? _initTimer;
  Timer? _notificationTimer;
  Timer? _emailTimer;
  bool _isEligible = false;
  bool _isScheduled = false;
  bool _isActivated = false;

  bool get isActivated => _isActivated;

  void updateEligibility({
    required bool hasSelectedChild,
    required bool isChildRouteActive,
  }) {
    final eligible = hasSelectedChild && isChildRouteActive;
    _isEligible = eligible;

    if (!eligible) {
      if (!_isActivated) {
        _cancelTimers();
        _isScheduled = false;
      }
      if (!hasSelectedChild) {
        _emailNotificationService.disableBackgroundDispatch(stopRetryLoop: true);
        _isActivated = false;
      }
      return;
    }

    if (_isActivated || _isScheduled) {
      return;
    }

    _isScheduled = true;
    _initTimer = Timer(_initialDelay, _runNotificationInitializationStep);
  }

  void dispose() {
    _cancelTimers();
  }

  void _runNotificationInitializationStep() {
    if (!_isEligible) {
      _isScheduled = false;
      return;
    }

    unawaited(_localNotificationService.initialize());
    _notificationTimer = Timer(_notificationSyncDelay, _runNotificationSyncStep);
  }

  void _runNotificationSyncStep() {
    if (!_isEligible) {
      _isScheduled = false;
      return;
    }

    _localNotificationService.syncSelectedChildNotificationsInBackground(
      delay: const Duration(milliseconds: 250),
    );
    _emailTimer = Timer(_emailSyncDelay, _runEmailSyncStep);
  }

  void _runEmailSyncStep() {
    if (!_isEligible) {
      _isScheduled = false;
      return;
    }

    _emailNotificationService.enableBackgroundDispatch();
    _emailNotificationService.startPendingRewardEmailSyncLoop();
    _isActivated = true;
    _isScheduled = false;
    _cancelTimers();
  }

  void _cancelTimers() {
    _initTimer?.cancel();
    _notificationTimer?.cancel();
    _emailTimer?.cancel();
    _initTimer = null;
    _notificationTimer = null;
    _emailTimer = null;
  }
}
