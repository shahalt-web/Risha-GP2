import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String appSource;
  late String usageRestOverlayServiceSource;

  setUpAll(() {
    appSource = File('lib/app.dart').readAsStringSync();
    usageRestOverlayServiceSource = File(
      'android/app/src/main/kotlin/com/example/risha/UsageRestOverlayService.kt',
    ).readAsStringSync();
  });

  test('production usage-rest timing is not left in quick-test values', () {
    expect(
      appSource,
      contains('static const Duration _usageThreshold = Duration(hours: 2);'),
    );
    expect(
      appSource,
      contains('static const Duration _restDuration = Duration(minutes: 30);'),
    );
  });

  test('UsageRestOverlayService stops invalid foreground starts safely', () {
    final invalidStateBranch = RegExp(
      r'if \(!state\.isActiveAt\(\) \|\| !SleepLockController\.isOverlayPermissionGranted\(this\)\) \{([\s\S]*?)\n\s*\}',
    ).firstMatch(usageRestOverlayServiceSource)?.group(1);

    expect(invalidStateBranch, isNotNull);
    expect(invalidStateBranch, contains('stopSelf(startId)'));
    expect(
      invalidStateBranch,
      isNot(contains('UsageRestController.syncServiceState(this)')),
    );
  });
}
