import 'package:flutter_test/flutter_test.dart';

import 'integration/parent_child_flow_test.dart' as flow;
import 'integration/reward_email_flow_test.dart' as email;
import 'report_test_suite.dart' as report_suite;
import 'unit/apps_script_email_backend_test.dart' as apps_script_email;
import 'unit/child_profile_and_behavior_test.dart' as profiles;
import 'unit/coins_and_rewards_test.dart' as coins;
import 'unit/email_notification_service_test.dart' as email_service;
import 'unit/task_progress_test.dart' as tasks;
import 'unit/usage_rest_guard_test.dart' as usage_rest;
import 'unit/validators_test.dart' as validators;
import 'widget/dashboard_test.dart' as dashboard_ui;
import 'widget/login_screen_test.dart' as login_ui;

void main() {
  group('Risha complete automated test suite', () {
    group('Unit tests', () {
      validators.main();
      coins.main();
      tasks.main();
      profiles.main();
      email_service.main();
      apps_script_email.main();
      usage_rest.main();
    });

    group('Integration tests', () {
      flow.main();
      email.main();
    });

    group('Report verification tests', () {
      report_suite.main();
    });

    group('Widget tests', () {
      login_ui.main();
      dashboard_ui.main();
    });
  });
}
