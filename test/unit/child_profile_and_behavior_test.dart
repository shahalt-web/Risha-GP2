/// R3 / R12 – Child Profile & Behavior Config Unit Tests
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:risha_v01/shared/services/child_service.dart';
import 'package:risha_v01/shared/services/child_behavior_service.dart';

void main() {
  // ── ChildProfile ──
  group('ChildProfile (R3)', () {
    test('fromMap creates profile with correct fields', () {
      final profile = ChildProfile.fromMap({
        'name': 'أحمد',
        'ageYears': 7,
        'avatarBase64': 'abc123',
      }, id: 'child-001');

      expect(profile.id, 'child-001');
      expect(profile.name, 'أحمد');
      expect(profile.ageYears, 7);
      expect(profile.avatarBase64, 'abc123');
    });

    test('fromMap trims name whitespace', () {
      final profile = ChildProfile.fromMap({
        'name': '  سارة  ',
      }, id: 'child-002');
      expect(profile.name, 'سارة');
    });

    test('fromMap handles missing name as empty string', () {
      final profile = ChildProfile.fromMap({}, id: 'child-003');
      expect(profile.name, isEmpty);
    });

    test('fromMap parses ageYears from string', () {
      final profile = ChildProfile.fromMap({
        'name': 'خالد',
        'ageYears': '5',
      }, id: 'child-004');
      expect(profile.ageYears, 5);
    });

    test('fromMap returns null ageYears for non-numeric', () {
      final profile = ChildProfile.fromMap({
        'name': 'نور',
        'ageYears': 'abc',
      }, id: 'child-005');
      expect(profile.ageYears, isNull);
    });

    test('toMap serializes correctly', () {
      const profile = ChildProfile(
        id: 'child-006',
        name: 'ريم',
        ageYears: 8,
        avatarBase64: 'img_data',
      );
      final map = profile.toMap();
      expect(map['name'], 'ريم');
      expect(map['ageYears'], 8);
      expect(map['avatarBase64'], 'img_data');
      // id is not in toMap – used as document key
      expect(map.containsKey('id'), isFalse);
    });

    test('toMap excludes null ageYears', () {
      const profile = ChildProfile(id: 'c1', name: 'test');
      final map = profile.toMap();
      expect(map.containsKey('ageYears'), isFalse);
    });

    test('toMap excludes empty avatarBase64', () {
      const profile = ChildProfile(id: 'c2', name: 'test', avatarBase64: '  ');
      final map = profile.toMap();
      expect(map.containsKey('avatarBase64'), isFalse);
    });

    test('FAIL case: fromMap with null name produces empty string', () {
      final profile = ChildProfile.fromMap({'name': null}, id: 'c3');
      expect(profile.name, isEmpty);
    });
  });

  // ── ChildBehaviorConfig ──
  group('ChildBehaviorConfig (R4/R12)', () {
    test('defaults() returns valid default configuration', () {
      final defaults = ChildBehaviorConfig.defaults();
      expect(defaults.selectedBehaviorIds, isNotEmpty);
      expect(defaults.waterCupsCount, 2);
      expect(defaults.sportSessionsCount, 1);
      expect(defaults.sleepRoutineConfigured, isFalse);
    });

    test('fromMap reads water config correctly', () {
      final config = ChildBehaviorConfig.fromMap({
        'selectedBehaviorIds': ['drink_water', 'sport_activity'],
        'water': {
          'cupsCount': 4,
          'reminderTimes': [
            {'hour': 8, 'minute': 0},
            {'hour': 10, 'minute': 30},
            {'hour': 14, 'minute': 0},
            {'hour': 18, 'minute': 0},
          ],
        },
        'sport': {'sessionsCount': 2, 'lightActivityEnabled': false},
        'sleep': {'hour': 21, 'minute': 30, 'configured': true},
      });

      expect(config.selectedBehaviorIds, contains('drink_water'));
      expect(config.waterCupsCount, 4);
      expect(config.sportSessionsCount, 2);
      expect(config.sportLightActivityEnabled, isFalse);
      expect(config.sleepHour, 21);
      expect(config.sleepMinute, 30);
      expect(config.sleepRoutineConfigured, isTrue);
    });

    test('fromMap clamps waterCupsCount to 1-12', () {
      final config = ChildBehaviorConfig.fromMap({
        'selectedBehaviorIds': ['morning_athkar'],
        'water': {'cupsCount': 50},
        'sleep': {'hour': 0, 'minute': 0, 'configured': true},
      });
      expect(config.waterCupsCount, 12);
    });

    test('fromMap clamps sportSessionsCount to 1-6', () {
      final config = ChildBehaviorConfig.fromMap({
        'selectedBehaviorIds': ['sport_activity'],
        'sport': {'sessionsCount': 20},
        'sleep': {'hour': 0, 'minute': 0, 'configured': true},
      });
      expect(config.sportSessionsCount, 6);
    });

    test('fromMap clamps sleep hour/minute', () {
      final config = ChildBehaviorConfig.fromMap({
        'selectedBehaviorIds': ['morning_athkar'],
        'sleep': {'hour': 99, 'minute': -5, 'configured': true},
      });
      expect(config.sleepHour, 23);
      expect(config.sleepMinute, 0);
    });

    test('toMap/fromMap round-trips correctly', () {
      final original = ChildBehaviorConfig.fromMap({
        'selectedBehaviorIds': ['drink_water'],
        'water': {'cupsCount': 3},
        'sport': {'sessionsCount': 1, 'lightActivityEnabled': true},
        'sleep': {
          'hour': 20,
          'minute': 45,
          'notificationsEnabled': true,
          'configured': true,
        },
      });
      final map = original.toMap();
      final restored = ChildBehaviorConfig.fromMap(map);

      expect(restored.waterCupsCount, original.waterCupsCount);
      expect(restored.sleepHour, original.sleepHour);
      expect(restored.sleepMinute, original.sleepMinute);
    });

    test('FAIL case: empty selectedBehaviorIds falls back to defaults', () {
      final config = ChildBehaviorConfig.fromMap({
        'selectedBehaviorIds': [],
        'sleep': {'configured': true},
      });
      final defaults = ChildBehaviorConfig.defaults();
      expect(config.selectedBehaviorIds, defaults.selectedBehaviorIds);
    });
  });

  // ── CustomBehaviorConfig ──
  group('CustomBehaviorConfig (R4)', () {
    test('fromMap creates config with correct fields', () {
      final config = CustomBehaviorConfig.fromMap({
        'id': 'custom_001',
        'title': 'قراءة كتاب',
        'repeatCount': 3,
        'periods': ['morning', 'evening'],
      });
      expect(config.id, 'custom_001');
      expect(config.title, 'قراءة كتاب');
      expect(config.repeatCount, 3);
      expect(config.periods, hasLength(2));
    });

    test('repeatCount is clamped to 1-10', () {
      final config = CustomBehaviorConfig.fromMap({
        'id': 'custom_002',
        'title': 'test',
        'repeatCount': 99,
        'periods': [],
      });
      expect(config.repeatCount, 10);
    });

    test('toMap serializes correctly', () {
      final config = CustomBehaviorConfig.fromMap({
        'id': 'custom_003',
        'title': 'رياضة',
        'repeatCount': 2,
        'periods': ['morning'],
      });
      final map = config.toMap();
      expect(map['id'], 'custom_003');
      expect(map['title'], 'رياضة');
      expect(map['repeatCount'], 2);
    });
  });
}
