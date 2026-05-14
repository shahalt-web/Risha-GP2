import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:risha_v01/shared/services/child_behavior_service.dart';
import 'package:risha_v01/shared/services/child_service.dart';
import 'package:risha_v01/shared/services/child_task_progress_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';

class LocalNotificationService {
  factory LocalNotificationService() => instance;

  LocalNotificationService._({
    FlutterLocalNotificationsPlugin? plugin,
    SelectedChildService? selectedChildService,
    ChildService? childService,
    ChildBehaviorService? childBehaviorService,
    ChildTaskProgressService? childTaskProgressService,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _selectedChildService = selectedChildService ?? SelectedChildService(),
       _childService = childService ?? ChildService(),
       _childBehaviorService = childBehaviorService ?? ChildBehaviorService(),
       _childTaskProgressService =
           childTaskProgressService ?? ChildTaskProgressService();

  static final LocalNotificationService instance = LocalNotificationService._();

  LocalNotificationService.create({
    FlutterLocalNotificationsPlugin? plugin,
    SelectedChildService? selectedChildService,
    ChildService? childService,
    ChildBehaviorService? childBehaviorService,
    ChildTaskProgressService? childTaskProgressService,
  }) : this._(
         plugin: plugin,
         selectedChildService: selectedChildService,
         childService: childService,
         childBehaviorService: childBehaviorService,
         childTaskProgressService: childTaskProgressService,
       );

  static const int _scheduleHorizonDays = 3;
  static const int _morningUnlockMinutes = 6 * 60;
  static const int _wakeSectionEndMinutes = 11 * 60;
  static const int _sleepSectionStartMinutes = 20 * 60;
  static const int _defaultSleepTimeMinutes = 21 * 60;
  static const Duration _missedReminderGrace = Duration(minutes: 90);
  static const String _timeZoneName = 'Asia/Aden';
  static const String _managedIdsKey = 'risha_local_notification_managed_ids';
  static const String _channelId = 'risha_child_routines';
  static const String _channelName = 'Risha Child Routines';
  static const String _channelDescription =
      'Morning, behavior, and missed routine reminders for the child.';

  final FlutterLocalNotificationsPlugin _plugin;
  final SelectedChildService _selectedChildService;
  final ChildService _childService;
  final ChildBehaviorService _childBehaviorService;
  final ChildTaskProgressService _childTaskProgressService;

  Future<void>? _initializationFuture;
  Future<void>? _syncFuture;
  Timer? _backgroundSyncDebounce;
  bool _pluginAvailable = true;
  Uint8List? _largeIconBytes;

  Future<void> initialize() {
    if (!_supportsCurrentPlatform) {
      _pluginAvailable = false;
      return Future<void>.value();
    }
    return _initializationFuture ??= _initializeInternal();
  }

  Future<void> syncSelectedChildNotifications() {
    if (!_supportsCurrentPlatform) {
      _pluginAvailable = false;
      return Future<void>.value();
    }
    return _syncFuture ??= _syncInternal().whenComplete(() {
      _syncFuture = null;
    });
  }

  void syncSelectedChildNotificationsInBackground({
    Duration delay = const Duration(milliseconds: 600),
  }) {
    if (!_supportsCurrentPlatform) {
      _pluginAvailable = false;
      return;
    }
    _backgroundSyncDebounce?.cancel();
    _backgroundSyncDebounce = Timer(delay, () {
      unawaited(syncSelectedChildNotifications());
    });
  }

  Future<void> clearManagedNotifications() async {
    if (!_supportsCurrentPlatform || !_pluginAvailable) {
      return;
    }
    final ids = await _readManagedNotificationIds();
    var processed = 0;
    for (final id in ids) {
      await _plugin.cancel(id);
      processed++;
      if (processed % 20 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    await _saveManagedNotificationIds(const <int>[]);
  }

  Future<void> _initializeInternal() async {
    if (!_supportsCurrentPlatform) {
      _pluginAvailable = false;
      return;
    }
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(_timeZoneName));
    } catch (_) {
      // Keep the default timezone if the named location cannot be resolved.
    }
    // تحميل صورة ريشة من مجلد assets
    try {
      final byteData = await rootBundle.load('assets/risha/risha_start.png');
      _largeIconBytes = byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('فشل تحميل صورة ريشة: $e');
    }
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    try {
      await _plugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );
    } on MissingPluginException {
      _pluginAvailable = false;
      debugPrint(
        'LocalNotificationService: flutter_local_notifications plugin is not '
        'available on ${defaultTargetPlatform.name}.',
      );
      return;
    }

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.requestNotificationsPermission();
  }

  Future<void> _handleNotificationResponse(NotificationResponse _) async {
    // The current flow only needs the system to reopen the app.
  }

  Future<void> _syncInternal() async {
    await initialize();
    if (!_pluginAvailable) {
      return;
    }

    final childId = (await _selectedChildService.getSelectedChildId())?.trim();
    if (childId == null || childId.isEmpty) {
      await clearManagedNotifications();
      return;
    }

    try {
      final childProfile = await _childService.getChildById(childId: childId);
      final behaviorConfig = await _childBehaviorService.getChildBehaviorConfig(
        childId: childId,
      );
      final todayProgress = await _childTaskProgressService
          .getSelectedChildTaskProgress();
      final plans = _buildNotificationPlans(
        childId: childId,
        childName: childProfile.name,
        config: behaviorConfig,
        todayProgress: todayProgress,
      );

      await clearManagedNotifications();

      final now = DateTime.now();
      final managedIds = <int>[];
      var processed = 0;
      for (final plan in plans) {
        if (!plan.when.isAfter(now)) {
          continue;
        }
        final notificationId = _stableNotificationId(plan.notificationKey);
        await _plugin.zonedSchedule(
          notificationId,
          plan.title,
          plan.body,
          tz.TZDateTime.from(plan.when, tz.local),
          _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: jsonEncode(<String, String>{
            'childId': childId,
            'kind': plan.kind,
            'taskId': plan.taskId ?? '',
            'dateKey': _dateKeyFor(plan.when),
          }),
        );
        managedIds.add(notificationId);
        processed++;
        if (processed % 12 == 0) {
          // Yield back to the event loop to keep UI responsive.
          await Future<void>.delayed(Duration.zero);
        }
      }

      await _saveManagedNotificationIds(managedIds);
    } catch (_) {
      await clearManagedNotifications();
    }
  }

  bool get _supportsCurrentPlatform {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => true,
      TargetPlatform.macOS => true,
      TargetPlatform.linux => true,
      TargetPlatform.fuchsia => false,
      TargetPlatform.windows => false,
    };
  }

