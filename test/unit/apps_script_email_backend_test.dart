import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String appsScriptSource;
  late String flutterEmailConfig;

  setUpAll(() {
    appsScriptSource = File(
      'apps_script/risha_mail_backend/Code.gs',
    ).readAsStringSync();
    flutterEmailConfig = File(
      'lib/shared/config/apps_script_email_config.dart',
    ).readAsStringSync();
  });

  test('pending reward emails stay outside recent-event deduplication', () {
    final match = RegExp(
      r'const exemptEvents = \{([\s\S]*?)\};',
    ).firstMatch(appsScriptSource);

    expect(match, isNotNull);
    expect(match!.group(1), contains('pending_reward'));
  });

  test('pending reward action links use the same Web App URL as Flutter', () {
    final dartUrl = RegExp(
      r"webAppUrl\s*=\s*'([^']+)'",
    ).firstMatch(flutterEmailConfig)?.group(1);
    final appsScriptUrl = RegExp(
      r'appsScriptWebAppUrl:\s*\r?\n\s*"([^"]+)"',
    ).firstMatch(appsScriptSource)?.group(1);

    expect(appsScriptUrl, isNotNull);
    expect(appsScriptUrl?.trim(), dartUrl?.trim());
  });

  test('Flutter Web App URL has no leading or trailing whitespace', () {
    final dartUrl = RegExp(
      r"webAppUrl\s*=\s*'([^']+)'",
    ).firstMatch(flutterEmailConfig)?.group(1);

    expect(dartUrl, isNotNull);
    expect(dartUrl, dartUrl!.trim());
  });

  test(
    'queued email operations stay pending when Google email quota is exhausted',
    () {
      expect(appsScriptSource, contains('function isEmailQuotaError_'));
      expect(appsScriptSource, contains('nextEmailQuotaRetryIso_()'));
      expect(
        appsScriptSource,
        contains('!isEmailQuotaFailure && attemptCount >= 5'),
      );
    },
  );

  test('verification code records are restored when email sending fails', () {
    expect(
      appsScriptSource,
      contains('restoreVerificationRecordAfterFailedEmail_'),
    );
    expect(
      appsScriptSource,
      contains('restorePasswordResetRecordAfterFailedEmail_'),
    );
  });

  test('child activity email queue can be processed immediately', () {
    final match = RegExp(
      r'function shouldProcessOperationImmediately_\(operationType\) \{([\s\S]*?)\n\}',
    ).firstMatch(appsScriptSource);

    expect(match, isNotNull);
    expect(match!.group(1), contains('type === "child_activity_email"'));
  });
}