  NotificationDetails get _notificationDetails {
    AndroidNotificationDetails androidDetails;
    if (_largeIconBytes != null) {
      androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        groupKey: 'risha-child-routines',
        ticker: 'Risha',
        largeIcon: ByteArrayAndroidBitmap(_largeIconBytes!),
        styleInformation: BigPictureStyleInformation(
          ByteArrayAndroidBitmap(_largeIconBytes!),
          contentTitle: 'ريشة',
          summaryText: 'روتينك اليومي',
        ),
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        groupKey: 'risha-child-routines',
        ticker: 'Risha',
      );
    }
    return NotificationDetails(android: androidDetails);
  }

  List<_NotificationPlan> _buildNotificationPlans({
    required String childId,
    required String childName,
    required ChildBehaviorConfig config,
    required ChildDailyTaskProgress todayProgress,
  }) {
    final plans = <_NotificationPlan>[];
    final enabledBehaviorIds = config.selectedBehaviorIds.toSet();
    final normalizedChildName = childName.trim().isEmpty ? 'الطفل' : childName;
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, now.day);
    final sleepTimeMinutes = _effectiveSleepTimeMinutes(config);

    for (var dayOffset = 0; dayOffset < _scheduleHorizonDays; dayOffset++) {
      final day = firstDay.add(Duration(days: dayOffset));
      final completedTaskIds = dayOffset == 0
          ? todayProgress.completedTaskIds
          : const <String>{};
      final dateKey = _dateKeyFor(day);

      final wakeTitles = <String>[
        if (enabledBehaviorIds.contains('morning_athkar')) 'أذكار الصباح',
        if (enabledBehaviorIds.contains('brush_teeth')) 'تنظيف الأسنان',
      ];
      final wakePendingTitles = <String>[
        if (enabledBehaviorIds.contains('morning_athkar') &&
            !completedTaskIds.contains(ChildTaskIds.quranReading))
          'أذكار الصباح',
        if (enabledBehaviorIds.contains('brush_teeth') &&
            !completedTaskIds.contains(ChildTaskIds.brushTimeMorning))
          'تنظيف الأسنان',
      ];

      plans.add(
        _NotificationPlan(
          notificationKey: '$childId|$dateKey|morning-greeting|start',
          kind: 'morning',
          when: _dateAtMinutes(day, _morningUnlockMinutes),
          title: 'جاهز لمهام اليوم يا $normalizedChildName؟ ريشة تنتظرك',
          body: _buildMorningBody(wakeTitles),
        ),
      );

      if (wakePendingTitles.isNotEmpty) {
        plans.add(
          _NotificationPlan(
            notificationKey: '$childId|$dateKey|wake-summary|missed',
            kind: 'wake_missed',
            when: _dateAtMinutes(day, _wakeSectionEndMinutes),
            title: 'تم تفويت سلوك صباحي',
            body: 'فات وقت ${_joinTitles(wakePendingTitles)} لهذا الصباح.',
          ),
        );
      }

      if (enabledBehaviorIds.contains('solve_puzzle')) {
        final puzzleTaskCompleted = completedTaskIds.contains(
          ChildTaskIds.shapeMatching,
        );
        if (!puzzleTaskCompleted) {
          plans.add(
            _NotificationPlan(
              notificationKey: '$childId|$dateKey|puzzle|start',
              kind: 'puzzle_start',
              when: _dateAtMinutes(day, _wakeSectionEndMinutes),
              title: 'ريشة محتارة... ساعدها بالحل ؟',
              body: 'حان وقت اللغز اليومي. افتح ريشة وحل اللغز معاً.',
              taskId: ChildTaskIds.shapeMatching,
            ),
          );
          plans.add(
            _NotificationPlan(
              notificationKey: '$childId|$dateKey|puzzle|missed',
              kind: 'puzzle_missed',
              when: _dateAtMinutes(day, _sleepSectionStartMinutes),
              title: 'فات وقت ريشة تفكر',
              body: 'لم تحل اللغز اليوم... جرب غداً.',
              taskId: ChildTaskIds.shapeMatching,
            ),
          );
        }
      }

      final sleepTitles = <String>[
        if (enabledBehaviorIds.contains('read_story')) 'قصة النوم',
        if (enabledBehaviorIds.contains('brush_teeth'))
          'تنظيف الأسنان قبل النوم',
      ];
      final sleepPendingTitles = <String>[
        if (enabledBehaviorIds.contains('read_story') &&
            !completedTaskIds.contains(ChildTaskIds.sleepStory))
          'قصة النوم',
        if (enabledBehaviorIds.contains('brush_teeth') &&
            !completedTaskIds.contains(ChildTaskIds.brushTimeNight))
          'تنظيف الأسنان قبل النوم',
      ];

      if (sleepTitles.isNotEmpty) {
        plans.add(
          _NotificationPlan(
            notificationKey: '$childId|$dateKey|sleep-summary|start',
            kind: 'sleep_start',
            when: _dateAtMinutes(day, _sleepSectionStartMinutes),
            title: sleepTitles.contains('قصة النوم')
                ? 'قصة قبل النوم = أحلام سعيدة'
                : 'استعداد للنوم',
            body: _buildSleepBody(sleepTitles),
          ),
        );
      }
      if (sleepPendingTitles.isNotEmpty) {
        plans.add(
          _NotificationPlan(
            notificationKey: '$childId|$dateKey|sleep-summary|missed',
            kind: 'sleep_missed',
            when: _windowEndDateTime(
              day,
              startMinutes: _sleepSectionStartMinutes,
              endMinutes: sleepTimeMinutes,
            ),
            title: 'تم تفويت سلوك قبل النوم',
            body: 'فات وقت ${_joinTitles(sleepPendingTitles)} لهذه الليلة.',
          ),
        );
      }

      if (enabledBehaviorIds.contains('drink_water')) {
        final waterSlots = _normalizedWaterSlotMinutes(
          waterCupsCount: config.waterCupsCount,
          reminderTimesMinutes: config.waterReminderTimesMinutes,
        );
        plans.addAll(
          _buildExactTaskPlans(
            childId: childId,
            day: day,
            dateKey: dateKey,
            slotMinutes: waterSlots,
            completedTaskIds: completedTaskIds,
            taskIdBuilder: ChildTaskIds.waterDrinkSlot,
            titleBuilder: (slotNumber) => 'حان وقت كوب الماء $slotNumber',
            startBodyBuilder: (slotNumber) =>
                'تذكير بكوب الماء رقم $slotNumber داخل ريشة.',
            missedTitleBuilder: (slotNumber) => 'فات وقت كوب الماء $slotNumber',
            missedBodyBuilder: (slotNumber) =>
                'تم تفويت الموعد المحدد لكوب الماء رقم $slotNumber.',
            keyPrefix: 'water-slot',
          ),
        );
      }

      if (enabledBehaviorIds.contains('sport_activity')) {
        final sportSlots = _normalizedSportSlotMinutes(
          config.sportSessionTimesMinutes,
        );
        plans.addAll(
          _buildExactTaskPlans(
            childId: childId,
            day: day,
            dateKey: dateKey,
            slotMinutes: sportSlots,
            completedTaskIds: completedTaskIds,
            taskIdBuilder: ChildTaskIds.exerciseSlot,
            titleBuilder: (slotNumber) => 'حان وقت النشاط الرياضي $slotNumber',
            startBodyBuilder: (slotNumber) =>
                'تذكير بجلسة النشاط الرياضي رقم $slotNumber.',
            missedTitleBuilder: (slotNumber) =>
                'فات موعد النشاط الرياضي $slotNumber',
            missedBodyBuilder: (slotNumber) =>
                'تم تفويت الموعد المحدد لجلسة النشاط الرياضي رقم $slotNumber.',
            keyPrefix: 'sport-slot',
          ),
        );
      }

      for (final behavior in config.customBehaviors) {
        if (!enabledBehaviorIds.contains(behavior.id)) {
          continue;
        }
        final customSlots = _normalizedCustomReminderTimes(behavior);
        plans.addAll(
          _buildExactTaskPlans(
            childId: childId,
            day: day,
            dateKey: dateKey,
            slotMinutes: customSlots,
            completedTaskIds: completedTaskIds,
            taskIdBuilder: (slotNumber) =>
                ChildTaskIds.customBehaviorSlot(behavior.id, slotNumber),
            titleBuilder: (_) => 'حان وقت ${behavior.title}',
            startBodyBuilder: (_) =>
                'هذا تذكير بالسلوك "${behavior.title}" داخل ريشة.',
            missedTitleBuilder: (_) => 'تم تفويت ${behavior.title}',
            missedBodyBuilder: (_) =>
                'فات الموعد المحدد للسلوك "${behavior.title}".',
            keyPrefix: 'custom:${behavior.id}',
          ),
        );
      }
    }

    return plans;
  }

  List<_NotificationPlan> _buildExactTaskPlans({
    required String childId,
    required DateTime day,
    required String dateKey,
    required List<int> slotMinutes,
    required Set<String> completedTaskIds,
    required String Function(int slotNumber) taskIdBuilder,
    required String Function(int slotNumber) titleBuilder,
    required String Function(int slotNumber) startBodyBuilder,
    required String Function(int slotNumber) missedTitleBuilder,
    required String Function(int slotNumber) missedBodyBuilder,
    required String keyPrefix,
  }) {
    final plans = <_NotificationPlan>[];
    final sortedSlots = List<int>.from(slotMinutes)
      ..sort((a, b) => a.compareTo(b));

    for (var i = 0; i < sortedSlots.length; i++) {
      final slotNumber = i + 1;
      final taskId = taskIdBuilder(slotNumber);
      if (completedTaskIds.contains(taskId)) {
        continue;
      }

      final startDateTime = _dateAtMinutes(day, sortedSlots[i]);
      final nextSlotDateTime = i + 1 < sortedSlots.length
          ? _dateAtMinutes(day, sortedSlots[i + 1])
          : null;
      final missedDateTime = _missedDateTimeForExactTask(
        startDateTime: startDateTime,
        nextSlotDateTime: nextSlotDateTime,
      );

      plans.add(
        _NotificationPlan(
          notificationKey: '$childId|$dateKey|$keyPrefix:$slotNumber|start',
          kind: 'exact_start',
          when: startDateTime,
          title: _getCustomTitle(keyPrefix, slotNumber),
          body: startBodyBuilder(slotNumber),
          taskId: taskId,
        ),
      );
      plans.add(
        _NotificationPlan(
          notificationKey: '$childId|$dateKey|$keyPrefix:$slotNumber|missed',
          kind: 'exact_missed',
          when: missedDateTime,
          title: _getMissedTitle(keyPrefix),
          body: missedBodyBuilder(slotNumber),
          taskId: taskId,
        ),
      );
    }

    return plans;
  }

  DateTime _missedDateTimeForExactTask({
    required DateTime startDateTime,
    required DateTime? nextSlotDateTime,
  }) {
    final graceDateTime = startDateTime.add(_missedReminderGrace);
    if (nextSlotDateTime == null || !nextSlotDateTime.isAfter(startDateTime)) {
      return graceDateTime;
    }
    return nextSlotDateTime.isBefore(graceDateTime)
        ? nextSlotDateTime
        : graceDateTime;
  }

  int _effectiveSleepTimeMinutes(ChildBehaviorConfig config) {
    if (config.sleepRoutineConfigured) {
      return (config.sleepHour * 60) + config.sleepMinute;
    }
    return _defaultSleepTimeMinutes;
  }

  List<int> _normalizedWaterSlotMinutes({
    required int waterCupsCount,
    required List<int> reminderTimesMinutes,
  }) {
    final cupCount = waterCupsCount
        .clamp(1, ChildTaskIds.maxWaterSlotsPerDay)
        .toInt();
    final cleaned = List<int>.from(reminderTimesMinutes)
      ..sort((a, b) => a.compareTo(b));
    if (cleaned.isEmpty) {
      return _defaultWaterSlotMinutes(cupCount);
    }
    return cleaned
        .take(cupCount)
        .map((minutes) => minutes.clamp(0, 1439).toInt())
        .toList(growable: false);
  }

  List<int> _defaultWaterSlotMinutes(int cupCount) {
    final safeCupCount = cupCount
        .clamp(1, ChildTaskIds.maxWaterSlotsPerDay)
        .toInt();
    const startMinutes = 8 * 60;
    const endMinutes = 20 * 60;
    final span = endMinutes - startMinutes;
    if (safeCupCount == 1) {
      return const <int>[14 * 60];
    }

    final interval = span / (safeCupCount + 1);
    return List<int>.generate(safeCupCount, (index) {
      return (startMinutes + (interval * (index + 1))).round();
    }, growable: false);
  }

  List<int> _normalizedSportSlotMinutes(List<int> rawTimes) {
    final cleaned = List<int>.from(rawTimes)..sort((a, b) => a.compareTo(b));
    if (cleaned.isEmpty) {
      return const <int>[8 * 60];
    }
    return cleaned
        .take(ChildTaskIds.maxExerciseSlotsPerDay)
        .map((minutes) => minutes.clamp(0, 1439).toInt())
        .toList(growable: false);
  }

  List<int> _normalizedCustomReminderTimes(CustomBehaviorConfig behavior) {
    final slotCount = behavior.repeatCount
        .clamp(1, ChildTaskIds.maxCustomBehaviorSlotsPerDay)
        .toInt();
    final cleaned = List<int>.from(behavior.reminderTimesMinutes)
      ..sort((a, b) => a.compareTo(b));
    if (cleaned.isEmpty) {
      return List<int>.generate(
        slotCount,
        (index) => ((8 * 60) + ((index + 1) * 60)) % Duration.minutesPerDay,
        growable: false,
      );
    }
    return cleaned
        .take(slotCount)
        .map((minutes) => minutes.clamp(0, 1439).toInt())
        .toList(growable: false);
  }

  DateTime _dateAtMinutes(DateTime day, int minutes) {
    final normalizedMinutes =
        ((minutes % Duration.minutesPerDay) + Duration.minutesPerDay) %
        Duration.minutesPerDay;
    return DateTime(
      day.year,
      day.month,
      day.day,
      normalizedMinutes ~/ 60,
      normalizedMinutes % 60,
    );
  }

  DateTime _windowEndDateTime(
    DateTime day, {
    required int startMinutes,
    required int endMinutes,
  }) {
    final endDateTime = _dateAtMinutes(day, endMinutes);
    if (endMinutes <= startMinutes) {
      return endDateTime.add(const Duration(days: 1));
    }
    return endDateTime;
  }

  String _dateKeyFor(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _joinTitles(List<String> titles) {
    final cleanTitles = titles
        .map((title) => title.trim())
        .where((title) => title.isNotEmpty)
        .toList(growable: false);
    if (cleanTitles.isEmpty) {
      return 'سلوكيات اليوم';
    }
    if (cleanTitles.length == 1) {
      return cleanTitles.first;
    }
    if (cleanTitles.length == 2) {
      return '${cleanTitles.first} و${cleanTitles.last}';
    }
    return '${cleanTitles.sublist(0, cleanTitles.length - 1).join('، ')}، و${cleanTitles.last}';
  }

  int _stableNotificationId(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  Future<List<int>> _readManagedNotificationIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_managedIdsKey);
      if (raw == null || raw.trim().isEmpty) {
        return const <int>[];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <int>[];
      }
      return decoded
          .map((item) {
            if (item is int) {
              return item;
            }
            if (item is num) {
              return item.toInt();
            }
            if (item is String) {
              return int.tryParse(item);
            }
            return null;
          })
          .whereType<int>()
          .toSet()
          .toList(growable: false);
    } catch (_) {
      return const <int>[];
    }
  }

  Future<void> _saveManagedNotificationIds(List<int> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _managedIdsKey,
        jsonEncode(ids.toSet().toList(growable: false)),
      );
    } catch (_) {
      // Ignore local storage failures to keep notification sync non-blocking.
    }
  }

  String _buildMorningBody(List<String> titles) {
    // titles تحتوي على السلوكيات المقررة هذا الصباح
    if (titles.contains('أذكار الصباح') && titles.contains('تنظيف الأسنان')) {
      return 'وقت أذكار الصباح 😉 وفرشاة ومعجون... يلا نبدأ';
    } else if (titles.contains('أذكار الصباح')) {
      return 'وقت أذكار الصباح 😉';
    } else if (titles.contains('تنظيف الأسنان')) {
      return 'فرشاة ومعجون... يلا نبدأ';
    } else {
      return 'افتحي ريشة وابدئي يومك الجميل.';
    }
  }

  String _buildSleepBody(List<String> titles) {
    if (titles.contains('قصة النوم') &&
        titles.contains('تنظيف الأسنان قبل النوم')) {
      return 'اقرأ قصتك ثم نظف أسنانك مثل ريشة';
    } else if (titles.contains('قصة النوم')) {
      return 'قصة قبل النوم = أحلام سعيدة';
    } else if (titles.contains('تنظيف الأسنان قبل النوم')) {
      return 'نظف أسنانك مثل ريشة';
    } else {
      return 'استعد للنوم باكراً.';
    }
  }

  String _getCustomTitle(String keyPrefix, int slotNumber) {
    if (keyPrefix.startsWith('water-slot')) {
      return 'وقت كوب الماء';
    } else if (keyPrefix.startsWith('sport-slot')) {
      return 'حركة بسيطة تخليك أقوى!';
    } else if (keyPrefix.startsWith('custom:')) {
      return 'تذكير بالسلوك المخصص';
    } else {
      return 'تذكير بمهمتك';
    }
  }

  String _getMissedTitle(String keyPrefix) {
    if (keyPrefix.startsWith('water-slot')) {
      return 'فات وقت كوب الماء';
    } else if (keyPrefix.startsWith('sport-slot')) {
      return 'فات موعد الحركة';
    } else {
      return 'تم تفويت المهمة';
    }
  }
}

class _NotificationPlan {
  const _NotificationPlan({
    required this.notificationKey,
    required this.kind,
    required this.when,
    required this.title,
    required this.body,
    this.taskId,
  });

  final String notificationKey;
  final String kind;
  final DateTime when;
  final String title;
  final String body;
  final String? taskId;
}
