const CONFIG = {
  appName: "ريشة",
  sharedSecret:
    "EBMSMTheBestNoOnCanDefatMeEverNever-that-I-create-this-pro-app",
  firebaseProjectId: "risha-9f2f2",
  timeZone: "Asia/Aden",
  appsScriptWebAppUrl:
    //رابط الخدمة الرئيسي
    //"https://script.google.com/macros/s/AKfycbxZQM6va_m3rv82v6a3Z8RiS3MPe_QOmaOAEDMWnVQMub8Bm1-C6bMkdXmdlarP2SBBTA/exec"
    //الرابط الخدمة الاحتياطي
    "https://script.google.com/macros/s/AKfycbyg00GCxtn_3E9M_FlmdnObYMvVy1KzBrRxLau8JohacUZHvSzUW6mpOlfdL47QRq8o/exec",
  storageTitle: "Risha Mail Backend Storage",
  verificationCodeLength: 6,
  verificationExpiryMinutes: 15,
  verificationCooldownSeconds: 60,
  dailyWarningHour: 21,
  weeklyStatsHour: 18,
  //  firebasePendingRewardActionHost:
  //    'https://us-central1-risha-9f2f2.cloudfunctions.net/handlePendingRewardAction',
  managedTriggerHandlers: [
    "sendScheduledDailyWarnings",
    "sendScheduledWeeklyStats",
    "processOperationsQueue",
  ],
};

const STORAGE_PROPERTY_KEY = "RISHA_STORAGE_SPREADSHEET_ID";
const FUNCTION_REGION = "us-central1";

const SHEETS = {
  users: "users",
  children: "children",
  childrenArchive: "children_archive",
  behaviors: "behavior_configs",
  behaviorsArchive: "behavior_configs_archive",
  dailyProgress: "daily_progress",
  dailyProgressArchive: "daily_progress_archive",
  verificationCodes: "verification_codes",
  passwordResetCodes: "password_reset_codes",
  emailLog: "email_log",
  operationsQueue: "operations_queue",
};

const SHEET_TO_FIRESTORE_COLLECTION = {
  [SHEETS.users]: "users",
  [SHEETS.children]: "children",
  [SHEETS.childrenArchive]: "children_archive",
  [SHEETS.behaviors]: "behavior_configs",
  [SHEETS.behaviorsArchive]: "behavior_configs_archive",
  [SHEETS.dailyProgress]: "daily_progress",
  [SHEETS.dailyProgressArchive]: "daily_progress_archive",
  [SHEETS.verificationCodes]: "verification_codes",
  [SHEETS.passwordResetCodes]: "password_reset_codes",
  [SHEETS.emailLog]: "email_log",
  [SHEETS.operationsQueue]: "operations_queue",
};

const HEADERS = {
  users: [
    "uid",
    "email",
    "locale",
    "notifications_enabled",
    "verification_enabled",
    "welcome_guide_enabled",
    "login_enabled",
    "child_activity_enabled",
    "weekly_stats_enabled",
    "daily_warnings_enabled",
    "email_verified",
    "welcome_sent_at_iso",
    "created_at_iso",
    "updated_at_iso",
    "last_login_at_iso",
  ],
  children: [
    "uid",
    "child_id",
    "child_name",
    "age_years",
    "avatar_present",
    "updated_at_iso",
  ],
  childrenArchive: [
    "uid",
    "child_id",
    "child_name",
    "age_years",
    "avatar_present",
    "updated_at_iso",
    "deleted_at_iso",
  ],
  behaviors: [
    "uid",
    "child_id",
    "selected_behavior_ids_json",
    "custom_behaviors_json",
    "water_cups_count",
    "sport_sessions_count",
    "sport_light_activity_enabled",
    "sport_session_times_json",
    "sleep_hour",
    "sleep_minute",
    "sleep_notifications_enabled",
    "sleep_routine_configured",
    "synced_at_iso",
  ],
  behaviorsArchive: [
    "uid",
    "child_id",
    "selected_behavior_ids_json",
    "custom_behaviors_json",
    "water_cups_count",
    "sport_sessions_count",
    "sport_light_activity_enabled",
    "sport_session_times_json",
    "sleep_hour",
    "sleep_minute",
    "sleep_notifications_enabled",
    "sleep_routine_configured",
    "synced_at_iso",
    "deleted_at_iso",
  ],
  dailyProgress: [
    "uid",
    "child_id",
    "date_key",
    "completed_task_ids_json",
    "total_task_count",
    "awarded_coins_by_task_id_json",
    "completion_ratio",
    "planned_task_ids_json",
    "planned_task_titles_json",
    "synced_at_iso",
  ],
  dailyProgressArchive: [
    "uid",
    "child_id",
    "date_key",
    "completed_task_ids_json",
    "total_task_count",
    "awarded_coins_by_task_id_json",
    "completion_ratio",
    "planned_task_ids_json",
    "planned_task_titles_json",
    "synced_at_iso",
    "deleted_at_iso",
  ],
  verificationCodes: [
    "uid",
    "email",
    "code_hash",
    "expires_at_iso",
    "last_sent_at_iso",
    "verified_at_iso",
  ],
  passwordResetCodes: [
    "uid",
    "email",
    "code_hash",
    "expires_at_iso",
    "last_sent_at_iso",
    "verified_at_iso",
    "used_at_iso",
  ],
  emailLog: [
    "timestamp_iso",
    "uid",
    "email",
    "event_type",
    "subject",
    "status",
    "details",
  ],
  operationsQueue: [
    "operation_id",
    "operation_type",
    "uid",
    "child_id",
    "payload_json",
    "status",
    "attempt_count",
    "next_attempt_at_iso",
    "last_error",
    "received_at_iso",
    "processed_at_iso",
  ],
};

const TRACKED_TASKS = {
  morning_athkar: { id: "quran-reading", title: "أذكار الصباح" },
  brush_teeth: { id: "brush-time", title: "تنظيف الأسنان" },
  drink_water: { id: "water-drink", title: "شرب الماء" },
  solve_puzzle: { id: "shape-matching", title: "حل اللغز" },
  sport_activity: { id: "exercising", title: "النشاط الرياضي" },
  read_story: { id: "sleep-story", title: "قراءة القصة" },
};

function doGet(e) {
  const query = e && e.parameter ? e.parameter : {};
  const action = stringValue_(query.action);
  if (action === "pending_reward") {
    return handlePendingRewardActionGet_(query);
  }

  return jsonResponse_({
    ok: true,
    data: {
      message: "Risha Apps Script mail backend is running.",
    },
  });
}

function doPost(e) {
  console.log("Incoming POST request: " + JSON.stringify(e));
  try {
    const request = parseRequestBody_(e);
    authorizeRequest_(request);

    const action = stringValue_(request.action);
    const payload = asObject_(request.payload);

    console.log(
      "Action: " +
        action +
        " | Payload keys: " +
        Object.keys(payload).join(", "),
    );

    const data = handleAction_(action, payload);

    return jsonResponse_({
      ok: true,
      data: data || {},
    });
  } catch (error) {
    console.error(
      "doPost Error: " + error.message + " | Stack: " + error.stack,
    );
    return jsonResponse_({
      ok: false,
      error: {
        message: toErrorMessage_(error),
      },
    });
  }
}

function setupRishaMailBackend() {
  ensureStorageSpreadsheet_();
  installRishaMailTriggers();
  Logger.log("Storage spreadsheet: %s", getRishaMailStorageUrl());
}

function installRishaMailTriggers() {
  const existingTriggers = ScriptApp.getProjectTriggers();
  existingTriggers.forEach((trigger) => {
    const handler = trigger.getHandlerFunction();
    if (CONFIG.managedTriggerHandlers.indexOf(handler) !== -1) {
      ScriptApp.deleteTrigger(trigger);
    }
  });

  ScriptApp.newTrigger("sendScheduledDailyWarnings")
    .timeBased()
    .everyDays(1)
    .atHour(CONFIG.dailyWarningHour)
    .inTimezone(CONFIG.timeZone)
    .create();

  ScriptApp.newTrigger("sendScheduledWeeklyStats")
    .timeBased()
    .onWeekDay(ScriptApp.WeekDay.FRIDAY)
    .atHour(CONFIG.weeklyStatsHour)
    .inTimezone(CONFIG.timeZone)
    .create();

  ScriptApp.newTrigger("processOperationsQueue")
    .timeBased()
    .everyMinutes(1)
    .create();
}

function getRishaMailStorageUrl() {
  return ensureStorageSpreadsheet_().getUrl();
}

/**
 * ===== دالة تشخيصية للاختبار اليدوي =====
 * قم بتشغيل هذه الدالة مباشرة من محرر Apps Script
 * لتشخيص سبب عدم إرسال إيميل الموافقة على المكافأة.
 *
 * قبل التشغيل: ابحث عن سطر REPLACE_WITH_PARENT_EMAIL واستبدله ببريد ولي الأمر.
 */
function diagnosePendingRewardEmail() {
  // ← استبدل هذا بالبريد الإلكتروني الفعلي لولي الأمر
  const parentEmail = "[EMAIL_ADDRESS]";

  console.log("=== بدء تشخيص إيميل المكافأة ===");
  console.log("البريد المستهدف: " + parentEmail);

  // الخطوة 1: هل يوجد سجل للمستخدم في الشيتس؟
  const usersSheet = getSheetRecords_(SHEETS.users);
  const userRow = usersSheet.find(
    (r) => stringValue_(r.email).toLowerCase() === parentEmail.toLowerCase(),
  );
  if (!userRow) {
    console.error(
      "❌ المستخدم غير موجود في جدول users. يجب أن يقوم ولي الأمر بتسجيل الدخول أولاً لإنشاء سجله.",
    );
    return;
  }
  console.log("✅ سجل المستخدم موجود:");
  console.log("  email_verified = " + userRow.email_verified);
  console.log("  notifications_enabled = " + userRow.notifications_enabled);
  console.log("  child_activity_enabled = " + userRow.child_activity_enabled);

  // الخطوة 2: هل هناك عمليات معلقة في الطابور؟
  const queue = getSheetRecords_(SHEETS.operationsQueue);
  const pendingRewards = queue.filter((r) => {
    const type = stringValue_(r.operation_type);
    const status = stringValue_(r.status).toLowerCase();
    return (
      type === "pending_reward_email" &&
      status !== "completed" &&
      status !== "failed"
    );
  });
  console.log(
    "📬 عدد طلبات المكافأة المعلقة في الطابور: " + pendingRewards.length,
  );
  pendingRewards.forEach((r, i) => {
    console.log(
      "  طلب " +
        (i + 1) +
        ": operation_id=" +
        r.operation_id +
        " status=" +
        r.status +
        " attempts=" +
        r.attempt_count +
        " last_error=" +
        r.last_error,
    );
  });

  // الخطوة 3: اختبار إرسال إيميل تجريبي مباشر
  console.log("\n🧪 اختبار إرسال إيميل تجريبي...");
  try {
    const testPayload = {
      eventType: "pending_reward",
      user: {
        uid: stringValue_(userRow.uid),
        email: parentEmail,
        emailVerification: { isVerified: true },
        notificationSettings: { enabled: true, childActivity: true },
        welcomeGuide: {},
      },
      child: { id: "test-child", name: "اختبار" },
      extraData: {
        rewardType: "task_completion",
        description: "اختبار - تشخيص الإيميل",
        coins: 5,
        rewardId: "diag-" + Date.now(),
        approvalToken: "test-approval",
        rejectionToken: "test-rejection",
        taskId: "test-task",
      },
    };
    const result = handleSendEventEmail_(testPayload);
    if (result.sent) {
      console.log(
        "✅✅ تم إرسال الإيميل التجريبي بنجاح! تحقق من صندوق البريد.",
      );
    } else {
      console.warn("⚠️ الإيميل لم يُرسل - النتيجة: " + JSON.stringify(result));
    }
  } catch (e) {
    console.error("❌ خطأ أثناء إرسال الإيميل التجريبي: " + e.message);
  }
  console.log("=== انتهى التشخيص ===");
}

function handleAction_(action, payload) {
  console.log("handleAction_: " + action);
  switch (action) {
    case "sync_user_profile":
      return handleSyncUserProfile_(payload);
    case "request_verification_code":
      return handleRequestVerificationCode_(payload);
    case "verify_email_code":
      return handleVerifyEmailCode_(payload);
    case "request_password_reset_code":
      return handleRequestPasswordResetCode_(payload);
    case "verify_password_reset_code":
      return handleVerifyPasswordResetCode_(payload);
    case "complete_password_reset":
      return handleCompletePasswordReset_(payload);
    case "send_event_email":
      return handleSendEventEmail_(payload);
    case "sync_child_profile":
      return handleSyncChildProfile_(payload);
    case "sync_behavior_config":
      return handleSyncBehaviorConfig_(payload);
    case "sync_daily_progress_history":
      return handleSyncDailyProgressHistory_(payload);
    case "send_scheduled_report_test_email":
      return handleSendScheduledReportTestEmail_(payload);
    case "send_completed_tasks_report_pipeline_test":
      return handleSendCompletedTasksReportPipelineTest_(payload);
    case "delete_child_now":
      return handleChildDelete_(payload);
    case "enqueue_operation":
      return handleEnqueueOperation_(payload);
    case "check_quota":
      return { quota: MailApp.getRemainingDailyQuota() };
    default:
      console.warn("Unknown action: " + action);
      throw new Error("الإجراء المطلوب غير معروف.");
  }
}

function sendScheduledDailyWarnings() {
  try {
    // معالجة العمليات المعلقة أولاً لضمان وجود أحدث البيانات (للمستخدمين الجدد أو المحذوفين)
    try {
      drainOperationsQueue_();
    } catch (e) {
      console.warn("فشل تفريغ طابور العمليات قبل التقرير اليومي: " + e.message);
    }

    const todayKey = dateKeyFor_(new Date());
    const reportKey = scheduledReportKey_("daily_warning", todayKey);
    const sentReportKeys = buildSentReportKeySet_("daily_warning");

    // 2. التنظيف التلقائي للمكافآت المعلقة مع حماية من التوقف
    try {
      cleanupPendingRewards_(todayKey);
    } catch (e) {
      console.error("فشل تنظيف المكافآت المعلقة: " + e.message);
    }

    const users = getSheetRecords_(SHEETS.users).filter(isUserReadyForEmails_);
    const children = getSheetRecords_(SHEETS.children);
    const behaviors = getSheetRecords_(SHEETS.behaviors);
    const progressRows = getSheetRecords_(SHEETS.dailyProgress).filter(
      (row) => stringValue_(row.date_key) === todayKey,
    );

    users.forEach((user) => {
      try {
        if (!boolValue_(user.daily_warnings_enabled, true)) {
          return;
        }
        if (
          wasScheduledReportSentFromSet_(sentReportKeys, user.uid, reportKey)
        ) {
          return;
        }

        const childrenForUser = children.filter(
          (child) => stringValue_(child.uid) === stringValue_(user.uid),
        );
        if (childrenForUser.length === 0) {
          return;
        }

        const sections = [];
        childrenForUser.forEach((child) => {
          const behavior = findBehaviorRecord_(
            behaviors,
            user.uid,
            child.child_id,
          );
          const progress = progressRows.find(
            (row) =>
              buildProgressKey_(row.uid, row.child_id, row.date_key) ===
              buildProgressKey_(user.uid, child.child_id, todayKey),
          );
          const expectedTasks = expectedTasksFromProgressOrBehavior_(
            progress,
            behavior,
          );
          if (expectedTasks.length === 0) {
            return;
          }
          const completedTaskIds = parseJsonArray_(
            progress && progress.completed_task_ids_json,
          );
          const missingTasks = expectedTasks.filter(
            (task) => completedTaskIds.indexOf(task.id) === -1,
          );
          if (missingTasks.length === 0) {
            return;
          }

          const totalTaskCount =
            progress && numberValue_(progress.total_task_count, 0) > 0
              ? numberValue_(progress.total_task_count, expectedTasks.length)
              : expectedTasks.length;
          const completedCount = Math.min(
            completedTaskIds.length,
            totalTaskCount,
          );
          sections.push({
            childName: child.child_name || "الطفل",
            completedCount: completedCount,
            totalTaskCount: totalTaskCount,
            missingTaskTitles: missingTasks.map((task) => task.title),
          });
        });

        if (sections.length === 0) {
          return;
        }

        const subject = "تنبيه نهاية اليوم من ريشة";
        try {
          sendEmail_({
            to: user.email,
            uid: user.uid,
            eventType: "daily_warning",
            subject: subject,
            htmlBody: buildDailyWarningHtml_(todayKey, sections),
            plainBody: buildDailyWarningText_(todayKey, sections),
            details: reportKey,
          });
          sentReportKeys[scheduledReportLogKey_(user.uid, reportKey)] = true;
        } catch (error) {
          logEmail_({
            uid: user.uid,
            email: user.email,
            eventType: "daily_warning",
            subject: subject,
            status: "failed",
            details: toErrorMessage_(error),
          });
        }
      } catch (e) {
        console.error(
          "خطأ أثناء معالجة التقرير اليومي للمستخدم " +
            user.uid +
            ": " +
            e.message,
        );
      }
    });
  } catch (e) {
    console.error("sendScheduledDailyWarnings error: " + e.message);
  }
}

function sendScheduledWeeklyStats() {
  try {
    // معالجة العمليات المعلقة أولاً لضمان وجود أحدث البيانات
    try {
      drainOperationsQueue_();
    } catch (e) {
      console.warn(
        "فشل تفريغ طابور العمليات قبل التقرير الأسبوعي: " + e.message,
      );
    }

    const users = getSheetRecords_(SHEETS.users).filter(isUserReadyForEmails_);
    const children = getSheetRecords_(SHEETS.children);
    const behaviors = getSheetRecords_(SHEETS.behaviors);
    const progressRows = getSheetRecords_(SHEETS.dailyProgress);
    const weekKeys = buildRecentDateKeys_(7);
    const weekReportKey = weekKeys[0] + ".." + weekKeys[weekKeys.length - 1];
    const reportKey = scheduledReportKey_("weekly_stats", weekReportKey);
    const sentReportKeys = buildSentReportKeySet_("weekly_stats");

    users.forEach((user) => {
      try {
        if (!boolValue_(user.weekly_stats_enabled, true)) {
          return;
        }
        if (
          wasScheduledReportSentFromSet_(sentReportKeys, user.uid, reportKey)
        ) {
          return;
        }

        const childrenForUser = children.filter(
          (child) => stringValue_(child.uid) === stringValue_(user.uid),
        );
        if (childrenForUser.length === 0) {
          return;
        }

        const childSummaries = [];
        childrenForUser.forEach((child) => {
          const behavior = findBehaviorRecord_(
            behaviors,
            user.uid,
            child.child_id,
          );
          const fallbackExpectedTasks = expectedTasksFromBehavior_(behavior);
          if (fallbackExpectedTasks.length === 0) {
            return;
          }

          const dailyLines = [];
          let totalExpected = 0;
          let totalCompleted = 0;

          weekKeys.forEach((dateKey) => {
            const progress = progressRows.find(
              (row) =>
                buildProgressKey_(row.uid, row.child_id, row.date_key) ===
                buildProgressKey_(user.uid, child.child_id, dateKey),
            );
            const completedTaskIds = parseJsonArray_(
              progress && progress.completed_task_ids_json,
            );
            const expectedTasks = expectedTasksFromProgressOrBehavior_(
              progress,
              behavior,
            );
            const expectedCount =
              progress && numberValue_(progress.total_task_count, 0) > 0
                ? numberValue_(progress.total_task_count, expectedTasks.length)
                : expectedTasks.length || fallbackExpectedTasks.length;
            const completedCount = Math.min(
              completedTaskIds.length,
              expectedCount,
            );

            totalExpected += expectedCount;
            totalCompleted += completedCount;
            dailyLines.push({
              dateKey: dateKey,
              completedCount: completedCount,
              expectedCount: expectedCount,
            });
          });

          childSummaries.push({
            childName: child.child_name || "الطفل",
            completionRate:
              totalExpected > 0
                ? Math.round((totalCompleted / totalExpected) * 100)
                : 0,
            totalCompleted: totalCompleted,
            totalExpected: totalExpected,
            dailyLines: dailyLines,
          });
        });

        if (childSummaries.length === 0) {
          return;
        }

        const subject = "الإحصائية الأسبوعية من ريشة";
        try {
          sendEmail_({
            to: user.email,
            uid: user.uid,
            eventType: "weekly_stats",
            subject: subject,
            htmlBody: buildWeeklyStatsHtml_(childSummaries),
            plainBody: buildWeeklyStatsText_(childSummaries),
            details: reportKey,
          });
          sentReportKeys[scheduledReportLogKey_(user.uid, reportKey)] = true;
        } catch (error) {
          logEmail_({
            uid: user.uid,
            email: user.email,
            eventType: "weekly_stats",
            subject: subject,
            status: "failed",
            details: toErrorMessage_(error),
          });
        }
      } catch (e) {
        console.error(
          "خطأ أثناء معالجة التقرير الأسبوعي للمستخدم " +
            user.uid +
            ": " +
            e.message,
        );
      }
    });
  } catch (e) {
    console.error("sendScheduledWeeklyStats error: " + e.message);
  }
}

function handleSendScheduledReportTestEmail_(payload) {
  const email = normalizeEmail_(payload.email);
  if (!isValidEmail_(email)) {
    throw new Error("Invalid test email.");
  }

  const now = new Date();
  const todayKey = dateKeyFor_(now);
  const weekKeys = buildRecentDateKeys_(7);
  const uid = "test-report:" + email;
  const dailySections = buildRandomDailyReportSections_();
  const weeklySummaries = buildRandomWeeklyReportSummaries_(weekKeys);
  const testRunKey = "test::" + now.getTime() + "::" + randomInt_(1000, 9999);

  sendEmail_({
    to: email,
    uid: uid,
    eventType: "daily_warning_test",
    subject: "[TEST] تقرير نهاية اليوم من ريشة - " + testRunKey,
    htmlBody: buildDailyWarningHtml_(todayKey, dailySections),
    plainBody: buildDailyWarningText_(todayKey, dailySections),
    details: testRunKey + "::daily",
  });

  sendEmail_({
    to: email,
    uid: uid,
    eventType: "weekly_stats_test",
    subject: "[TEST] الإحصائية الأسبوعية من ريشة - " + testRunKey,
    htmlBody: buildWeeklyStatsHtml_(weeklySummaries),
    plainBody: buildWeeklyStatsText_(weeklySummaries),
    details: testRunKey + "::weekly",
  });

  return {
    sent: true,
    email: email,
    dailySections: dailySections.length,
    weeklySummaries: weeklySummaries.length,
    testRunKey: testRunKey,
  };
}

function testScheduledReportEmail_Manual() {
  const email = "basemmunassar@gmail.com";
  return handleSendScheduledReportTestEmail_({ email: email });
}

function handleSendCompletedTasksReportPipelineTest_(payload) {
  const email = normalizeEmail_(payload.email);
  if (!isValidEmail_(email)) {
    throw new Error("Invalid test email.");
  }

  const now = new Date();
  const weekKeys = buildRecentDateKeys_(7);
  const testRunKey =
    "completed-pipeline::" + now.getTime() + "::" + randomInt_(1000, 9999);
  const uid = "test-completed-report:" + email;
  const childId = "completed-child-" + now.getTime();
  const taskIds = Object.keys(TRACKED_TASKS).map(
    (behaviorId) => TRACKED_TASKS[behaviorId].id,
  );
  const taskTitlesById = {};
  Object.keys(TRACKED_TASKS).forEach((behaviorId) => {
    const task = TRACKED_TASKS[behaviorId];
    taskTitlesById[task.id] = task.title;
  });
  const user = {
    uid: uid,
    email: email,
    weekly_stats_enabled: true,
    notifications_enabled: true,
  };
  const childrenForUser = [
    {
      uid: uid,
      child_id: childId,
      child_name: "اختبار إنجاز كامل " + randomInt_(100, 999),
    },
  ];
  const behaviors = [
    {
      uid: uid,
      child_id: childId,
      selected_behavior_ids_json: JSON.stringify(Object.keys(TRACKED_TASKS)),
    },
  ];
  const progressRows = weekKeys.map((dateKey) => {
    return {
      uid: uid,
      child_id: childId,
      date_key: dateKey,
      completed_task_ids_json: JSON.stringify(taskIds),
      total_task_count: taskIds.length,
      planned_task_ids_json: JSON.stringify(taskIds),
      planned_task_titles_json: JSON.stringify(taskTitlesById),
    };
  });
  const childSummaries = buildWeeklyStatsSummariesForUser_({
    user: user,
    childrenForUser: childrenForUser,
    behaviors: behaviors,
    progressRows: progressRows,
    weekKeys: weekKeys,
  });
  if (childSummaries.length === 0) {
    throw new Error("Completed task aggregation produced no summaries.");
  }

  const summary = childSummaries[0];
  if (
    summary.completionRate !== 100 ||
    summary.totalCompleted !== summary.totalExpected
  ) {
    throw new Error(
      "Completed task aggregation failed: " +
        JSON.stringify({
          completionRate: summary.completionRate,
          totalCompleted: summary.totalCompleted,
          totalExpected: summary.totalExpected,
        }),
    );
  }

  sendEmail_({
    to: email,
    uid: uid,
    eventType: "weekly_stats_completed_pipeline_test",
    subject: "[TEST] فحص تجميع إنجاز كامل - " + testRunKey,
    htmlBody: buildWeeklyStatsHtml_(childSummaries),
    plainBody: buildWeeklyStatsText_(childSummaries),
    details: testRunKey,
  });

  return {
    sent: true,
    email: email,
    completionRate: summary.completionRate,
    totalCompleted: summary.totalCompleted,
    totalExpected: summary.totalExpected,
    childSummaries: childSummaries.length,
    testRunKey: testRunKey,
  };
}

function handleSyncUserProfile_(payload) {
  const user = normalizeUser_(payload.user || payload);
  upsertUserRecord_(user, {});
  return { synced: true };
}

function handleRequestVerificationCode_(payload) {
  const user = normalizeUser_(payload.user || payload);
  const verificationRecord = findVerificationRecord_(user.uid, user.email);
  const now = new Date();
  const lastSentAt = parseIsoDate_(
    verificationRecord && verificationRecord.last_sent_at_iso,
  );

  if (lastSentAt) {
    const elapsedSeconds = Math.floor(
      (now.getTime() - lastSentAt.getTime()) / 1000,
    );
    const remainingCooldown =
      CONFIG.verificationCooldownSeconds - elapsedSeconds;
    if (remainingCooldown > 0) {
      return {
        sent: false,
        message: "تم إرسال رمز قريبًا. انتظر قليلًا ثم أعد المحاولة.",
        cooldownSeconds: remainingCooldown,
      };
    }
  }

  const code = generateVerificationCode_();
  const expiresAt = new Date(
    now.getTime() + CONFIG.verificationExpiryMinutes * 60 * 1000,
  );
  const previousVerificationRecord = verificationRecord
    ? Object.assign({}, verificationRecord)
    : null;
  upsertVerificationRecord_({
    uid: user.uid,
    email: user.email,
    codeHash: hashValue_(code),
    expiresAtIso: expiresAt.toISOString(),
    lastSentAtIso: now.toISOString(),
    verifiedAtIso: "",
  });
  upsertUserRecord_(user, {});

  const timeString = Utilities.formatDate(
    now,
    CONFIG.timeZone || "GMT",
    "HH:mm:ss",
  );
  try {
    sendEmail_({
      to: user.email,
      uid: user.uid,
      eventType: "verification_code",
      subject: "رمز التحقق لحساب ريشة - " + timeString,
      htmlBody: buildVerificationEmailHtml_(code, expiresAt),
      plainBody: [
        "رمز التحقق الخاص بحساب ريشة:",
        code,
        "",
        "تنتهي صلاحية الرمز بعد 15 دقيقة.",
      ].join("\n"),
    });
  } catch (error) {
    restoreVerificationRecordAfterFailedEmail_(
      previousVerificationRecord,
      user.uid,
      user.email,
    );
    throw error;
  }

  return {
    sent: true,
    message: "تم إرسال رمز التحقق إلى بريدك الإلكتروني.",
    cooldownSeconds: CONFIG.verificationCooldownSeconds,
    sentAtIso: now.toISOString(),
    expiresAtIso: expiresAt.toISOString(),
  };
}

function handleVerifyEmailCode_(payload) {
  const user = normalizeUser_(payload.user || payload);
  const code = stringValue_(payload.code);
  if (!/^\d{6}$/.test(code)) {
    throw new Error("رمز التحقق يجب أن يتكون من 6 أرقام.");
  }

  const verificationRecord = findVerificationRecord_(user.uid, user.email);
  if (!verificationRecord) {
    throw new Error("لا يوجد رمز تحقق نشط لهذا الحساب.");
  }

  const alreadyVerifiedAt = parseIsoDate_(verificationRecord.verified_at_iso);
  if (alreadyVerifiedAt) {
    const existingUserRecord = upsertUserRecord_(user, {
      emailVerified: true,
      updatedAtIso: isoNow_(),
    });
    return {
      verified: true,
      message: "تم التحقق من البريد مسبقًا.",
      verifiedAtIso: alreadyVerifiedAt.toISOString(),
      welcomeSentAtIso: stringValue_(existingUserRecord.welcome_sent_at_iso),
    };
  }

  const expiresAt = parseIsoDate_(verificationRecord.expires_at_iso);
  if (!expiresAt || expiresAt.getTime() < Date.now()) {
    throw new Error("انتهت صلاحية الرمز. اطلب رمزًا جديدًا.");
  }

  if (hashValue_(code) !== stringValue_(verificationRecord.code_hash)) {
    throw new Error("رمز التحقق غير صحيح.");
  }

  const nowIso = isoNow_();
  upsertVerificationRecord_({
    uid: user.uid,
    email: user.email,
    codeHash: stringValue_(verificationRecord.code_hash),
    expiresAtIso: stringValue_(verificationRecord.expires_at_iso),
    lastSentAtIso: stringValue_(verificationRecord.last_sent_at_iso),
    verifiedAtIso: nowIso,
  });

  const currentUserRecord = upsertUserRecord_(user, {
    emailVerified: true,
    updatedAtIso: nowIso,
  });

  let welcomeSentAtIso = stringValue_(currentUserRecord.welcome_sent_at_iso);
  if (
    !welcomeSentAtIso &&
    boolValue_(currentUserRecord.welcome_guide_enabled, true)
  ) {
    sendEmail_({
      to: user.email,
      uid: user.uid,
      eventType: "welcome_guide",
      subject: "مرحبًا بك في ريشة",
      htmlBody: buildWelcomeEmailHtml_(),
      plainBody: [
        "مرحبًا بك في ريشة.",
        "ابدأ الآن بإضافة الطفل ثم اختيار السلوكيات اليومية وضبطها داخل التطبيق.",
        "ستصلك التنبيهات والإحصائيات الأسبوعية تلقائيًا على هذا البريد.",
      ].join("\n"),
    });
    welcomeSentAtIso = nowIso;
    upsertUserRecord_(user, {
      emailVerified: true,
      welcomeSentAtIso: welcomeSentAtIso,
      updatedAtIso: nowIso,
    });
  }

  return {
    verified: true,
    message: "تم التحقق من البريد بنجاح.",
    verifiedAtIso: nowIso,
    welcomeSentAtIso: welcomeSentAtIso,
  };
}

function handleRequestPasswordResetCode_(payload) {
  const email = normalizeEmail_(payload.email);
  if (!email) {
    throw new Error("أدخل البريد الإلكتروني أولًا.");
  }

  const authUser = requireFirebaseAuthUserByEmail_(email);
  const resetRecord = findPasswordResetRecord_(authUser.localId, email);
  const now = new Date();
  const lastSentAt = parseIsoDate_(resetRecord && resetRecord.last_sent_at_iso);

  if (lastSentAt) {
    const elapsedSeconds = Math.floor(
      (now.getTime() - lastSentAt.getTime()) / 1000,
    );
    const remainingCooldown =
      CONFIG.verificationCooldownSeconds - elapsedSeconds;
    if (remainingCooldown > 0) {
      return {
        sent: false,
        message: "تم إرسال رمز قريبًا. انتظر قليلًا ثم أعد المحاولة.",
        cooldownSeconds: remainingCooldown,
      };
    }
  }

  const code = generateVerificationCode_();
  const expiresAt = new Date(
    now.getTime() + CONFIG.verificationExpiryMinutes * 60 * 1000,
  );
  const previousPasswordResetRecord = resetRecord
    ? Object.assign({}, resetRecord)
    : null;

  upsertPasswordResetRecord_({
    uid: authUser.localId,
    email: email,
    codeHash: hashValue_(code),
    expiresAtIso: expiresAt.toISOString(),
    lastSentAtIso: now.toISOString(),
    verifiedAtIso: "",
    usedAtIso: "",
  });

  try {
    sendEmail_({
      to: email,
      uid: authUser.localId,
      eventType: "password_reset_code",
      subject: "رمز إعادة تعيين كلمة المرور في ريشة",
      htmlBody: buildPasswordResetCodeEmailHtml_(code, expiresAt),
      plainBody: [
        "رمز إعادة تعيين كلمة المرور في ريشة:",
        code,
        "",
        "تنتهي صلاحية الرمز بعد 15 دقيقة.",
      ].join("\n"),
    });
  } catch (error) {
    restorePasswordResetRecordAfterFailedEmail_(
      previousPasswordResetRecord,
      authUser.localId,
      email,
    );
    throw error;
  }

  return {
    sent: true,
    message: "تم إرسال رمز إعادة التعيين إلى بريدك الإلكتروني.",
    cooldownSeconds: CONFIG.verificationCooldownSeconds,
    sentAtIso: now.toISOString(),
    expiresAtIso: expiresAt.toISOString(),
  };
}

function handleVerifyPasswordResetCode_(payload) {
  const email = normalizeEmail_(payload.email);
  const code = stringValue_(payload.code);

  if (!email) {
    throw new Error("أدخل البريد الإلكتروني أولًا.");
  }
  validateSixDigitCode_(code, "رمز إعادة التعيين");

  const authUser = requireFirebaseAuthUserByEmail_(email);
  const resetRecord = requireUsablePasswordResetRecord_(
    authUser.localId,
    email,
    code,
  );
  const nowIso = isoNow_();

  upsertPasswordResetRecord_({
    uid: authUser.localId,
    email: email,
    codeHash: stringValue_(resetRecord.code_hash),
    expiresAtIso: stringValue_(resetRecord.expires_at_iso),
    lastSentAtIso: stringValue_(resetRecord.last_sent_at_iso),
    verifiedAtIso: nowIso,
    usedAtIso: stringValue_(resetRecord.used_at_iso),
  });

  return {
    verified: true,
    message: "تم التحقق من رمز إعادة التعيين بنجاح.",
    verifiedAtIso: nowIso,
  };
}

function handleCompletePasswordReset_(payload) {
  const email = normalizeEmail_(payload.email);
  const code = stringValue_(payload.code);
  const newPassword = stringValue_(payload.newPassword);

  if (!email) {
    throw new Error("أدخل البريد الإلكتروني أولًا.");
  }
  validateSixDigitCode_(code, "رمز إعادة التعيين");
  validateNewPassword_(newPassword);

  const authUser = requireFirebaseAuthUserByEmail_(email);
  const resetRecord = requireUsablePasswordResetRecord_(
    authUser.localId,
    email,
    code,
  );
  updateFirebaseAuthPassword_(authUser.localId, newPassword);

  const nowIso = isoNow_();
  upsertPasswordResetRecord_({
    uid: authUser.localId,
    email: email,
    codeHash: stringValue_(resetRecord.code_hash),
    expiresAtIso: stringValue_(resetRecord.expires_at_iso),
    lastSentAtIso: stringValue_(resetRecord.last_sent_at_iso),
    verifiedAtIso: stringValue_(resetRecord.verified_at_iso) || nowIso,
    usedAtIso: nowIso,
  });

  sendEmail_({
    to: email,
    uid: authUser.localId,
    eventType: "password_reset_completed",
    subject: "تم تغيير كلمة المرور في ريشة",
    htmlBody: buildPasswordResetCompletedEmailHtml_(),
    plainBody: [
      "تم تغيير كلمة المرور الخاصة بحسابك في ريشة بنجاح.",
      "إذا لم تكن أنت من نفّذ هذه العملية، غيّر كلمة المرور مرة أخرى فورًا.",
    ].join("\n"),
  });

  return {
    reset: true,
    message: "تم تحديث كلمة المرور بنجاح.",
    completedAtIso: nowIso,
  };
}

function handleSendEventEmail_(payload) {
  const user = normalizeUser_(payload.user || payload);
  const eventType = stringValue_(payload.eventType);
  const child = normalizeChild_(payload.child || {});
  const userRecord = upsertUserRecord_(user, {
    lastLoginAtIso: eventType === "login" ? isoNow_() : "",
    updatedAtIso: isoNow_(),
  });

  // pending_reward emails MUST always be sent —  they are approval requests
  // that do not require email_verified or child_activity_enabled flags.
  const isPendingReward = eventType === "pending_reward";

  if (!isPendingReward && !isUserReadyForEmails_(userRecord)) {
    console.warn(
      "Email SKIPPED [not_ready]: uid=" +
        user.uid +
        " email=" +
        user.email +
        " notifications_enabled=" +
        userRecord.notifications_enabled +
        " email_verified=" +
        userRecord.email_verified,
    );
    return { sent: false, skipped: true };
  }
  // For pending_reward, we still need a valid email address
  if (isPendingReward && !stringValue_(userRecord.email)) {
    console.warn("Email SKIPPED [no_email]: uid=" + user.uid);
    return { sent: false, skipped: true };
  }
  if (eventType === "login" && !boolValue_(userRecord.login_enabled, true)) {
    return { sent: false, skipped: true };
  }
  if (
    !isPendingReward &&
    eventType !== "login" &&
    !boolValue_(userRecord.child_activity_enabled, true)
  ) {
    return { sent: false, skipped: true };
  }

  if (child.id) {
    upsertChildRecord_(userRecord, child);
  }

  // Fix: Deduplication - skip if same event was sent recently (5 min cooldown)
  try {
    const childId = child.id ? stringValue_(child.id) : "";
    const dedupKey = eventType + "::" + userRecord.uid + "::" + childId;
    if (
      wasEventEmailRecentlySent_(userRecord.uid, eventType, childId, 300000)
    ) {
      console.warn(
        "Email SKIPPED [dedup]: " +
          dedupKey +
          " was sent within last 5 minutes.",
      );
      return { sent: false, skipped: true, reason: "dedup" };
    }
  } catch (dedupError) {
    // Dedup check failure must never block email sending
    console.warn(
      "Dedup check failed (proceeding with send): " + dedupError.message,
    );
  }

  console.log("Sending email [" + eventType + "] to: " + userRecord.email);
  const eventTemplate = eventTemplateFor_(eventType, child, payload, user);
  sendEmail_({
    to: userRecord.email,
    uid: userRecord.uid,
    eventType: eventType,
    subject: eventTemplate.subject,
    htmlBody: eventTemplate.htmlBody,
    plainBody: eventTemplate.plainBody,
    details: child.id ? stringValue_(child.id) : "",
  });

  return { sent: true };
}

function handleSyncChildProfile_(payload) {
  console.log("handleSyncChildProfile_ payload: " + JSON.stringify(payload));
  const user = normalizeUser_(payload.user || payload);
  const child = normalizeChild_(payload.child || {});

  if (!user.uid || !user.email) {
    throw new Error("بيانات ولي الأمر غير مكتملة لمزامنة الطفل.");
  }
  if (!child.id || !child.name) {
    throw new Error("بيانات الطفل غير مكتملة.");
  }

  // 1. مسح أي عمليات معلقة لهذا الطفل في الطابور لمنع التكرار (Ghost Requests)
  try {
    dropPendingSyncOperationsForChild_(user.uid, child.id);
  } catch (e) {
    console.warn("Could not drop pending operations: " + e.message);
  }

  console.log(
    "Syncing child profile: " + child.name + " for user: " + user.email,
  );
  const userRecord = upsertUserRecord_(user, {
    updatedAtIso: isoNow_(),
  });

  // Guard against stale sync requests resurrecting a deleted child.
  const archivedChildRecord = readSheetRecord_(SHEETS.childrenArchive, {
    uid: userRecord.uid,
    child_id: child.id,
  });
  const activeChildRecord = readSheetRecord_(SHEETS.children, {
    uid: userRecord.uid,
    child_id: child.id,
  });
  if (archivedChildRecord && !activeChildRecord) {
    console.warn(
      "Skipping stale child sync for archived child. uid=" +
        userRecord.uid +
        " child_id=" +
        child.id,
    );
    return {
      synced: false,
      skippedArchivedChild: true,
      uid: userRecord.uid,
      child_id: child.id,
    };
  }

  // 2. فحص وجود الطفل مسبقاً لمنع التكرار في الشيت
  const existing = activeChildRecord || {};

  const childRecord = upsertSheetRecord_(SHEETS.children, ["uid", "child_id"], {
    uid: userRecord.uid,
    child_id: child.id,
    child_name: child.name || stringValue_(existing.child_name) || "الطفل",
    age_years: numberValue_(
      child.ageYears,
      numberValue_(existing.age_years, 0),
    ),
    avatar_present: boolValue_(
      child.hasAvatar,
      boolValue_(existing.avatar_present, false),
    ),
    updated_at_iso: isoNow_(),
  });

  // إنشاء إعدادات سلوك افتراضية فوراً لضمان ظهور الطفل في التقارير والإحصائيات
  console.log("Creating/Updating behavior config for: " + child.name);
  upsertBehaviorRecord_(userRecord, child.id, {
    selectedBehaviorIds: [],
    customBehaviors: [],
    waterCupsCount: 8,
    sportSessionsCount: 1,
    sportLightActivityEnabled: true,
    sportSessionTimes: [],
    sleepHour: 20,
    sleepMinute: 0,
    sleepNotificationsEnabled: true,
  });

  return {
    synced: true,
    uid: userRecord.uid,
    child_id: childRecord.child_id,
  };
}

function handleSyncBehaviorConfig_(payload) {
  const user = normalizeUser_(payload.user || payload);
  const child = normalizeChild_(payload.child || {});
  if (!child.id) {
    throw new Error("معرف الطفل مطلوب لحفظ إعدادات السلوكيات.");
  }

  const userRecord = upsertUserRecord_(user, {});
  if (child.name) {
    upsertChildRecord_(userRecord, child);
  }
  upsertBehaviorRecord_(
    userRecord,
    child.id,
    asObject_(payload.behaviorConfig),
  );
  return { synced: true };
}

function handleSyncDailyProgressHistory_(payload) {
  const user = normalizeUser_(payload.user || payload);
  const child = normalizeChild_(payload.child || {});
  const history = Array.isArray(payload.history) ? payload.history : [];
  if (!child.id) {
    throw new Error("معرف الطفل مطلوب لحفظ التقدم اليومي.");
  }
  if (history.length === 0) {
    return { synced: true };
  }

  const userRecord = upsertUserRecord_(user, {});
  if (child.name) {
    upsertChildRecord_(userRecord, child);
  }

  history.forEach((entry) => {
    const dateKey = stringValue_(entry.dateKey);
    if (!dateKey) {
      return;
    }
    upsertDailyProgressRecord_(
      userRecord,
      child.id,
      dateKey,
      asObject_(entry.progress),
    );
  });

  return { synced: true };
}

function handleEnqueueOperation_(payload) {
  const operationId = stringValue_(payload.operationId);
  const operationType = stringValue_(payload.operationType);
  const uid = stringValue_(payload.uid);
  const childId = stringValue_(payload.childId);
  const operationPayload = asObject_(payload.payload);
  const payloadJson = JSON.stringify(operationPayload);
  if (!operationId || !operationType || !uid) {
    throw new Error("معرف العملية، نوع العملية، ومعرف المستخدم مطلوبة.");
  }
  const existingOperation = findSheetRecords_(SHEETS.operationsQueue, {
    operation_id: operationId,
  })[0];
  if (existingOperation) {
    const existingStatus = stringValue_(existingOperation.status).toLowerCase();
    // Fix: If already completed or already pending, skip to prevent duplicates
    if (
      existingStatus === "completed" &&
      isImmutableQueueOperation_(operationType)
    ) {
      return {
        enqueued: true,
        operationId: operationId,
        alreadyCompleted: true,
      };
    }
    if (existingStatus === "pending") {
      console.warn("Enqueue SKIPPED [already_pending]: " + operationId);
      return {
        enqueued: true,
        operationId: operationId,
        alreadyPending: true,
      };
    }
  }

  // Fix: For child_activity_email, check if a pending operation of same type+uid+child exists
  if (operationType === "child_activity_email") {
    try {
      const pendingDuplicates = getSheetRecords_(SHEETS.operationsQueue).filter(
        function (r) {
          return (
            stringValue_(r.operation_type) === "child_activity_email" &&
            stringValue_(r.uid) === uid &&
            stringValue_(r.child_id) === childId &&
            (stringValue_(r.status).toLowerCase() === "pending" ||
              stringValue_(r.status) === "")
          );
        },
      );
      // Check payload eventType to match same event
      const newEventType = stringValue_(operationPayload.eventType);
      const hasSameEventPending = pendingDuplicates.some(function (r) {
        try {
          const existingPayload = parseJsonObject_(r.payload_json);
          return stringValue_(existingPayload.eventType) === newEventType;
        } catch (_) {
          return false;
        }
      });
      if (hasSameEventPending) {
        console.warn(
          "Enqueue SKIPPED [duplicate_event_pending]: type=" +
            newEventType +
            " uid=" +
            uid +
            " child=" +
            childId,
        );
        return {
          enqueued: true,
          operationId: operationId,
          alreadyPending: true,
        };
      }
    } catch (dedupErr) {
      // Dedup check failure must not block enqueueing
      console.warn(
        "child_activity_email dedup check failed: " + dedupErr.message,
      );
    }
  }

  upsertSheetRecord_(SHEETS.operationsQueue, ["operation_id"], {
    operation_id: operationId,
    operation_type: operationType,
    uid: uid,
    child_id: childId || "",
    payload_json: payloadJson,
    status: "pending",
    attempt_count: 0,
    next_attempt_at_iso: "",
    last_error: "",
    received_at_iso: isoNow_(),
    processed_at_iso: "",
  });
  return {
    enqueued: true,
    operationId: operationId,
    processedImmediately: tryProcessAcceptedOperationImmediately_(
      operationId,
      operationType,
    ),
  };
}

function isImmutableQueueOperation_(operationType) {
  const type = stringValue_(operationType);
  return type === "pending_reward_email" || type === "child_activity_email";
}

function shouldProcessOperationImmediately_(operationType) {
  const type = stringValue_(operationType);
  return (
    type === "pending_reward_email" ||
    type === "child_activity_email" ||
    type === "child_profile_sync"
  );
}

function tryProcessAcceptedOperationImmediately_(operationId, operationType) {
  if (!shouldProcessOperationImmediately_(operationType)) {
    return false;
  }
  try {
    // الانتظار قليلاً لضمان كتابة السجل في الشيت (بسبب تأخر Google Sheets أحياناً)
    Utilities.sleep(800);

    const record = findSheetRecords_(SHEETS.operationsQueue, {
      operation_id: operationId,
    })[0];

    if (!record) {
      console.warn(
        "tryProcessAcceptedOperationImmediately_: Record not found for ID: " +
          operationId,
      );
      return false;
    }

    const queuePayload = parseJsonObject_(record.payload_json);

    // تنفيذ العملية
    handleOperation_(stringValue_(record.operation_type), {
      ...queuePayload,
      uid: stringValue_(record.uid),
      childId: stringValue_(record.child_id),
    });

    // تحديث الحالة إلى مكتملة
    upsertSheetRecord_(SHEETS.operationsQueue, ["operation_id"], {
      operation_id: stringValue_(record.operation_id),
      status: "completed",
      processed_at_iso: isoNow_(),
    });

    return true;
  } catch (error) {
    console.error(
      "Immediate queue processing failed for " +
        operationId +
        ": " +
        error.message,
    );

    // تسجيل الفشل في لوق الإيميلات للمساعدة في التشخيص
    if (operationType === "child_delete") {
      logEmail_({
        uid: "SYSTEM",
        email: "sync-error@risha.app",
        eventType: "child_delete_sync_error",
        subject: "فشل حذف طفل فوراً: " + operationId,
        status: "failed",
        details: error.message,
      });
    }

    return false;
  }
}

function buildVerificationEmailHtml_(code, expiresAt) {
  const expirationLabel = Utilities.formatDate(
    expiresAt,
    CONFIG.timeZone,
    "hh:mm a",
  );
  return wrapEmailHtml_(
    "رمز التحقق",
    [
      "<p>استخدم الرمز التالي لتأكيد بريدك الإلكتروني في ريشة:</p>",
      '<div style="font-size:34px;font-weight:700;letter-spacing:8px;text-align:center;background:#f6efe1;padding:18px;border-radius:16px;">' +
        escapeHtml_(code) +
        "</div>",
      "<p>تنتهي صلاحية الرمز عند " + escapeHtml_(expirationLabel) + ".</p>",
      "<p>إذا لم تطلب هذا الرمز، تجاهل هذه الرسالة.</p>",
    ].join(""),
  );
}

function buildPasswordResetCodeEmailHtml_(code, expiresAt) {
  const expirationLabel = Utilities.formatDate(
    expiresAt,
    CONFIG.timeZone,
    "hh:mm a",
  );
  return wrapEmailHtml_(
    "رمز إعادة تعيين كلمة المرور",
    [
      "<p>استخدم الرمز التالي لإكمال إعادة تعيين كلمة المرور في ريشة:</p>",
      '<div style="font-size:34px;font-weight:700;letter-spacing:8px;text-align:center;background:#f6efe1;padding:18px;border-radius:16px;">' +
        escapeHtml_(code) +
        "</div>",
      "<p>تنتهي صلاحية الرمز عند " + escapeHtml_(expirationLabel) + ".</p>",
      "<p>بعد التحقق من الرمز داخل التطبيق ستنتقل إلى شاشة كلمة المرور الجديدة.</p>",
    ].join(""),
  );
}

function buildPasswordResetCompletedEmailHtml_() {
  return wrapEmailHtml_(
    "تم تغيير كلمة المرور",
    [
      "<p>تم تحديث كلمة المرور الخاصة بحسابك في ريشة بنجاح.</p>",
      "<p>إذا لم تكن أنت من نفّذ هذه العملية، أعِد تغيير كلمة المرور فورًا وتحقق من أمان بريدك الإلكتروني.</p>",
    ].join(""),
  );
}

function buildWelcomeEmailHtml_() {
  return wrapEmailHtml_(
    "مرحبًا بك في ريشة",
    [
      "<p>اكتمل تفعيل حسابك بنجاح.</p>",
      "<p>ابدأ الآن بهذه الخطوات:</p>",
      '<ol style="padding-right:18px;">',
      "<li>أضف ملف الطفل.</li>",
      "<li>اختر السلوكيات اليومية المناسبة.</li>",
      "<li>اضبط أوقات النوم والماء والنشاط.</li>",
      "<li>تابع الإحصائيات والتنبيهات من بريدك.</li>",
      "</ol>",
      "<p>نتمنى لك تجربة موفقة مع ريشة.</p>",
    ].join(""),
  );
}

function eventTemplateFor_(eventType, child, payload, user) {
  const childName = child.name || "الطفل";
  const extraData = payload && payload.extraData ? payload.extraData : {};
  const rewardDescription =
    stringValue_(extraData.description) || "طلب مكافأة جديدة";
  const rewardCoins = numberValue_(extraData.coins, 0);
  switch (eventType) {
    case "pending_reward": {
      const functionHost = getPendingRewardActionHost_();
      const rewardId = stringValue_(extraData.rewardId);
      const approvalToken = stringValue_(extraData.approvalToken);
      const rejectionToken = stringValue_(extraData.rejectionToken);
      const taskId = stringValue_(extraData.taskId);
      const childId = stringValue_(child.id);
      const userId = stringValue_(user?.uid || payload.user?.uid);
      const approveUrl = buildPendingRewardActionUrl_(
        functionHost,
        userId,
        childId,
        rewardId,
        approvalToken,
        "approve",
      );
      const rejectUrl = buildPendingRewardActionUrl_(
        functionHost,
        userId,
        childId,
        rewardId,
        rejectionToken,
        "reject",
      );

      const actionButtons =
        approveUrl && rejectUrl
          ? '<div style="text-align:center;margin:24px 0;">' +
            '<a href="' +
            escapeHtml_(approveUrl) +
            '" style="display:inline-block;margin:6px 8px;padding:14px 20px;background:#4caf50;color:#ffffff;text-decoration:none;border-radius:12px;font-weight:700;">قبول الطلب</a>' +
            '<a href="' +
            escapeHtml_(rejectUrl) +
            '" style="display:inline-block;margin:6px 8px;padding:14px 20px;background:#e53935;color:#ffffff;text-decoration:none;border-radius:12px;font-weight:700;">رفض الطلب</a>' +
            "</div>"
          : "<p>فتح البريد الإلكتروني في التطبيق أو تحقق من إعدادات ريشة.</p>";

      const plainActionLinks =
        approveUrl && rejectUrl
          ? ["رابط القبول: " + approveUrl, "رابط الرفض: " + rejectUrl].join(
              "\n",
            )
          : "راجع التطبيق لإكمال هذا الطلب.";

      return {
        subject: "طلب مكافأة جديدة في ريشة",
        htmlBody: wrapEmailHtml_(
          "طلب مكافأة جديدة",
          "<p>طلب الطفل <strong>" +
            escapeHtml_(childName) +
            "</strong> مكافأة جديدة.</p>" +
            "<p>المكافأة: <strong>" +
            escapeHtml_(rewardDescription) +
            "</strong></p>" +
            (taskId
              ? "<p>المهمة: <strong>" + escapeHtml_(taskId) + "</strong></p>"
              : "") +
            "<p>النقاط المطلوبة: <strong>" +
            rewardCoins +
            "</strong></p>" +
            "<p>اضغط أحد الأزرار التالية للاعتماد أو الرفض.</p>" +
            actionButtons,
        ),
        plainBody: [
          "طلب مكافأة جديدة",
          "الطفل: " + childName,
          "المكافأة: " + rewardDescription,
          taskId ? "المهمة: " + taskId : null,
          "النقاط: " + rewardCoins,
          "",
          "اضغط أحد الروابط التالية للاعتماد أو الرفض:",
          plainActionLinks,
        ]
          .filter(Boolean)
          .join("\n"),
      };
    }
    case "login":
      return {
        subject: "تم تسجيل الدخول إلى ريشة",
        htmlBody: wrapEmailHtml_(
          "تسجيل دخول جديد",
          "<p>تم تسجيل الدخول إلى حساب ريشة الخاص بك بنجاح.</p><p>إذا لم تكن أنت من قام بهذه العملية، غيّر كلمة المرور فورًا.</p>",
        ),
        plainBody: "تم تسجيل الدخول إلى حساب ريشة الخاص بك بنجاح.",
      };
    case "child_added":
      return {
        subject: "تمت إضافة طفل جديد في ريشة",
        htmlBody: wrapEmailHtml_(
          "إضافة طفل جديد",
          "<p>تمت إضافة الطفل <strong>" +
            escapeHtml_(childName) +
            "</strong> إلى حسابك في ريشة.</p>",
        ),
        plainBody: "تمت إضافة الطفل " + childName + " إلى حسابك في ريشة.",
      };
    case "child_updated":
      return {
        subject: "تم تحديث بيانات طفل في ريشة",
        htmlBody: wrapEmailHtml_(
          "تحديث بيانات الطفل",
          "<p>تم تحديث بيانات الطفل <strong>" +
            escapeHtml_(childName) +
            "</strong> في حسابك.</p>",
        ),
        plainBody: "تم تحديث بيانات الطفل " + childName + " في حسابك.",
      };
    case "child_switched":
      return {
        subject: "تم التبديل بين حسابات الأطفال في ريشة",
        htmlBody: wrapEmailHtml_(
          "تبديل حساب الطفل",
          "<p>تم فتح ملف الطفل <strong>" +
            escapeHtml_(childName) +
            "</strong> داخل التطبيق.</p>",
        ),
        plainBody: "تم فتح ملف الطفل " + childName + " داخل التطبيق.",
      };
    default:
      throw new Error("نوع البريد المطلوب غير معروف.");
  }
}

function buildPendingRewardActionUrl_(
  host,
  userId,
  childId,
  rewardId,
  token,
  decision,
) {
  if (!host || !userId || !childId || !rewardId || !token || !decision) {
    return "";
  }

  const params = [
    "action=pending_reward",
    "userId=" + encodeURIComponent(userId),
    "childId=" + encodeURIComponent(childId),
    "rewardId=" + encodeURIComponent(rewardId),
    "token=" + encodeURIComponent(token),
    "decision=" + encodeURIComponent(decision),
  ];

  return host + "?" + params.join("&");
}

function getPendingRewardActionHost_() {
  if (CONFIG.firebasePendingRewardActionHost) {
    return String(CONFIG.firebasePendingRewardActionHost).trim();
  }

  if (CONFIG.appsScriptWebAppUrl) {
    return String(CONFIG.appsScriptWebAppUrl).trim();
  }

  try {
    const url = ScriptApp.getService().getUrl();
    if (url && typeof url === "string" && url.trim()) {
      return url.trim();
    }
  } catch (error) {
    // Fall back to the configured Google Apps Script web app URL
  }

  return "";
}

function handlePendingRewardActionGet_(query) {
  const userId = stringValue_(query.userId);
  const childId = stringValue_(query.childId);
  const rewardId = stringValue_(query.rewardId);
  const token = stringValue_(query.token);
  const decision = stringValue_(query.decision).toLowerCase();

  const renderPendingRewardActionHtml_ = function (title, message, type) {
    if (typeof buildPendingRewardActionHtml_ === "function") {
      return buildPendingRewardActionHtml_(title, message, type);
    }

    const html = [
      "<!DOCTYPE html>",
      '<html lang="ar">',
      "<head>",
      '  <meta charset="UTF-8">',
      '  <meta name="viewport" content="width=device-width, initial-scale=1.0">',
      "  <title>" + escapeHtml_(title) + "</title>",
      "  <style>",
      "    body { font-family: Arial, sans-serif; direction: rtl; text-align: center; padding: 40px; background: #f7f5f2; color: #333; }",
      "    .card { display: inline-block; max-width: 520px; width: 100%; padding: 28px; border-radius: 18px; background: #ffffff; box-shadow: 0 20px 50px rgba(0,0,0,0.08); }",
      "    h1 { margin-bottom: 18px; font-size: 28px; }",
      "    p { font-size: 18px; line-height: 1.6; margin: 0; }",
      "  </style>",
      "</head>",
      "<body>",
      '  <div class="card">',
      "    <h1>" + escapeHtml_(title) + "</h1>",
      "    <p>" + escapeHtml_(message) + "</p>",
      "  </div>",
      "</body>",
      "</html>",
    ].join("");

    return HtmlService.createHtmlOutput(html).setXFrameOptionsMode(
      HtmlService.XFrameOptionsMode.ALLOWALL,
    );
  };

  if (!userId || !childId || !rewardId || !token || !decision) {
    return renderPendingRewardActionHtml_(
      "رابط غير صالح",
      "تعذر معالجة الرابط. تأكد من استخدام الرابط الكامل المرسل إلى بريدك الإلكتروني.",
      "error",
    );
  }
  if (decision !== "approve" && decision !== "reject") {
    return renderPendingRewardActionHtml_(
      "خيار غير صالح",
      'قرار الطلب غير معروف. يجب أن يكون "approve" أو "reject".',
      "error",
    );
  }

  let childDocument;
  const docPath = firestoreDocumentPath_("users", userId, "children", childId);
  try {
    childDocument = getFirestoreDocument_(docPath);
    if (!childDocument) {
      console.error("Child document not found at path: " + docPath);
    }
  } catch (error) {
    const logInfo =
      "Project: " + CONFIG.firebaseProjectId + " | Path: " + docPath;
    console.error("Firestore error: " + error.message + " | " + logInfo);
    let errorMsg = error.message || "حاول مرة أخرى لاحقًا.";
    if (errorMsg.indexOf("403") !== -1) {
      errorMsg =
        "خطأ 403: صلاحيات غير كافية. يرجى تفعيل Firestore API في مشروع Google Cloud والتأكد من ربط المشروع برقم المشروع الصحيح، ثم تشغيل دالة testFirestoreConnection يدوياً في المحرر لمنح الصلاحيات.";
    }
    return renderPendingRewardActionHtml_(
      "تعذر الوصول إلى قاعدة البيانات",
      "فشل الاتصال بخدمة قاعدة البيانات.\n\n" +
        logInfo +
        "\n\nالتفاصيل: " +
        errorMsg,
      "error",
    );
  }

  if (!childDocument) {
    const logInfo =
      "Project: " + CONFIG.firebaseProjectId + " | Path: " + docPath;
    console.warn("Child NOT FOUND: " + logInfo);
    return renderPendingRewardActionHtml_(
      "الطفل غير موجود",
      "تعذر العثور على بيانات الطفل المطلوب.\n\n" +
        logInfo +
        "\n\nتأكد من أن الحساب مرتبط بهذا الطفل ومن أن معرف المشروع صحيح.",
      "error",
    );
  }

  const walletData = firestoreDocumentToJs(childDocument);
  const pendingRewards = Array.isArray(walletData.pendingRewards)
    ? walletData.pendingRewards
    : [];
  const rewardIndex = pendingRewards.findIndex(
    (item) => stringValue_(item?.id) === rewardId,
  );

  if (rewardIndex === -1) {
    return renderPendingRewardActionHtml_(
      "المكافأة غير موجودة",
      "لم يتم العثور على طلب المكافأة. ربما تم حذفه أو أن الرابط غير صالح.",
      "error",
    );
  }

  const reward = pendingRewards[rewardIndex] || {};
  const currentStatus = stringValue_(reward.status);
  if (currentStatus !== "pending") {
    return renderPendingRewardActionHtml_(
      "تمت معالجة الطلب",
      "تم بالفعل " +
        (currentStatus === "approved" ? "الموافقة على" : "الرفض") +
        " هذا الطلب.",
      currentStatus === "approved" ? "happy" : "tired",
    );
  }

  const expectedToken = stringValue_(
    decision === "approve" ? reward.approvalToken : reward.rejectionToken,
  );
  if (!expectedToken || expectedToken !== token) {
    return renderPendingRewardActionHtml_(
      "رمز غير صالح",
      "تعذر التحقق من الرابط. ربما انتهت صلاحيته أو تم تغييره.",
      "error",
    );
  }

  const nowIso = new Date().toISOString();
  const updatedReward = Object.assign({}, reward, {
    status: decision === "approve" ? "approved" : "rejected",
    approvedAt: decision === "approve" ? nowIso : reward.approvedAt,
    rejectedAt: decision === "reject" ? nowIso : reward.rejectedAt,
  });

  const updatedPendingRewards = Array.from(pendingRewards);
  updatedPendingRewards[rewardIndex] = updatedReward;

  const updates = {
    pendingRewards: updatedPendingRewards,
    updatedAt: nowIso,
  };

  const currentCoins = Number.isFinite(Number(walletData.coins))
    ? Number(walletData.coins)
    : 0;

  const taskId = stringValue_(reward.taskId);
  const rewardType = stringValue_(reward.rewardType);
  const isTaskCompletion = rewardType === "task_completion" && taskId;
  const rewardCoins = Number.isFinite(Number(reward.coins))
    ? Number(reward.coins)
    : 0;

  if (decision === "approve") {
    if (isTaskCompletion) {
      const requestedDateKey = dateKeyFromIsoOrNow_(
        reward.requestedAt || reward.createdAt,
      );
      const dailyProgress = normalizeDailyTaskProgress(
        walletData.dailyTaskProgress,
        requestedDateKey,
      );
      const completedTaskIds = Array.isArray(dailyProgress.completedTaskIds)
        ? Array.from(dailyProgress.completedTaskIds)
        : [];
      const alreadyCompletedTask = completedTaskIds.includes(taskId);
      if (!alreadyCompletedTask) {
        completedTaskIds.push(taskId);
        const awardedCoinsByTaskId = Object.assign(
          {},
          dailyProgress.awardedCoinsByTaskId || {},
          {
            [taskId]: rewardCoins,
          },
        );
        const nextTotalTaskCount = Math.max(
          dailyProgress.totalTaskCount || completedTaskIds.length,
          completedTaskIds.length,
        );
        const nextProgress = {
          dateKey: requestedDateKey,
          completedTaskIds,
          totalTaskCount: nextTotalTaskCount,
          awardedCoinsByTaskId,
          plannedTaskIds: Array.isArray(dailyProgress.plannedTaskIds)
            ? Array.from(dailyProgress.plannedTaskIds)
            : [],
          plannedTaskTitlesById: Object.assign(
            {},
            dailyProgress.plannedTaskTitlesById || {},
          ),
        };
        const history = normalizeTaskProgressHistory(
          walletData.taskProgressHistory,
        );
        history[requestedDateKey] = nextProgress;
        updates.dailyTaskProgress = nextProgress;
        updates.taskProgressHistory = history;
        const userRecord = readUserRecord_(userId);
        if (userRecord) {
          upsertDailyProgressRecord_(
            userRecord,
            childId,
            requestedDateKey,
            nextProgress,
          );
        }

        const currentLevelState = normalizeLevelState(
          walletData.levelState,
          nextTotalTaskCount,
        );
        updates.levelState = advanceLevelState(
          currentLevelState,
          1, // Increment by 1 task, not the total tasks count!
        );
        updates.coins = currentCoins + rewardCoins;
      }
    } else {
      updates.coins = currentCoins + rewardCoins;
    }
  }

  try {
    patchFirestoreDocument_(
      firestoreDocumentPath_("users", userId, "children", childId),
      updates,
    );
  } catch (error) {
    return renderPendingRewardActionHtml_(
      "تعذر حفظ التحديث",
      "حدث خطأ أثناء معالجة طلب المكافأة. حاول مرة أخرى لاحقًا.",
      "error",
    );
  }

  if (decision === "approve") {
    return renderPendingRewardActionHtml_(
      "تمت الموافقة",
      "تم اعتماد مكافأة الطفل وإضافتها إلى رصيده بنجاح. ريشة سعيد جداً بهذا الإنجاز!",
      "happy",
    );
  } else {
    return renderPendingRewardActionHtml_(
      "تم الرفض",
      "تم رفض طلب المكافأة هذه المرة. نعتذر منك، ولكن يجب على الطفل إعادة السلوك بشكل أفضل في المرة القادمة لينال المكافأة. ريشة ينتظر منه التميز!",
      "tired",
    );
  }
}

function firestoreDocumentPath_() {
  const segments = Array.prototype.slice
    .call(arguments || [])
    .filter((segment) => segment != null)
    .map((segment) => String(segment).trim());
  return segments.join("/");
}

function getFirestoreDocument_(documentPath) {
  const url =
    "https://firestore.googleapis.com/v1/projects/" +
    CONFIG.firebaseProjectId +
    "/databases/(default)/documents/" +
    documentPath;
  try {
    const response = firestoreApiFetch_(url, "get");
    return response || null;
  } catch (error) {
    // Return null if document not found (404)
    if (error.message && error.message.indexOf("404") !== -1) {
      console.warn(
        "Firestore Document NOT FOUND (404). Project: " +
          CONFIG.firebaseProjectId +
          " | Path: " +
          documentPath,
      );
      return null;
    }
    console.error(
      "Firestore FETCH ERROR. Project: " +
        CONFIG.firebaseProjectId +
        " | Path: " +
        documentPath +
        " | Error: " +
        error.message,
    );
    throw error;
  }
}

function patchFirestoreDocument_(documentPath, updates) {
  const fieldNames = Object.keys(updates);
  if (fieldNames.length === 0) return {};

  const updateMask = fieldNames
    .map((name) => "updateMask.fieldPaths=" + encodeURIComponent(name))
    .join("&");

  const url =
    "https://firestore.googleapis.com/v1/projects/" +
    CONFIG.firebaseProjectId +
    "/databases/(default)/documents/" +
    documentPath +
    "?currentDocument.exists=true" +
    "&" +
    updateMask;

  const fields = {};
  fieldNames.forEach((name) => {
    fields[name] = objectToFirestoreFields(updates[name]);
  });

  return firestoreApiFetch_(url, "patch", { fields: fields });
}

function firestoreApiFetch_(url, method, payload) {
  const options = {
    method: method,
    headers: {
      Authorization: "Bearer " + ScriptApp.getOAuthToken(),
    },
    muteHttpExceptions: true,
  };
  if (payload != null) {
    options.contentType = "application/json; charset=utf-8";
    options.payload = JSON.stringify(payload);
  }

  const response = UrlFetchApp.fetch(url, options);
  const statusCode = response.getResponseCode();
  const contentText = response.getContentText();
  if (statusCode < 200 || statusCode >= 300) {
    let errorMsg = "HTTP " + statusCode;
    try {
      const errorObj = JSON.parse(contentText);
      if (errorObj && errorObj.error && errorObj.error.message) {
        errorMsg += " - " + errorObj.error.message;
      } else {
        errorMsg += " - " + contentText;
      }
    } catch (e) {
      errorMsg += " - " + contentText;
    }
    throw new Error("Firestore API error: " + errorMsg);
  }
  return contentText ? parseJsonObject_(contentText) : {};
}

function upsertFirestoreDocument_(documentPath, record) {
  const fieldNames = Object.keys(record);
  if (fieldNames.length === 0) return {};

  const updateMask = fieldNames
    .map((name) => "updateMask.fieldPaths=" + encodeURIComponent(name))
    .join("&");

  const url =
    "https://firestore.googleapis.com/v1/projects/" +
    CONFIG.firebaseProjectId +
    "/databases/(default)/documents/" +
    documentPath +
    "?" +
    updateMask;

  const fields = {};
  fieldNames.forEach((name) => {
    fields[name] = objectToFirestoreFields(record[name]);
  });

  return firestoreApiFetch_(url, "patch", { fields: fields });
}

function deleteFirestoreDocument_(documentPath) {
  const url =
    "https://firestore.googleapis.com/v1/projects/" +
    CONFIG.firebaseProjectId +
    "/databases/(default)/documents/" +
    documentPath;
  try {
    firestoreApiFetch_(url, "delete");
  } catch (e) {
    // Ignore 404
  }
}

function mirrorToFirestore_(sheetName, keyColumns, record) {
  let attemptedPath = "unknown";
  try {
    const collectionName = SHEET_TO_FIRESTORE_COLLECTION[sheetName];
    if (!collectionName) return;

    let docId = "";
    if (keyColumns && keyColumns.length > 0) {
      docId = keyColumns.map((col) => stringValue_(record[col])).join("_");
    }

    if (!docId) {
      docId =
        "doc_" +
        Utilities.computeDigest(
          Utilities.DigestAlgorithm.MD5,
          JSON.stringify(record),
        )
          .map(function (chr) {
            return (chr + 256).toString(16).slice(-2);
          })
          .join("");
    }

    docId = docId.replace(/[\/\.]/g, "-");

    const tableDocumentPath = firestoreDocumentPath_(collectionName, docId);
    let documentPath = tableDocumentPath;

    // Ensure uid is present for security rules
    if (!record.uid && record.parent_uid) {
      record.uid = record.parent_uid;
    }

    // Special handling for nested collections to match mobile app structure
    const uid = stringValue_(record.uid || "");
    const childId = stringValue_(record.child_id || "");

    if (uid && childId && sheetName === SHEETS.children) {
      const nestedChildPath = "users/" + uid + "/children/" + childId;
      attemptedPath = nestedChildPath;

      // توحيد الحقول لتطابق تطبيق Flutter (ageYears بدلاً من age_years)
      const unifiedRecord = { ...record };
      if (unifiedRecord.age_years !== undefined) {
        unifiedRecord.ageYears = unifiedRecord.age_years;
        delete unifiedRecord.age_years;
      }
      if (unifiedRecord.child_name !== undefined) {
        unifiedRecord.name = unifiedRecord.child_name;
        delete unifiedRecord.child_name;
      }
      if (unifiedRecord.avatar_present !== undefined) {
        unifiedRecord.hasAvatar = unifiedRecord.avatar_present;
        delete unifiedRecord.avatar_present;
      }

      console.log(
        "✅ Mirroring child to unified Firestore path: " + nestedChildPath,
      );
      upsertFirestoreDocument_(nestedChildPath, unifiedRecord);
      // تم إزالة return حتى يتم إنشاء نسخة في الجذر أيضاً
    }

    if (uid && childId && sheetName === SHEETS.behaviors) {
      const nestedBehaviorPath =
        "users/" + uid + "/behavior_configs/" + childId;
      upsertFirestoreDocument_(nestedBehaviorPath, record);
    }

    attemptedPath = documentPath;

    console.log(
      "Mirroring sheet '" +
        sheetName +
        "' to Firestore path: " +
        documentPath +
        " (docId: " +
        docId +
        ")",
    );

    upsertFirestoreDocument_(documentPath, record);
  } catch (e) {
    console.error(
      "❌ Mirror error for " +
        sheetName +
        ": " +
        e.message +
        "\nPath attempted: " +
        attemptedPath,
    );
  }
}

function mirrorDeleteFromFirestore_(sheetName, keyFields) {
  let attemptedPath = "unknown";
  try {
    const collectionName = SHEET_TO_FIRESTORE_COLLECTION[sheetName];
    if (!collectionName) return;

    const keyColumns = Object.keys(keyFields);
    if (keyColumns.length === 0) return;

    let docId = keyColumns.map((col) => stringValue_(keyFields[col])).join("_");
    docId = docId.replace(/[\/\.]/g, "-");

    const tableDocumentPath = firestoreDocumentPath_(collectionName, docId);
    let documentPath = tableDocumentPath;

    // Special handling for nested collections to match mobile app structure
    const uid = stringValue_(keyFields.uid || "");
    const childId = stringValue_(keyFields.child_id || "");

    if (uid && childId && sheetName === SHEETS.children) {
      const nestedChildPath = "users/" + uid + "/children/" + childId;
      deleteFirestoreDocument_(nestedChildPath);
    }

    if (uid && childId && sheetName === SHEETS.behaviors) {
      const nestedBehaviorPath =
        "users/" + uid + "/behavior_configs/" + childId;
      deleteFirestoreDocument_(nestedBehaviorPath);
    }

    attemptedPath = documentPath;

    deleteFirestoreDocument_(documentPath);
  } catch (e) {
    console.error(
      "Mirror delete error for " +
        sheetName +
        ": " +
        e.message +
        " | path: " +
        attemptedPath,
    );
  }
}

function firestoreDocumentToJs(document) {
  const rawFields = asObject_(document.fields || {});
  const result = {};
  Object.entries(rawFields).forEach(([key, value]) => {
    result[key] = firestoreValueToJs(value);
  });
  return result;
}

function firestoreValueToJs(value) {
  if (!value || typeof value !== "object") {
    return null;
  }
  if (value.stringValue !== undefined) {
    return stringValue_(value.stringValue);
  }
  if (value.integerValue !== undefined) {
    return Number(value.integerValue);
  }
  if (value.doubleValue !== undefined) {
    return Number(value.doubleValue);
  }
  if (value.booleanValue !== undefined) {
    return value.booleanValue === true;
  }
  if (value.nullValue !== undefined) {
    return null;
  }
  if (value.timestampValue !== undefined) {
    return stringValue_(value.timestampValue);
  }
  if (value.mapValue !== undefined) {
    return firestoreMapValueToJs(value.mapValue);
  }
  if (value.arrayValue !== undefined) {
    return firestoreArrayValueToJs(value.arrayValue);
  }
  return null;
}

function firestoreMapValueToJs(mapValue) {
  const fields = asObject_(mapValue.fields || {});
  const result = {};
  Object.entries(fields).forEach(([key, value]) => {
    result[key] = firestoreValueToJs(value);
  });
  return result;
}

function firestoreArrayValueToJs(arrayValue) {
  const values = Array.isArray(arrayValue.values) ? arrayValue.values : [];
  return values.map((value) => firestoreValueToJs(value));
}

function objectToFirestoreFields(value) {
  if (value === null || value === undefined) {
    return { nullValue: null };
  }
  if (typeof value === "string") {
    return { stringValue: value };
  }
  if (typeof value === "boolean") {
    return { booleanValue: value };
  }
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map((item) => objectToFirestoreFields(item)),
      },
    };
  }
  if (typeof value === "object") {
    const fields = {};
    Object.entries(value).forEach(([key, fieldValue]) => {
      fields[key] = objectToFirestoreFields(fieldValue);
    });
    return { mapValue: { fields: fields } };
  }
  return { stringValue: String(value) };
}

function buildDailyWarningHtml_(todayKey, sections) {
  const content = sections
    .map((section) => {
      return [
        '<div style="background:#f6efe1;border-radius:14px;padding:14px;margin-bottom:12px;">',
        "<strong>" + escapeHtml_(section.childName) + "</strong>",
        '<p style="margin:8px 0 6px;">الإنجاز اليوم: ' +
          section.completedCount +
          " من " +
          section.totalTaskCount +
          "</p>",
        '<p style="margin:0;">المهام غير المكتملة: ' +
          escapeHtml_(section.missingTaskTitles.join("، ")) +
          "</p>",
        "</div>",
      ].join("");
    })
    .join("");

  return wrapEmailHtml_(
    "تنبيه نهاية اليوم",
    "<p>هذا ملخص نهاية اليوم ليوم " + escapeHtml_(todayKey) + ":</p>" + content,
  );
}

function buildDailyWarningText_(todayKey, sections) {
  const lines = ["تنبيه نهاية اليوم - " + todayKey, ""];
  sections.forEach((section) => {
    lines.push(
      section.childName +
        ": " +
        section.completedCount +
        "/" +
        section.totalTaskCount,
    );
    lines.push("غير مكتمل: " + section.missingTaskTitles.join("، "));
    lines.push("");
  });
  return lines.join("\n");
}

function buildWeeklyStatsHtml_(childSummaries) {
  const content = childSummaries
    .map((summary) => {
      const daysHtml = summary.dailyLines
        .map((line) => {
          return (
            "<li>" +
            escapeHtml_(weekdayLabelForDateKey_(line.dateKey)) +
            ": " +
            line.completedCount +
            " / " +
            line.expectedCount +
            "</li>"
          );
        })
        .join("");

      return [
        '<div style="background:#f6efe1;border-radius:14px;padding:14px;margin-bottom:12px;">',
        "<strong>" + escapeHtml_(summary.childName) + "</strong>",
        '<p style="margin:8px 0 6px;">نسبة الإنجاز: ' +
          summary.completionRate +
          "%</p>",
        '<p style="margin:0 0 8px;">إجمالي الأسبوع: ' +
          summary.totalCompleted +
          " من " +
          summary.totalExpected +
          "</p>",
        '<ul style="margin:0;padding-right:18px;">' + daysHtml + "</ul>",
        "</div>",
      ].join("");
    })
    .join("");

  return wrapEmailHtml_(
    "الإحصائية الأسبوعية",
    "<p>ملخص آخر 7 أيام:</p>" + content,
  );
}

function buildWeeklyStatsText_(childSummaries) {
  const lines = ["الإحصائية الأسبوعية - آخر 7 أيام", ""];
  childSummaries.forEach((summary) => {
    lines.push(summary.childName + ": " + summary.completionRate + "%");
    lines.push(
      "الإجمالي: " + summary.totalCompleted + "/" + summary.totalExpected,
    );
    summary.dailyLines.forEach((line) => {
      lines.push(
        " - " +
          weekdayLabelForDateKey_(line.dateKey) +
          ": " +
          line.completedCount +
          "/" +
          line.expectedCount,
      );
    });
    lines.push("");
  });
  return lines.join("\n");
}

function wrapEmailHtml_(title, contentHtml) {
  return [
    '<div dir="rtl" style="font-family:Tahoma,Arial,sans-serif;background:#f8f2e6;padding:24px;color:#3d3025;">',
    '<div style="max-width:640px;margin:0 auto;background:#ffffff;border-radius:18px;padding:24px;border:1px solid #eadfc8;">',
    '<h2 style="margin-top:0;color:#b7864e;">' + escapeHtml_(title) + "</h2>",
    contentHtml,
    '<hr style="border:none;border-top:1px solid #eadfc8;margin:20px 0;">',
    '<p style="margin:0;color:#8c7658;font-size:13px;">تم إرسال هذه الرسالة من نظام ريشة.</p>',
    "</div>",
    "</div>",
  ].join("");
}

function parseRequestBody_(e) {
  if (!e || !e.postData || !e.postData.contents) {
    throw new Error("الطلب لا يحتوي على بيانات.");
  }
  return JSON.parse(e.postData.contents);
}

function authorizeRequest_(request) {
  if (stringValue_(request.secret) !== CONFIG.sharedSecret) {
    throw new Error("المفتاح السري غير صحيح.");
  }
}

function normalizeUser_(input) {
  const raw = asObject_(input);
  const notificationSettings = asObject_(raw.notificationSettings);
  const verification = asObject_(raw.emailVerification);
  const welcomeGuide = asObject_(raw.welcomeGuide);

  return {
    uid: stringValue_(raw.uid),
    email: stringValue_(raw.email).toLowerCase(),
    locale: stringValue_(raw.locale) || "ar",
    notificationSettings: {
      enabled: boolValue_(notificationSettings.enabled, true),
      verification: boolValue_(notificationSettings.verification, true),
      welcomeGuide: boolValue_(notificationSettings.welcomeGuide, true),
      login: boolValue_(notificationSettings.login, true),
      childActivity: boolValue_(notificationSettings.childActivity, true),
      weeklyStats: boolValue_(notificationSettings.weeklyStats, true),
      dailyWarnings: boolValue_(notificationSettings.dailyWarnings, true),
    },
    emailVerification: {
      isVerified: boolValue_(verification.isVerified, false),
      verifiedAt: stringValue_(verification.verifiedAt),
    },
    welcomeGuide: {
      sentAt: stringValue_(welcomeGuide.sentAt),
    },
    createdAt: stringValue_(raw.createdAt),
    updatedAt: stringValue_(raw.updatedAt),
  };
}

function normalizeChild_(input) {
  const raw = asObject_(input);
  return {
    id: stringValue_(raw.id),
    name: stringValue_(raw.name),
    ageYears: numberValue_(raw.ageYears, 0),
    hasAvatar: boolValue_(raw.hasAvatar, false),
  };
}

function upsertUserRecord_(user, overrides) {
  if (!user.uid || !user.email) {
    throw new Error("بيانات المستخدم غير مكتملة.");
  }

  const existing = readUserRecord_(user.uid) || {};
  const settings = user.notificationSettings || {};
  const nowIso = isoNow_();
  const row = {
    uid: user.uid,
    email: user.email,
    locale: user.locale || stringValue_(existing.locale) || "ar",
    notifications_enabled: boolValue_(
      overrides.notificationsEnabled,
      boolValue_(
        settings.enabled,
        boolValue_(existing.notifications_enabled, true),
      ),
    ),
    verification_enabled: boolValue_(
      overrides.verificationEnabled,
      boolValue_(
        settings.verification,
        boolValue_(existing.verification_enabled, true),
      ),
    ),
    welcome_guide_enabled: boolValue_(
      overrides.welcomeGuideEnabled,
      boolValue_(
        settings.welcomeGuide,
        boolValue_(existing.welcome_guide_enabled, true),
      ),
    ),
    login_enabled: boolValue_(
      overrides.loginEnabled,
      boolValue_(settings.login, boolValue_(existing.login_enabled, true)),
    ),
    child_activity_enabled: boolValue_(
      overrides.childActivityEnabled,
      boolValue_(
        settings.childActivity,
        boolValue_(existing.child_activity_enabled, true),
      ),
    ),
    weekly_stats_enabled: boolValue_(
      overrides.weeklyStatsEnabled,
      boolValue_(
        settings.weeklyStats,
        boolValue_(existing.weekly_stats_enabled, true),
      ),
    ),
    daily_warnings_enabled: boolValue_(
      overrides.dailyWarningsEnabled,
      boolValue_(
        settings.dailyWarnings,
        boolValue_(existing.daily_warnings_enabled, true),
      ),
    ),
    email_verified: boolValue_(
      overrides.emailVerified,
      boolValue_(
        user.emailVerification.isVerified,
        boolValue_(existing.email_verified, false),
      ),
    ),
    welcome_sent_at_iso:
      stringValue_(overrides.welcomeSentAtIso) ||
      user.welcomeGuide.sentAt ||
      stringValue_(existing.welcome_sent_at_iso),
    created_at_iso:
      user.createdAt || stringValue_(existing.created_at_iso) || nowIso,
    updated_at_iso:
      stringValue_(overrides.updatedAtIso) || user.updatedAt || nowIso,
    last_login_at_iso:
      stringValue_(overrides.lastLoginAtIso) ||
      stringValue_(existing.last_login_at_iso),
  };
  // الحماية: نستخدم uid و email معاً كمعرفات فريدة لمنع التكرار
  return upsertSheetRecord_(SHEETS.users, ["uid", "email"], row);
}

function upsertChildRecord_(userRecord, child) {
  if (!userRecord.uid || !child.id) {
    throw new Error("بيانات الطفل غير مكتملة.");
  }

  const existing =
    readSheetRecord_(SHEETS.children, {
      uid: userRecord.uid,
      child_id: child.id,
    }) || {};
  return upsertSheetRecord_(SHEETS.children, ["uid", "child_id"], {
    uid: userRecord.uid,
    child_id: child.id,
    child_name: child.name || stringValue_(existing.child_name) || "الطفل",
    age_years: numberValue_(
      child.ageYears,
      numberValue_(existing.age_years, 0),
    ),
    avatar_present: boolValue_(
      child.hasAvatar,
      boolValue_(existing.avatar_present, false),
    ),
    updated_at_iso: isoNow_(),
  });
}

function upsertBehaviorRecord_(userRecord, childId, behaviorConfig) {
  const normalized = normalizeBehaviorConfig_(behaviorConfig);
  return upsertSheetRecord_(SHEETS.behaviors, ["uid", "child_id"], {
    uid: userRecord.uid,
    child_id: childId,
    selected_behavior_ids_json: JSON.stringify(normalized.selectedBehaviorIds),
    custom_behaviors_json: JSON.stringify(normalized.customBehaviors),
    water_cups_count: normalized.water.cupsCount,
    sport_sessions_count: normalized.sport.sessionsCount,
    sport_light_activity_enabled: normalized.sport.lightActivityEnabled,
    sport_session_times_json: JSON.stringify(normalized.sport.sessionTimes),
    sleep_hour: normalized.sleep.hour,
    sleep_minute: normalized.sleep.minute,
    sleep_notifications_enabled: normalized.sleep.notificationsEnabled,
    sleep_routine_configured: normalized.sleep.configured,
    synced_at_iso: isoNow_(),
  });
}

function upsertDailyProgressRecord_(userRecord, childId, dateKey, progress) {
  const normalized = normalizeProgress_(progress, dateKey);
  const completedCount = normalized.completedTaskIds.length;
  const plannedTaskCount = Array.isArray(normalized.plannedTaskIds)
    ? normalized.plannedTaskIds.length
    : 0;
  const totalTaskCount =
    normalized.totalTaskCount > 0
      ? normalized.totalTaskCount
      : Math.max(completedCount, plannedTaskCount);
  return upsertSheetRecord_(
    SHEETS.dailyProgress,
    ["uid", "child_id", "date_key"],
    {
      uid: userRecord.uid,
      child_id: childId,
      date_key: dateKey,
      completed_task_ids_json: JSON.stringify(normalized.completedTaskIds),
      total_task_count: totalTaskCount,
      awarded_coins_by_task_id_json: JSON.stringify(
        normalized.awardedCoinsByTaskId,
      ),
      completion_ratio:
        totalTaskCount > 0 ? completedCount / totalTaskCount : 0,
      planned_task_ids_json: JSON.stringify(normalized.plannedTaskIds || []),
      planned_task_titles_json: JSON.stringify(
        normalized.plannedTaskTitlesById || {},
      ),
      synced_at_iso: isoNow_(),
    },
  );
}

function findVerificationRecord_(uid, email) {
  return readSheetRecord_(SHEETS.verificationCodes, {
    uid: uid,
    email: email,
  });
}

function upsertVerificationRecord_(record) {
  return upsertSheetRecord_(SHEETS.verificationCodes, ["uid", "email"], {
    uid: record.uid,
    email: record.email,
    code_hash: record.codeHash,
    expires_at_iso: record.expiresAtIso,
    last_sent_at_iso: record.lastSentAtIso,
    verified_at_iso: record.verifiedAtIso,
  });
}

function findPasswordResetRecord_(uid, email) {
  return readSheetRecord_(SHEETS.passwordResetCodes, {
    uid: uid,
    email: email,
  });
}

function upsertPasswordResetRecord_(record) {
  return upsertSheetRecord_(SHEETS.passwordResetCodes, ["uid", "email"], {
    uid: record.uid,
    email: record.email,
    code_hash: record.codeHash,
    expires_at_iso: record.expiresAtIso,
    last_sent_at_iso: record.lastSentAtIso,
    verified_at_iso: record.verifiedAtIso,
    used_at_iso: record.usedAtIso,
  });
}

function restoreVerificationRecordAfterFailedEmail_(
  previousRecord,
  uid,
  email,
) {
  try {
    if (previousRecord) {
      upsertVerificationRecord_({
        uid: previousRecord.uid,
        email: previousRecord.email,
        codeHash: previousRecord.code_hash,
        expiresAtIso: previousRecord.expires_at_iso,
        lastSentAtIso: previousRecord.last_sent_at_iso,
        verifiedAtIso: previousRecord.verified_at_iso,
      });
      return;
    }
    deleteMatchingRowsFromSheet_(SHEETS.verificationCodes, {
      uid: uid,
      email: email,
    });
  } catch (restoreError) {
    console.warn(
      "Failed to restore verification code record after email failure: " +
        toErrorMessage_(restoreError),
    );
  }
}

function restorePasswordResetRecordAfterFailedEmail_(
  previousRecord,
  uid,
  email,
) {
  try {
    if (previousRecord) {
      upsertPasswordResetRecord_({
        uid: previousRecord.uid,
        email: previousRecord.email,
        codeHash: previousRecord.code_hash,
        expiresAtIso: previousRecord.expires_at_iso,
        lastSentAtIso: previousRecord.last_sent_at_iso,
        verifiedAtIso: previousRecord.verified_at_iso,
        usedAtIso: previousRecord.used_at_iso,
      });
      return;
    }
    deleteMatchingRowsFromSheet_(SHEETS.passwordResetCodes, {
      uid: uid,
      email: email,
    });
  } catch (restoreError) {
    console.warn(
      "Failed to restore password reset record after email failure: " +
        toErrorMessage_(restoreError),
    );
  }
}

function findBehaviorRecord_(behaviors, uid, childId) {
  return (
    behaviors.find(
      (row) =>
        buildChildKey_(row.uid, row.child_id) === buildChildKey_(uid, childId),
    ) || null
  );
}

function expectedTasksFromBehavior_(behaviorRecord) {
  if (!behaviorRecord) {
    return [];
  }
  const behaviorIds = parseJsonArray_(
    behaviorRecord.selected_behavior_ids_json,
  );
  const expectedTasks = [];
  const seen = {};
  behaviorIds.forEach((behaviorId) => {
    if (!TRACKED_TASKS[behaviorId] || seen[TRACKED_TASKS[behaviorId].id]) {
      return;
    }
    expectedTasks.push(TRACKED_TASKS[behaviorId]);
    seen[TRACKED_TASKS[behaviorId].id] = true;
  });
  return expectedTasks;
}

function expectedTasksFromProgressOrBehavior_(progressRecord, behaviorRecord) {
  const plannedTaskIds = parseJsonArray_(
    progressRecord && progressRecord.planned_task_ids_json,
  );
  const plannedTaskTitlesById = parseJsonObject_(
    progressRecord && progressRecord.planned_task_titles_json,
  );
  if (plannedTaskIds.length > 0) {
    return plannedTaskIds.map((taskId) => {
      const cleanTaskId = stringValue_(taskId);
      return {
        id: cleanTaskId,
        title: stringValue_(plannedTaskTitlesById[cleanTaskId]) || cleanTaskId,
      };
    });
  }
  return expectedTasksFromBehavior_(behaviorRecord);
}

function buildWeeklyStatsSummariesForUser_(options) {
  const user = options.user;
  const childrenForUser = options.childrenForUser || [];
  const behaviors = options.behaviors || [];
  const progressRows = options.progressRows || [];
  const weekKeys = options.weekKeys || [];
  const childSummaries = [];

  childrenForUser.forEach((child) => {
    const behavior = findBehaviorRecord_(behaviors, user.uid, child.child_id);
    const fallbackExpectedTasks = expectedTasksFromBehavior_(behavior);
    if (fallbackExpectedTasks.length === 0) {
      return;
    }

    const dailyLines = [];
    let totalExpected = 0;
    let totalCompleted = 0;

    weekKeys.forEach((dateKey) => {
      const progress = progressRows.find(
        (row) =>
          buildProgressKey_(row.uid, row.child_id, row.date_key) ===
          buildProgressKey_(user.uid, child.child_id, dateKey),
      );
      const completedTaskIds = parseJsonArray_(
        progress && progress.completed_task_ids_json,
      );
      const expectedTasks = expectedTasksFromProgressOrBehavior_(
        progress,
        behavior,
      );
      const expectedCount =
        progress && numberValue_(progress.total_task_count, 0) > 0
          ? numberValue_(progress.total_task_count, expectedTasks.length)
          : expectedTasks.length || fallbackExpectedTasks.length;
      const completedCount = Math.min(completedTaskIds.length, expectedCount);

      totalExpected += expectedCount;
      totalCompleted += completedCount;
      dailyLines.push({
        dateKey: dateKey,
        completedCount: completedCount,
        expectedCount: expectedCount,
      });
    });

    childSummaries.push({
      childName: child.child_name || "الطفل",
      completionRate:
        totalExpected > 0
          ? Math.round((totalCompleted / totalExpected) * 100)
          : 0,
      totalCompleted: totalCompleted,
      totalExpected: totalExpected,
      dailyLines: dailyLines,
    });
  });

  return childSummaries;
}

function normalizeBehaviorConfig_(raw) {
  const config = asObject_(raw);
  const water = asObject_(config.water);
  const sport = asObject_(config.sport);
  const sleep = asObject_(config.sleep);
  return {
    selectedBehaviorIds: parseJsonArray_(config.selectedBehaviorIds || []),
    customBehaviors: Array.isArray(config.customBehaviors)
      ? config.customBehaviors
      : parseJsonArray_(config.customBehaviors),
    water: {
      cupsCount: numberValue_(water.cupsCount, 0),
    },
    sport: {
      sessionsCount: numberValue_(sport.sessionsCount, 0),
      lightActivityEnabled: boolValue_(sport.lightActivityEnabled, false),
      sessionTimes: Array.isArray(sport.sessionTimes)
        ? sport.sessionTimes
        : parseJsonArray_(sport.sessionTimes),
    },
    sleep: {
      hour: numberValue_(sleep.hour, 0),
      minute: numberValue_(sleep.minute, 0),
      notificationsEnabled: boolValue_(sleep.notificationsEnabled, true),
      configured: boolValue_(sleep.configured, false),
    },
  };
}

function normalizeProgress_(raw, fallbackDateKey) {
  const progress = asObject_(raw);
  return {
    dateKey: stringValue_(progress.dateKey) || fallbackDateKey,
    completedTaskIds: Array.isArray(progress.completedTaskIds)
      ? progress.completedTaskIds
          .map((value) => stringValue_(value))
          .filter(Boolean)
      : parseJsonArray_(progress.completedTaskIds),
    totalTaskCount: numberValue_(progress.totalTaskCount, 0),
    awardedCoinsByTaskId: asObject_(
      progress.awardedCoinsByTaskId ||
        parseJsonObject_(progress.awardedCoinsByTaskId),
    ),
    plannedTaskIds: Array.isArray(progress.plannedTaskIds)
      ? progress.plannedTaskIds
          .map((value) => stringValue_(value))
          .filter(Boolean)
      : parseJsonArray_(progress.plannedTaskIds),
    plannedTaskTitlesById: asObject_(
      progress.plannedTaskTitlesById ||
        parseJsonObject_(progress.plannedTaskTitlesById),
    ),
  };
}

function sendEmail_(options) {
  try {
    GmailApp.sendEmail(options.to, options.subject, options.plainBody, {
      htmlBody: options.htmlBody,
      name: CONFIG.appName,
    });
  } catch (e) {
    console.warn("GmailApp failed, falling back to MailApp: " + e.message);
    try {
      MailApp.sendEmail({
        to: options.to,
        subject: options.subject,
        htmlBody: options.htmlBody,
        body: options.plainBody,
        name: CONFIG.appName,
      });
    } catch (mailError) {
      logEmailFailure_(options, mailError);
      throw mailError;
    }
  }
  logEmail_({
    uid: options.uid,
    email: options.to,
    eventType: options.eventType,
    subject: options.subject,
    status: "sent",
    details: stringValue_(options.details),
  });
}

function logEmailFailure_(options, error) {
  try {
    logEmail_({
      uid: options.uid,
      email: options.to,
      eventType: options.eventType,
      subject: options.subject,
      status: "failed",
      details: toErrorMessage_(error),
    });
  } catch (logError) {
    console.warn(
      "Failed to write failed email log: " + toErrorMessage_(logError),
    );
  }
}

/**
 * فحص ما إذا تم إرسال إيميل لنفس الحدث/المستخدم/الطفل مؤخراً
 * يمنع التكرار بدون تعطيل أي خدمة (آمن تماماً)
 */
function wasEventEmailRecentlySent_(uid, eventType, childId, cooldownMs) {
  try {
    // الأحداث التي لا تحتاج حماية تكرار (رموز التحقق وإعادة التعيين)
    const exemptEvents = {
      verification_code: true,
      pending_reward: true,
      password_reset_code: true,
      password_reset_completed: true,
      welcome_guide: true,
      daily_warning: true,
      weekly_stats: true,
      daily_warning_test: true,
      weekly_stats_test: true,
      weekly_stats_completed_pipeline_test: true,
    };
    if (exemptEvents[eventType]) {
      return false;
    }

    const logs = getSheetRecords_(SHEETS.emailLog);
    const cutoff = new Date(Date.now() - (cooldownMs || 300000));
    const cleanUid = stringValue_(uid);
    const cleanEventType = stringValue_(eventType);
    const cleanChildId = stringValue_(childId);

    for (var i = logs.length - 1; i >= 0; i--) {
      var row = logs[i];
      if (stringValue_(row.status) !== "sent") continue;
      if (stringValue_(row.uid) !== cleanUid) continue;
      if (stringValue_(row.event_type) !== cleanEventType) continue;
      var sentAt = parseIsoDate_(row.timestamp_iso);
      if (!sentAt || sentAt.getTime() < cutoff.getTime()) continue;
      // For child-specific events, also check childId in details
      if (
        cleanChildId &&
        stringValue_(row.details).indexOf(cleanChildId) === -1
      )
        continue;
      return true;
    }
    return false;
  } catch (e) {
    // Safety: never block sending due to dedup check failure
    console.warn(
      "wasEventEmailRecentlySent_ error (allowing send): " + e.message,
    );
    return false;
  }
}

function logEmail_(entry) {
  upsertAppendRecord_(SHEETS.emailLog, {
    timestamp_iso: isoNow_(),
    uid: stringValue_(entry.uid),
    email: stringValue_(entry.email),
    event_type: stringValue_(entry.eventType),
    subject: stringValue_(entry.subject),
    status: stringValue_(entry.status),
    details: stringValue_(entry.details),
  });
}

let _cachedSpreadsheet_ = null;

function ensureStorageSpreadsheet_() {
  if (_cachedSpreadsheet_) {
    return _cachedSpreadsheet_;
  }

  const properties = PropertiesService.getScriptProperties();
  const storedId = stringValue_(properties.getProperty(STORAGE_PROPERTY_KEY));
  let spreadsheet = null;
  if (storedId) {
    try {
      spreadsheet = SpreadsheetApp.openById(storedId);
    } catch (error) {
      properties.deleteProperty(STORAGE_PROPERTY_KEY);
    }
  }
  if (!spreadsheet) {
    spreadsheet = SpreadsheetApp.create(CONFIG.storageTitle);
    properties.setProperty(STORAGE_PROPERTY_KEY, spreadsheet.getId());
  }

  ensureSheet_(spreadsheet, SHEETS.users, HEADERS.users);
  ensureSheet_(spreadsheet, SHEETS.children, HEADERS.children);
  ensureSheet_(spreadsheet, SHEETS.childrenArchive, HEADERS.childrenArchive);
  ensureSheet_(spreadsheet, SHEETS.behaviors, HEADERS.behaviors);
  ensureSheet_(spreadsheet, SHEETS.behaviorsArchive, HEADERS.behaviorsArchive);
  ensureSheet_(spreadsheet, SHEETS.dailyProgress, HEADERS.dailyProgress);
  ensureSheet_(
    spreadsheet,
    SHEETS.dailyProgressArchive,
    HEADERS.dailyProgressArchive,
  );
  ensureSheet_(
    spreadsheet,
    SHEETS.verificationCodes,
    HEADERS.verificationCodes,
  );
  ensureSheet_(
    spreadsheet,
    SHEETS.passwordResetCodes,
    HEADERS.passwordResetCodes,
  );
  ensureSheet_(spreadsheet, SHEETS.emailLog, HEADERS.emailLog);
  ensureSheet_(spreadsheet, SHEETS.operationsQueue, HEADERS.operationsQueue);

  // Note: runDatabaseCleanup_ is removed from critical path to avoid conflicts with Filters/Sorting
  // runDatabaseCleanup_(spreadsheet);

  _cachedSpreadsheet_ = spreadsheet;
  return spreadsheet;
}

/**
 * وظيفة تنظيف قاعدة البيانات: تحذف عمود time_zone وأي أعمدة عمر مكررة
 */
function runDatabaseCleanup_(ss) {
  const sheets = ss.getSheets();
  sheets.forEach((sheet) => {
    const sheetName = sheet.getName();
    if (sheet.getLastColumn() === 0) return;

    const headers = sheet
      .getRange(1, 1, 1, sheet.getLastColumn())
      .getValues()[0];
    const columnsToDelete = [];

    headers.forEach((header, index) => {
      const h = stringValue_(header).toLowerCase().trim();

      // حذف أي عمود يتعلق بالمنطقة الزمنية
      if (h === "time_zone" || h === "timezone") {
        columnsToDelete.push(index + 1);
      }

      // في جدول الأطفال، حذف أعمدة العمر المكررة (بخلاف age_years)
      if (
        sheetName === SHEETS.children ||
        sheetName === SHEETS.childrenArchive
      ) {
        if (h === "age" || h === "child_age") {
          columnsToDelete.push(index + 1);
        }
      }
    });

    // الحذف من اليمين لليسار لتجنب تغيير ترتيب المؤشرات
    columnsToDelete
      .sort((a, b) => b - a)
      .forEach((colIndex) => {
        sheet.deleteColumn(colIndex);
        console.log(
          "🗑️ تم حذف العمود مكرر رقم " + colIndex + " من " + sheetName,
        );
      });

    // إجبار كل البيانات في هذا الجدول على أن تكون نصاً بسيطاً لمنع التحذيرات المزعجة
    // تم الإلغاء لأنها تتعارض مع ميزة الجداول (Tables) الجديدة في Google Sheets
  });
}

function getSheet_(sheetName) {
  const spreadsheet = ensureStorageSpreadsheet_();
  let sheet = spreadsheet.getSheetByName(sheetName);
  if (!sheet) {
    sheet = spreadsheet.insertSheet(sheetName);
  }
  if (sheet.getLastRow() === 0) {
    const headers = knownHeadersForSheet_(sheetName);
    if (headers.length > 0) {
      sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
      sheet.setFrozenRows(1);
    }
  }
  return sheet;
}

function ensureSheet_(spreadsheet, sheetName, headers) {
  let sheet = spreadsheet.getSheetByName(sheetName);
  if (!sheet) {
    sheet = spreadsheet.insertSheet(sheetName);
  }
  if (sheet.getLastRow() === 0) {
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheet.setFrozenRows(1);
    // إجبار التنسيق على نص بسيط لمنع "شرائح الأشخاص" المزعجة
    // تم الإلغاء لتجنب الخطأ مع الجداول
    return sheet;
  }
  const currentHeaders = headerRowForSheet_(sheetName, sheet);
  const canonicalCurrentHeaders = currentHeaders.map((header) =>
    canonicalHeaderKey_(header),
  );
  const missingHeaders = headers.filter((header) => {
    const canonicalHeader = canonicalHeaderKey_(header);
    return canonicalCurrentHeaders.indexOf(canonicalHeader) === -1;
  });
  if (missingHeaders.length > 0) {
    const startColumn = currentHeaders.length + 1;
    sheet
      .getRange(1, startColumn, 1, missingHeaders.length)
      .setValues([missingHeaders]);
    sheet.setFrozenRows(1);
  }
  return sheet;
}

function getSheetRecords_(sheetName) {
  const sheet = ensureStorageSpreadsheet_().getSheetByName(sheetName);
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) {
    return [];
  }
  const headers = values[0].map((header) => stringValue_(header));
  return values.slice(1).map((row) => recordFromRow_(headers, row));
}

function readUserRecord_(uid) {
  return readSheetRecord_(SHEETS.users, { uid: uid });
}

function readSheetRecord_(sheetName, keyFields) {
  const records = getSheetRecords_(sheetName);
  return (
    records.find((record) => {
      return Object.keys(keyFields).every((key) => {
        return stringValue_(record[key]) === stringValue_(keyFields[key]);
      });
    }) || null
  );
}

function upsertSheetRecord_(sheetName, keyColumns, rowData) {
  try {
    const spreadsheet = ensureStorageSpreadsheet_();
    const sheet = spreadsheet.getSheetByName(sheetName);
    const headers = headerRowForSheet_(sheetName, sheet);
    const values = sheet.getDataRange().getValues();
    let rowIndex = -1;

    for (let index = 1; index < values.length; index += 1) {
      const record = recordFromRow_(headers, values[index]);
      const matches = keyColumns.every((column) => {
        return stringValue_(record[column]) === stringValue_(rowData[column]);
      });
      if (matches) {
        rowIndex = index + 1;
        break;
      }
    }

    const row = headers.map((header) =>
      cellValue_(rowValueForHeader_(rowData, header)),
    );
    if (rowIndex === -1) {
      sheet.appendRow(row);
    } else {
      const targetRange = sheet.getRange(rowIndex, 1, 1, headers.length);
      targetRange.setValues([row]);
    }
    const finalRecord = recordFromRow_(headers, row);
    mirrorToFirestore_(sheetName, keyColumns, finalRecord);
    return finalRecord;
  } catch (e) {
    console.error(
      "upsertSheetRecord_ failed for " + sheetName + ": " + e.message,
    );
    throw e;
  }
}

function upsertAppendRecord_(sheetName, rowData) {
  const spreadsheet = ensureStorageSpreadsheet_();
  const sheet = spreadsheet.getSheetByName(sheetName);
  const headers = headerRowForSheet_(sheetName, sheet);
  const row = headers.map((header) =>
    cellValue_(rowValueForHeader_(rowData, header)),
  );
  sheet.appendRow(row);
  mirrorToFirestore_(sheetName, [], recordFromRow_(headers, row));
}

function headerRowForSheet_(sheetName, sheet) {
  const activeSheet =
    sheet || ensureStorageSpreadsheet_().getSheetByName(sheetName);
  const values = activeSheet.getDataRange().getValues();
  if (values.length > 0 && Array.isArray(values[0])) {
    return values[0].map((header) => stringValue_(header));
  }

  const knownHeaders = knownHeadersForSheet_(sheetName);
  if (knownHeaders.length > 0) {
    return knownHeaders;
  }

  throw new Error("تعذر العثور على رؤوس الأعمدة لجدول: " + sheetName);
}

function knownHeadersForSheet_(sheetName) {
  switch (sheetName) {
    case SHEETS.users:
      return HEADERS.users.slice();
    case SHEETS.children:
      return HEADERS.children.slice();
    case SHEETS.childrenArchive:
      return HEADERS.childrenArchive.slice();
    case SHEETS.behaviors:
      return HEADERS.behaviors.slice();
    case SHEETS.behaviorsArchive:
      return HEADERS.behaviorsArchive.slice();
    case SHEETS.dailyProgress:
      return HEADERS.dailyProgress.slice();
    case SHEETS.dailyProgressArchive:
      return HEADERS.dailyProgressArchive.slice();
    case SHEETS.verificationCodes:
      return HEADERS.verificationCodes.slice();
    case SHEETS.passwordResetCodes:
      return HEADERS.passwordResetCodes.slice();
    case SHEETS.emailLog:
      return HEADERS.emailLog.slice();
    case SHEETS.operationsQueue:
      return HEADERS.operationsQueue.slice();
    default:
      return [];
  }
}

function recordFromRow_(headers, row) {
  const record = {};
  headers.forEach((header, index) => {
    const canonicalHeader = canonicalHeaderKey_(header);
    if (!canonicalHeader) {
      return;
    }
    const nextValue = row[index];
    if (!Object.prototype.hasOwnProperty.call(record, canonicalHeader)) {
      record[canonicalHeader] = nextValue;
      return;
    }
    if (
      stringValue_(record[canonicalHeader]).trim() === "" &&
      stringValue_(nextValue).trim() !== ""
    ) {
      record[canonicalHeader] = nextValue;
    }
  });
  return record;
}

function canonicalHeaderKey_(header) {
  // إزالة أي رموز تعبيرية أو أيقونات خاصة بجداول جوجل
  const cleanHeader = stringValue_(header).replace(/[^\w\s_]/g, "");
  const normalized = cleanHeader.trim().toLowerCase();
  if (!normalized) {
    return "";
  }
  if (normalized === "z") {
    return "uid";
  }
  if (normalized === "childid") {
    return "child_id";
  }
  if (normalized === "operationid") {
    return "operation_id";
  }
  if (normalized === "operationtype") {
    return "operation_type";
  }
  return normalized;
}

function rowValueForHeader_(rowData, header) {
  if (!rowData || typeof rowData !== "object") {
    return "";
  }
  if (Object.prototype.hasOwnProperty.call(rowData, header)) {
    return rowData[header];
  }
  const canonicalHeader = canonicalHeaderKey_(header);
  if (
    canonicalHeader &&
    Object.prototype.hasOwnProperty.call(rowData, canonicalHeader)
  ) {
    return rowData[canonicalHeader];
  }
  return "";
}

function cellValue_(value) {
  if (value === null || value === undefined) {
    return "";
  }
  if (
    typeof value === "string" ||
    typeof value === "number" ||
    typeof value === "boolean"
  ) {
    return value;
  }
  return JSON.stringify(value);
}

function isUserReadyForEmails_(userRecord) {
  return (
    !!userRecord &&
    !!stringValue_(userRecord.email) &&
    boolValue_(userRecord.notifications_enabled, true)
    // تم إزالة قيد التحقق من البريد كنقطة أمان حسب الطلب
  );
}

function buildChildKey_(uid, childId) {
  return stringValue_(uid) + "::" + stringValue_(childId);
}

function buildProgressKey_(uid, childId, dateKey) {
  return (
    stringValue_(uid) +
    "::" +
    stringValue_(childId) +
    "::" +
    stringValue_(dateKey)
  );
}

function scheduledReportKey_(eventType, reportPeriodKey) {
  return stringValue_(eventType) + "::" + stringValue_(reportPeriodKey);
}

function scheduledReportLogKey_(uid, reportKey) {
  return stringValue_(uid) + "::" + stringValue_(reportKey);
}

function buildSentReportKeySet_(eventType) {
  const targetEventType = stringValue_(eventType);
  const sentReportKeys = {};
  getSheetRecords_(SHEETS.emailLog).forEach((row) => {
    if (
      stringValue_(row.event_type) !== targetEventType ||
      stringValue_(row.status) !== "sent"
    ) {
      return;
    }
    const uid = stringValue_(row.uid);
    const details = stringValue_(row.details);
    if (!uid || !details) {
      return;
    }
    sentReportKeys[scheduledReportLogKey_(uid, details)] = true;
  });
  return sentReportKeys;
}

function wasScheduledReportSentFromSet_(sentReportKeys, uid, reportKey) {
  return !!sentReportKeys[scheduledReportLogKey_(uid, reportKey)];
}

function buildRandomDailyReportSections_() {
  const childNames = ["نوره", "سارة", "محمد", "عمر", "ريم"];
  const taskTitles = [
    "أذكار الصباح",
    "شرب الماء",
    "تنظيف الأسنان",
    "النشاط الرياضي",
    "حل اللغز",
    "قراءة قصيرة",
    "ترتيب الغرفة",
  ];
  const sectionCount = randomInt_(1, 3);
  const sections = [];
  for (let index = 0; index < sectionCount; index += 1) {
    const totalTaskCount = randomInt_(4, 7);
    const completedCount = randomInt_(1, totalTaskCount - 1);
    const missingCount = totalTaskCount - completedCount;
    sections.push({
      childName: pickRandom_(childNames) + " - اختبار " + randomInt_(100, 999),
      completedCount: completedCount,
      totalTaskCount: totalTaskCount,
      missingTaskTitles: shuffledCopy_(taskTitles).slice(0, missingCount),
    });
  }
  return sections;
}

function buildRandomWeeklyReportSummaries_(weekKeys) {
  return buildRandomDailyReportSections_().map((section) => {
    let totalCompleted = 0;
    let totalExpected = 0;
    const dailyLines = weekKeys.map((dateKey) => {
      const expectedCount = randomInt_(3, 7);
      const completedCount = randomInt_(0, expectedCount);
      totalCompleted += completedCount;
      totalExpected += expectedCount;
      return {
        dateKey: dateKey,
        completedCount: completedCount,
        expectedCount: expectedCount,
      };
    });
    return {
      childName: section.childName,
      completionRate:
        totalExpected > 0
          ? Math.round((totalCompleted / totalExpected) * 100)
          : 0,
      totalCompleted: totalCompleted,
      totalExpected: totalExpected,
      dailyLines: dailyLines,
    };
  });
}

function shuffledCopy_(items) {
  const copy = items.slice();
  for (let index = copy.length - 1; index > 0; index -= 1) {
    const swapIndex = randomInt_(0, index);
    const item = copy[index];
    copy[index] = copy[swapIndex];
    copy[swapIndex] = item;
  }
  return copy;
}

function pickRandom_(items) {
  return items[randomInt_(0, items.length - 1)];
}

function randomInt_(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function isValidEmail_(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(stringValue_(email));
}

function isoNow_() {
  return new Date().toISOString();
}

function dateKeyFor_(date) {
  return Utilities.formatDate(date, CONFIG.timeZone, "yyyy-MM-dd");
}

function dateKeyFromIsoOrNow_(value) {
  const parsed = parseIsoDate_(value);
  return dateKeyFor_(parsed || new Date());
}

function buildRecentDateKeys_(dayCount) {
  const keys = [];
  for (let index = dayCount - 1; index >= 0; index -= 1) {
    const date = new Date();
    date.setDate(date.getDate() - index);
    keys.push(dateKeyFor_(date));
  }
  return keys;
}

function weekdayLabelForDateKey_(dateKey) {
  const parsed = parseIsoDate_(dateKey + "T00:00:00");
  if (!parsed) {
    return dateKey;
  }
  return Utilities.formatDate(parsed, CONFIG.timeZone, "EEEE");
}

function parseIsoDate_(value) {
  const clean = stringValue_(value);
  if (!clean) {
    return null;
  }
  const parsed = new Date(clean);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function generateVerificationCode_() {
  let code = "";
  for (let index = 0; index < CONFIG.verificationCodeLength; index += 1) {
    code += Math.floor(Math.random() * 10);
  }
  return code;
}

function hashValue_(value) {
  const bytes = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    stringValue_(value),
    Utilities.Charset.UTF_8,
  );
  return Utilities.base64Encode(bytes);
}

function normalizeEmail_(value) {
  return stringValue_(value).toLowerCase();
}

function validateSixDigitCode_(code, label) {
  if (!/^\d{6}$/.test(stringValue_(code))) {
    throw new Error((label || "الرمز") + " يجب أن يتكون من 6 أرقام.");
  }
}

function validateNewPassword_(password) {
  const cleanPassword = stringValue_(password);
  if (!cleanPassword) {
    throw new Error("أدخل كلمة المرور الجديدة أولًا.");
  }
  if (/\s/.test(cleanPassword)) {
    throw new Error("كلمة المرور لا يجب أن تحتوي على مسافات.");
  }
  if (cleanPassword.length < 6) {
    throw new Error("كلمة المرور يجب أن تكون 6 أحرف على الأقل.");
  }
  if (!/[A-Za-z\u0600-\u06FF]/.test(cleanPassword)) {
    throw new Error("كلمة المرور يجب أن تحتوي على حرف واحد على الأقل.");
  }
  if (!/\d/.test(cleanPassword)) {
    throw new Error("كلمة المرور يجب أن تحتوي على رقم واحد على الأقل.");
  }
}

function requireUsablePasswordResetRecord_(uid, email, code) {
  const resetRecord = findPasswordResetRecord_(uid, email);
  if (!resetRecord) {
    throw new Error("لا يوجد رمز إعادة تعيين نشط لهذا البريد.");
  }

  const usedAt = parseIsoDate_(resetRecord.used_at_iso);
  if (usedAt) {
    throw new Error("تم استخدام هذا الرمز بالفعل. اطلب رمزًا جديدًا.");
  }

  const expiresAt = parseIsoDate_(resetRecord.expires_at_iso);
  if (!expiresAt || expiresAt.getTime() < Date.now()) {
    throw new Error("انتهت صلاحية الرمز. اطلب رمزًا جديدًا.");
  }

  if (hashValue_(code) !== stringValue_(resetRecord.code_hash)) {
    throw new Error("رمز إعادة التعيين غير صحيح.");
  }

  return resetRecord;
}

function requireFirebaseAuthUserByEmail_(email) {
  const authUser = lookupFirebaseAuthUserByEmail_(email);
  if (!authUser) {
    throw new Error("هذا البريد غير مسجل في ريشة.");
  }
  return authUser;
}

function lookupFirebaseAuthUserByEmail_(email) {
  const response = callIdentityToolkitApi_(
    "projects/" + CONFIG.firebaseProjectId + "/accounts:lookup",
    {
      email: [email],
    },
  );
  const users = Array.isArray(response.users) ? response.users : [];
  if (users.length === 0) {
    return null;
  }

  const matchedUser =
    users.find((user) => {
      return normalizeEmail_(user.email) === email;
    }) || users[0];

  return {
    localId: stringValue_(matchedUser.localId),
    email: normalizeEmail_(matchedUser.email || email),
    emailVerified: boolValue_(matchedUser.emailVerified, false),
  };
}

function updateFirebaseAuthPassword_(uid, newPassword) {
  callIdentityToolkitApi_(
    "projects/" + CONFIG.firebaseProjectId + "/accounts:update",
    {
      localId: uid,
      password: newPassword,
    },
  );
}

function callIdentityToolkitApi_(path, payload) {
  const response = UrlFetchApp.fetch(
    "https://identitytoolkit.googleapis.com/v1/" + path,
    {
      method: "post",
      contentType: "application/json; charset=utf-8",
      headers: {
        Authorization: "Bearer " + ScriptApp.getOAuthToken(),
      },
      muteHttpExceptions: true,
      payload: JSON.stringify(payload || {}),
    },
  );

  const statusCode = response.getResponseCode();
  const responseText = response.getContentText();
  const responseBody = responseText ? parseJsonObject_(responseText) : {};

  if (statusCode < 200 || statusCode >= 300) {
    throw new Error(identityToolkitErrorMessage_(responseBody, statusCode));
  }

  return responseBody;
}

function identityToolkitErrorMessage_(responseBody, statusCode) {
  const errorBody = asObject_(responseBody.error);
  const rawMessage = stringValue_(errorBody.message);
  switch (rawMessage) {
    case "EMAIL_NOT_FOUND":
      return "هذا البريد غير مسجل في ريشة.";
    case "USER_NOT_FOUND":
      return "تعذر العثور على الحساب المطلوب.";
    case "INVALID_PASSWORD":
      return "كلمة المرور الجديدة غير صالحة.";
    case "PASSWORD_LOGIN_DISABLED":
      return "تسجيل الدخول بالبريد الإلكتروني غير مفعّل في Firebase.";
    case "INSUFFICIENT_PERMISSION":
    case "PERMISSION_DENIED":
      return "حساب Apps Script لا يملك صلاحية تعديل مستخدمي Firebase Auth.";
    default:
      return rawMessage
        ? "فشل الاتصال بخدمة Firebase Auth: " + rawMessage
        : "فشل الاتصال بخدمة Firebase Auth. رمز الاستجابة: " + statusCode + ".";
  }
}

function parseJsonArray_(value) {
  if (Array.isArray(value)) {
    return value.map((item) => stringValue_(item)).filter(Boolean);
  }
  const clean = stringValue_(value);
  if (!clean) {
    return [];
  }
  try {
    const parsed = JSON.parse(clean);
    return Array.isArray(parsed)
      ? parsed.map((item) => stringValue_(item)).filter(Boolean)
      : [];
  } catch (error) {
    return [];
  }
}

function parseJsonObject_(value) {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value;
  }
  const clean = stringValue_(value);
  if (!clean) {
    return {};
  }
  try {
    const parsed = JSON.parse(clean);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? parsed
      : {};
  } catch (error) {
    return {};
  }
}

function stringValue_(value) {
  if (value === null || value === undefined) {
    return "";
  }
  return String(value).trim();
}

function numberValue_(value, fallback) {
  if (typeof value === "number" && !Number.isNaN(value)) {
    return value;
  }
  const parsed = Number(stringValue_(value));
  return Number.isNaN(parsed) ? fallback : parsed;
}

function boolValue_(value, fallback) {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    return value !== 0;
  }
  const normalized = stringValue_(value).toLowerCase();
  if (normalized === "true" || normalized === "1") {
    return true;
  }
  if (normalized === "false" || normalized === "0") {
    return false;
  }
  return fallback;
}

function asObject_(value) {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value;
  }
  return {};
}

function escapeHtml_(value) {
  return stringValue_(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function toErrorMessage_(error) {
  if (!error) {
    return "حدث خطأ غير متوقع.";
  }
  if (typeof error === "string") {
    return error;
  }
  if (error.message) {
    return String(error.message);
  }
  return "حدث خطأ غير متوقع.";
}

function jsonResponse_(payload) {
  return ContentService.createTextOutput(JSON.stringify(payload)).setMimeType(
    ContentService.MimeType.JSON,
  );
}

/**
 * دالة لبناء صفحة استجابة بمظهر احترافي
 */
function buildPendingRewardActionHtml_(title, message, type) {
  const images = {
    happy: "data:image/png;base64," + RESOURCES.happy,
    tired: "data:image/png;base64," + RESOURCES.tired,
    error: "",
  };

  const currentImage = images[type] || "";
  const isError = type === "error";

  const html = [
    "<!DOCTYPE html>",
    '<html lang="ar" dir="rtl">',
    "<head>",
    '  <meta charset="UTF-8">',
    '  <meta name="viewport" content="width=device-width, initial-scale=1.0">',
    "  <title>" + escapeHtml_(title) + "</title>",
    '  <link rel="preconnect" href="https://fonts.googleapis.com">',
    '  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
    '  <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;700&display=swap" rel="stylesheet">',
    "  <style>",
    "    * { box-sizing: border-box; }",
    "    body { ",
    "      font-family: 'Cairo', sans-serif; ",
    "      background: #f0f4f8; ",
    "      display: flex; align-items: center; justify-content: center; ",
    "      min-height: 100vh; margin: 0; padding: 20px;",
    "      color: #334e68; ",
    "    }",
    "    .card { ",
    "      background: #ffffff; ",
    "      max-width: 450px; width: 100%; ",
    "      padding: 40px 30px; ",
    "      border-radius: 24px; ",
    "      box-shadow: 0 15px 35px rgba(0,0,0,0.06); ",
    "      text-align: center; ",
    "      animation: slideDown 0.6s ease-out; ",
    "    }",
    "    @keyframes slideDown { ",
    "      from { transform: translateY(-30px); opacity: 0; } ",
    "      to { transform: translateY(0); opacity: 1; } ",
    "    }",
    "    .icon-box { ",
    "      width: 160px; height: 160px; ",
    "      margin: 0 auto 25px; ",
    "      display: flex; align-items: center; justify-content: center; ",
    "    }",
    "    .icon-box img { ",
    "      max-width: 100%; max-height: 100%; object-fit: contain; ",
    "      animation: fadeIn 0.8s ease-in; ",
    "    }",
    "    @keyframes fadeIn { from { opacity: 0; transform: scale(0.9); } to { opacity: 1; transform: scale(1); } }",
    "    h1 { ",
    "      font-size: 28px; margin: 0 0 15px; ",
    "      color: " +
      (type === "approve"
        ? "#2d9d78"
        : type === "tired"
          ? "#e67e22"
          : "#cb2121") +
      "; ",
    "    }",
    "    p { ",
    "      font-size: 17px; line-height: 1.7; margin: 0; font-weight: 500;",
    "    }",
    "    .status-bar { ",
    "      height: 6px; width: 60px; ",
    "      background: " +
      (type === "approve"
        ? "#2d9d78"
        : type === "tired"
          ? "#e67e22"
          : "#cb2121") +
      "; ",
    "      margin: 20px auto; border-radius: 3px; opacity: 0.3;",
    "    }",
    "  </style>",
    "</head>",
    "<body>",
    '  <div class="card">',
    '    <div class="icon-box">',
    currentImage
      ? '      <img src="' + currentImage + '" alt="Risha">'
      : isError
        ? '      <span style="font-size: 80px;">⚠️</span>'
        : "",
    "    </div>",
    "    <h1>" + escapeHtml_(title) + "</h1>",
    '    <div class="status-bar"></div>',
    "    <p>" + escapeHtml_(message).replace(/\n/g, "<br>") + "</p>",
    "  </div>",
    "</body>",
    "</html>",
  ].join("");

  return HtmlService.createHtmlOutput(html).setXFrameOptionsMode(
    HtmlService.XFrameOptionsMode.ALLOWALL,
  );
}

/**
 * دالة لاختبار الاتصال بـ Firestore يدوياً من داخل المحرر.
 * قم بتشغيل هذه الدالة للتأكد من الصلاحيات وتفعيل الـ API.
 */
function testFirestoreConnection() {
  try {
    const userId = "test_user";
    const path = firestoreDocumentPath_("users", userId);
    const url =
      "https://firestore.googleapis.com/v1/projects/" +
      CONFIG.firebaseProjectId +
      "/databases/(default)/documents/" +
      path;

    console.log("Testing connection to: " + url);
    const response = UrlFetchApp.fetch(url, {
      method: "get",
      headers: { Authorization: "Bearer " + ScriptApp.getOAuthToken() },
      muteHttpExceptions: true,
    });

    const code = response.getResponseCode();
    const content = response.getContentText();
    if (code === 200 || code === 404) {
      console.log(
        "✅ Success! Firestore connection is working (Response Code: " +
          code +
          ")",
      );
    } else if (code === 403) {
      console.error("❌ Error 403! Insufficient permissions.");
      console.log("Please ensure:");
      console.log(
        "1. The Cloud Firestore API is enabled in project " +
          CONFIG.firebaseProjectId,
      );
      console.log(
        "2. The Apps Script project is linked to project number " +
          CONFIG.firebaseProjectId,
      );
      console.log(
        "3. You have run this function and clicked 'Allow' for all requested permissions.",
      );
      console.log("Server response: " + content);
    } else {
      console.error(
        "❌ Error! Response Code: " + code + "\nDetails: " + content,
      );
    }
  } catch (e) {
    console.error("❌ Exception during test: " + e.message);
  }
}

/**
 * يقوم بفحص جميع الأطفال في Firestore والتعامل مع المكافآت المعلقة التي انتهى يومها.
 * يتم تحويلها إلى 'expired' واعتبار السلوك منجزاً بدون نقاط.
 */
function cleanupPendingRewards_(todayKey) {
  const childrenRows = getSheetRecords_(SHEETS.children);
  const userRows = getSheetRecords_(SHEETS.users);

  childrenRows.forEach((childRow) => {
    const userId = stringValue_(childRow.uid);
    const childId = stringValue_(childRow.child_id);
    if (!userId || !childId) return;

    try {
      const docPath = firestoreDocumentPath_(
        "users",
        userId,
        "children",
        childId,
      );
      const childDocument = getFirestoreDocument_(docPath);
      if (!childDocument) return;

      const walletData = firestoreDocumentToJs(childDocument);
      const pendingRewards = Array.isArray(walletData.pendingRewards)
        ? walletData.pendingRewards
        : [];

      const rewardsToExpire = pendingRewards.filter((r) => {
        if (!r || r.status !== "pending") return false;
        const rewardDateKey = dateKeyFromIsoOrNow_(
          r.requestedAt || r.createdAt,
        );
        return rewardDateKey !== todayKey;
      });

      if (rewardsToExpire.length === 0) return;

      const nowIso = isoNow_();
      const nextPendingRewards = pendingRewards.map((reward) => {
        if (reward.status === "pending") {
          const rewardDateKey = dateKeyFromIsoOrNow_(
            reward.requestedAt || reward.createdAt,
          );
          if (rewardDateKey !== todayKey) {
            return Object.assign({}, reward, {
              status: "expired",
              updatedAt: nowIso,
            });
          }
        }
        return reward;
      });

      const updates = {
        pendingRewards: nextPendingRewards,
        updatedAt: nowIso,
      };

      // ملاحظة: قمنا بإزالة كود تعديل مستوى التقدم التقدم التلقائي للمكافآت المنتهية (Expired)
      // لضمان عدم احتساب أي نقاط إلا بموافقة صريحة من ولي الأمر أو إنجاز حقيقي.

      // حفظ التغييرات في Firestore
      patchFirestoreDocument_(docPath, updates);
      console.log(
        "Auto-expired rewards for child: " +
          childId +
          " (User: " +
          userId +
          ")",
      );
    } catch (error) {
      console.error(
        "Error during cleanupPendingRewards_ for child " +
          childId +
          ": " +
          error.message,
      );
    }
  });
}

function normalizeDailyTaskProgress(raw, dateKey) {
  const data = asObject_(raw);
  const plannedTaskIds = Array.isArray(data.plannedTaskIds)
    ? data.plannedTaskIds
    : parseJsonArray_(data.plannedTaskIds);
  const completedTaskIds = Array.isArray(data.completedTaskIds)
    ? data.completedTaskIds
    : parseJsonArray_(data.completedTaskIds);
  return {
    dateKey: stringValue_(data.dateKey) || dateKey,
    completedTaskIds: completedTaskIds,
    totalTaskCount: Math.max(
      numberValue_(data.totalTaskCount, 0),
      completedTaskIds.length,
      plannedTaskIds.length,
    ),
    awardedCoinsByTaskId: asObject_(data.awardedCoinsByTaskId),
    plannedTaskIds: plannedTaskIds,
    plannedTaskTitlesById: asObject_(
      data.plannedTaskTitlesById ||
        parseJsonObject_(data.plannedTaskTitlesById),
    ),
  };
}

function normalizeTaskProgressHistory(raw) {
  const history = asObject_(raw);
  const result = {};
  Object.keys(history).forEach((key) => {
    result[key] = normalizeDailyTaskProgress(history[key], key);
  });
  return result;
}

function normalizeLevelState(raw, fallbackTarget) {
  const data = asObject_(raw);
  return {
    level: numberValue_(data.level, 0),
    progressTasks: numberValue_(data.progressTasks, 0),
    targetTasks: numberValue_(data.targetTasks, fallbackTarget || 1),
    pendingRewardLevels: parseJsonArray_(data.pendingRewardLevels),
  };
}

function advanceLevelState(state, increment = 1) {
  const nextState = Object.assign({}, state);
  // زيادة التقدم بعدد المهام الجديدة
  nextState.progressTasks += increment;

  // رفع المستوى بشكل متكرر حتى يصبح التقدم أقل من الهدف
  while (nextState.progressTasks >= nextState.targetTasks) {
    nextState.progressTasks -= nextState.targetTasks;
    nextState.level += 1;
    nextState.targetTasks = Math.floor(nextState.targetTasks * 1.1) + 2;
    if (!nextState.pendingRewardLevels.includes(nextState.level)) {
      nextState.pendingRewardLevels.push(nextState.level);
    }
  }
  return nextState;
}

/**
 * موارد الصور بصيغة Base64
 */
const RESOURCES = {
  happy:
    "iVBORw0KGgoAAAANSUhEUgAAASwAAAEsCAYAAAB5fY51AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAACxMAAAsTAQCanBgAAKzQSURBVHhe7f0L3G1XVd+NPychN04gJCRAuMk9SYNKeEUgAsGoFUR9q1IE2hpFqcpV2lfUlteE/rGt2BYQk6ogGuyLFLDWC0KLRgLIxSAXJQ0BDPeLJOGa++Wc//yus39Pfs/vjDnX2s85JwHkm8/KmHOM3xhrnb3Wmnuutdfez45du3ZtfJ2vsy67dt+4cdCOg1e9r/N19g9zx9VB/A+RUPvr9sBaZ53YnBU9P4x8czZZmvd1+9VhnXVzev0lVm0GK7Ud+coZFkElft3eZMW6elHFR7m9mGtGjHRLa8C66/u6/eq229mXYml/qR+2xFa+TTLx63aPFevqhftlK5/n0l5aPxnpejH8FdIqnrpe3tf56kTHx5wFWfC490Xmpy714D7sXgNWL9H9/xDj+Jx19K5THyof0NaSdRPXiirPNb2alV85XhMrP6jv1vl6/KsvvkTH4lT50lT+kR7SN/VT4GWCqHyuxabP+WrMn4tVPuyIkZ5+VcN9ytMivC1Sk/h6sj54rvxYadWXzjVO5XPt1/NvuXxnpRNBp6/X8vX66G8UX5VJ7Vz+RW92p7jGq+jtvsgtb1aTtbOeEXWFbR98brJKFahetiKan3SV3nud6tYhWtEVWOpdTzmuH7Lp4ROz+9FZZ1ePH2jWM8n3I91ev5eLddnTFT1Mq+Ky6qut0XlG9XzWiDtqE6vXsaX5MviyzjW6fk9xxnVSq3j+l6++3sWaFfxyuc5jvquEVU+pA5Si3WqeNZZmueMYoCfRVS6zO/Fl6A6k/WOI7+33SfcP9ItiTmpd5txp+cXXgtcL59wf9ar9OlTjnxea+QTqQNpIeO9Op4DtNV3O5fvdVIDlc77ykmNSK3nQNWXrfQjenrVFNI57vM68o0sS64TKl9qlS8Ur2q633OgykvfKKYl6eWIXjxrjfybN92Fi7FO5RutsGIUU61RzfSLXl3Py3hVL7WZn7bSQGWJO57juUkvV1R1vL0devnajqquchzV6NXyWC9XeR4f6R35Uitf6hPXLdHPMaqR66m0+DzuZI7r0jrrxLDurxjFoFdTDP09cYUXWrpCt3MxIb+Tusxxvdd25EubLMl3XO9Wi/srXONUuepr8TjWyVhqaGsRrqvsEnI9YlSr8mUdxXs13K+8njZ1Yonf46mlPVqkqajqA31BO/ue49bJur08j1VkjjOKLa3pZD1s9+dlnErjLI07meNkraU6Fsgc2VHMNT3mdFlLuvRjHY85mZO6nh/oe8zxvnIyH6p89bVU9YXHvbb7MgYeq8jcnnVGsaX+rIEV0mBHbfVB+VU9qLQ9ejWEYl4TPC9jWS/jidfpWafypXavOls6zVZUGvc5lS/zezmVdebiS2pUPtdqqXSQtV2Xvp6/8vWss04cXOtkY/f1XMs7TOn69U6mX9pX6K0X6fS76Xp+U5qYynp/l7OMqf16NWIUV67tqKqGfWpT/mO0jqpdeZUnfSVXv3S3O9hfSW7+LpYVvpxp/K5T87F6N8X6Svp6Wp/oBv1U6O8pX/q+/pUeaO+P+t4jK+qWpWunFHtVPl+72f+nu/X79Vy3F/VVPrS8Suf08teS3N8PaLykU/lY73U6I/w9RiznUofrePhvuoH6Ssd719a6KuvU8uW6DOf813X02eN0q96UfWl9YVre/U9Zp29fN7veRnHfVnnR8O03yZ1Tsc/sqV29pUreDtdL17r8fV/hA9Yn9fSPlp/7tXvUvT43K6+l/MArIcVXlf7fM9z+9uofpW/0pWOn+09PqHH6rW7f6SzH9/R5666f7Otm9v57V890Abw3hbeTf98S8p0f/UInxbtH61Xq0FOHDndx5B/XmNff+7Z9zbP7W8D0X200be6S17+0E87/fntj7T7Mpfat8Xp6Z8Vv69tS5tBf+FfM1gd1Y6XNmj9YlvOat+Xfdr7K7r6n2V47atf/vS3tZ23D7TnuE/HhDqNfQf+V3yZzL/8uS87S+fWkU86tdV/xZf75e/v8/Gq7NTP7V66U/I1L33e3p9Xm9e38VlU1dfVwT9mUfW4P9vpt3/zF38H8lZ1nOzzOf0uR30/z6F/A/n60mclH9A6gGk99n2Y7mFpwHrq03/v739g+rWJ/7B9Z9/TfnvT36V0WdqOf9I6R97vH2mHt+Vj7Xic0gb5pve07Vv+G60/2xadP0VpMMsh+C8tX375+U977C+15q6P/u43L0vbtm3n09r27Vxt36p7TnuOfW871m+97nre6mDH7/7VPrR2Y/fG8W3gOmhV+6Bv6SdPvN/H0fbtfNsB9y4F/0C7XP/7rX6Yp8XN7V99/uPbbLIDq75yE/X7S/L7fN3v79+728He0Zovvvi5v92W728D1n7y9/ZzD9747G6zdOOfvGnnn0B97tD6mOlbR/6i9v0+jUvAA9qO60/aoPWBNojd+Kcv3fPZpueW/+fPffmrtuWvWvN2O69fboPV77TlW+v3lX9Aex37tYn+nZ/S98e+0g+r/tzy+HOf9K+u2/e3Zf9v7/3be9ryqR6vtYf+rZ9913qN3vU6aOfd96t/L+h/W/m6eF8u/Y92+oVvO+i09v+v3f68tm+37f90rN/PqX727S9v/279W7S+tP09S7/Rntf/Rnuu59mO//T3vXF0O8FvX7XzE6df2qfOf6B173T+QO+I/7hdtm/H0+f0unD7Rz5f8Xn4y8u7LviD9n9rW3vP0S7Nf+8YvN93/vj/t896Z2O3wY9/97VbeH03uU1qO4f/h6I/L72j9U/m8TOnS0IdI25A5nNdfL3L+0M5X2u0D/XoAdqntC80L76/pW78+vOv//y3nbV3XfDR7/71K6435lDscK6L09XW50S/p/T50Z1D/hOIn1v2W8Z9wH70IeeebjH07wR65m6+XPr1nN69v9KAnRzo/zR/X7493P787V99Lgf0vtzO9M7P9R3/88569Gf/9Y0X/WhbtuVj00zt/m69XnO0mZ33P6z99vA7o/v43u0GqKfbzO6+ttP7XN/T9D6Y8jOqUatXvK9o+DntqYf8w7adI5uD6L4mvyx44uEvfO7bt7/Pnxr2e6YfmG8/v99eB+/mSrtX9F7O73O2+VlZun/f2f5p6r/7k/n9v/vNrY9uS9OnD/v4z3vX7vUf97pY99N76I7W633lH/Oofm93m6l5P9A7TfM94O/P91f7w7m+tT6I7n8V9B/46P7O0q726Z9V39XezV57Z86L7uO+z6VfA3iN3m6+BvS7eR5oY2mX5L7f++Ie9eLnn37Vyz79o21fvdZ6/T47/L8g6P6RzSGPuV2n59+vT5mHnt/LreYv61T9wD810vQ28vfoq7R+H/F9Oaj6/XqV6N8f1eD69+9j4Xm9uPh8vXmP8f/P9v0L8H+f603n39W6N7v899ePy9v9e1m7X8W9Lqj6+N39at8S+TInp2pX7V6uC786fGk798W728E0D/p8A6VPr8e9T86f/u69mO69X59YQvYfC9/f0n7PZ/vzt/+98v09O7O4H5eDfXy+7+xLPh94Pz7fV/vOnPj5yX/7unA76G+0L9W+/P678p9v99L778bH3N/+p3vY6+Ld7Y8u26V7e/Z+65uUuO30v6VfE3vVat0T6tXW65OfwM3C377r778WrrO1W28f1U7oG6I3VvO2/3T/R7e+Y7T7v9AOMZ3jXwM95pC7+I0xXm3/BvT4bUAnJ/4A8fC9v6V7X6bTf3Wq6O8f0RbeV6/T9/X3rT5n6x6+D8/15fXvP+J7rWf9X/770n73ZfudG++0Mvof972W65fXvLpU+P8DODmZ462mO6VvX0VvA93U0e/rT8fXy6dE/fU7pX3x5aNve/v6V7SByD8k/9jG9S29vG76/Xv+u+GHe7g99X9Wf0PrtX6T8z/7O09117Xf37WvAatW9d/Cbe7H2m+T/m3YPr47zM6W/0aAn8h/09j97N9H2qXp/z6uUfL9uOfv43vH0H/zN/6YfMee+uNfTz1u77+7f/jV591p7R9hL7W7P5R7Z7vveX+vS7X+93/TzX0lO9Lw5XFvS/992f9W9Vrv9X3be7Wfdf9f/61Y9T9zS7v+1O7YfN+/r7//2yX92v/f78C3v7W//9Wv0f07XG3YPy9rP49+t27P/+zv//75vvr6hW97Z9vPZdr2r//1/69/Ptd6jT7Nn3b/e7v/H9/TPl99ve9tN6/B+W5pXvG/089X+0b7v9f+WfU96un9Suf8m90D/VvS6ov0H71eZ3G9at6G+vO2/6+Tf/2+k99E8jX/6e1X/T79V20j4t6D5m9O9S9D7fUuXhV/fXUenA7vW71vuvpQOv6/rV6m8pT8Zre7/n9f8v8xbe9xP4v9r0P8z/37Tte6I7mO2j3x7pD/O/2veA/yfq31hvx8I/NfHve+H+/PZPv+N0/m9D+7a/n9vB7/7+v5v+3/r/XvX9/TjB7nZ/T6jD/+T02Xat93++Xf6+93F0O+hvSfevTf3/n9jI0m0T+F2m/5/O/7t++O6/E+tXm/f5p9fW71v9T7T8+0P979/+L7TDqP7N7YzuSHe7/+PZfqGfG/of2p6/Zf0D6O/Lz2j1//D/H9P//v8AnbUvI+yR0GAAAAABJRU5ErkJggg==",
  error: "",
  tired: "",
};

/**
 * معالجة طابور العمليات المؤجلة
 */
function processOperationsQueue() {
  // Use property-based guard to prevent overlapping runs.
  const properties = PropertiesService.getScriptProperties();

  try {
    const isRunning = properties.getProperty("QUEUE_RUNNING");
    const startedAt = Number(properties.getProperty("QUEUE_STARTED_AT") || "0");
    const now = new Date().getTime();
    if (isRunning === "true" && now - startedAt < 300000) {
      console.warn(
        "processOperationsQueue: skipping — previous run still active.",
      );
      return;
    }
    properties.setProperty("QUEUE_RUNNING", "true");
    properties.setProperty("QUEUE_STARTED_AT", now.toString());
  } catch (e) {
    console.warn("Could not set queue properties guard: " + e.message);
  }

  const startTime = new Date().getTime();

  try {
    // Auto-cleanup: remove completed/failed records older than 16 hours
    purgeCompletedQueueRecords_();

    const allRecords = getSheetRecords_(SHEETS.operationsQueue);
    requeueCompletedChildDeleteOperations_(allRecords);
    const refreshedRecords = getSheetRecords_(SHEETS.operationsQueue);
    const pendingRecords = refreshedRecords.filter((r) => {
      const status = stringValue_(r.status).toLowerCase();
      return status === "pending" || status === "";
    });

    if (pendingRecords.length === 0) return;

    // Prioritize pending_reward_email (newest first), then others
    const rewardRecords = [];
    const otherRecords = [];
    pendingRecords.forEach((r) => {
      if (stringValue_(r.operation_type) === "pending_reward_email") {
        rewardRecords.push(r);
      } else {
        otherRecords.push(r);
      }
    });
    rewardRecords.reverse();
    const orderedRecords = rewardRecords.concat(otherRecords);

    // Process max 20 items per cycle to avoid timeout
    const maxPerCycle = 20;
    let processed = 0;
    for (const record of orderedRecords) {
      if (processed >= maxPerCycle) break;
      // GAS triggers have 6 mins limit, keep it safe at 4 mins
      if (new Date().getTime() - startTime > 240000) break;
      processQueueRecord_(record);
      processed++;
    }
  } catch (error) {
    console.error("processOperationsQueue failed: " + toErrorMessage_(error));
  } finally {
    try {
      properties.setProperty("QUEUE_RUNNING", "false");
    } catch (e) {}
  }
}

function requeueCompletedChildDeleteOperations_(records) {
  if (!Array.isArray(records) || records.length === 0) {
    return 0;
  }

  const existingChildKeys = new Set(
    getSheetRecords_(SHEETS.children).map((row) => stringValue_(row.child_id)),
  );

  let requeuedCount = 0;
  records.forEach((record) => {
    const status = stringValue_(record.status).toLowerCase();
    const operationType = stringValue_(record.operation_type);
    if (status !== "completed" || operationType !== "child_delete") {
      return;
    }

    const uid = stringValue_(record.uid);
    const childId = stringValue_(record.child_id);
    if (!uid || !childId) {
      return;
    }

    const childStillExists = existingChildKeys.has(childId);
    if (!childStillExists) {
      return;
    }

    upsertSheetRecord_(SHEETS.operationsQueue, ["operation_id"], {
      operation_id: stringValue_(record.operation_id),
      operation_type: operationType,
      uid: uid,
      child_id: childId,
      payload_json: stringValue_(record.payload_json),
      status: "pending",
      attempt_count: numberValue_(record.attempt_count, 0),
      next_attempt_at_iso: "",
      last_error: "",
      received_at_iso: stringValue_(record.received_at_iso) || isoNow_(),
      processed_at_iso: "",
    });
    requeuedCount++;
  });

  if (requeuedCount > 0) {
    console.warn(
      "Re-queued " +
        requeuedCount +
        " completed child_delete operations because child rows still exist.",
    );
  }
  return requeuedCount;
}

function purgeCompletedQueueRecords_() {
  try {
    const sheet = getSheet_(SHEETS.operationsQueue);
    const data = sheet.getDataRange().getValues();
    if (data.length <= 1) return;
    const headers = data[0].map((h) => stringValue_(h));
    const statusIndex = headers.indexOf("status");
    const processedAtIndex = headers.indexOf("processed_at_iso");
    const receivedAtIndex = headers.indexOf("received_at_iso");
    if (statusIndex === -1) return;

    const cutoff = new Date(Date.now() - 16 * 60 * 60 * 1000);
    // Delete from bottom to avoid index shift
    for (let i = data.length - 1; i >= 1; i--) {
      const status = stringValue_(data[i][statusIndex]).toLowerCase();
      if (status !== "completed" && status !== "failed") continue;
      const dateStr =
        stringValue_(data[i][processedAtIndex]) ||
        stringValue_(data[i][receivedAtIndex]);
      const recordDate = parseIsoDate_(dateStr);
      if (recordDate && recordDate.getTime() < cutoff.getTime()) {
        sheet.deleteRow(i + 1);
      }
    }
  } catch (error) {
    console.warn(
      "purgeCompletedQueueRecords_ failed: " + toErrorMessage_(error),
    );
  }
}

function processQueuedOperationById_(operationId) {
  const cleanOperationId = stringValue_(operationId);
  if (!cleanOperationId) return false;

  // No outer lock needed — processQueueRecord_ and upsertSheetRecord_
  // handle their own fine-grained locking internally.
  try {
    const record = findSheetRecords_(SHEETS.operationsQueue, {
      operation_id: cleanOperationId,
    })[0];

    if (!record) return false;
    return processQueueRecord_(record);
  } catch (e) {
    console.warn("processQueuedOperationById_ error: " + e.message);
    return false;
  }
}

function processQueueRecord_(record) {
  // Fix: Re-read record from sheet to catch concurrent updates (prevents duplicate processing)
  try {
    const freshRecord = findSheetRecords_(SHEETS.operationsQueue, {
      operation_id: stringValue_(record.operation_id),
    })[0];
    if (freshRecord) {
      record = freshRecord;
    }
  } catch (e) {
    console.warn(
      "processQueueRecord_ fresh-read failed (using cached): " + e.message,
    );
  }

  const status = stringValue_(record.status).toLowerCase();
  if (status === "completed" || status === "failed") {
    return false;
  }
  if (!isQueueOperationDue_(record)) {
    return false;
  }

  const attemptCount = numberValue_(record.attempt_count, 0) + 1;
  const queuePayload = parseJsonObject_(record.payload_json);
  try {
    handleOperation_(stringValue_(record.operation_type), {
      ...queuePayload,
      uid: stringValue_(record.uid),
      childId: stringValue_(record.child_id),
    });
    upsertSheetRecord_(SHEETS.operationsQueue, ["operation_id"], {
      operation_id: stringValue_(record.operation_id),
      operation_type: stringValue_(record.operation_type),
      uid: stringValue_(record.uid),
      child_id: stringValue_(record.child_id),
      payload_json: stringValue_(record.payload_json),
      status: "completed",
      attempt_count: attemptCount,
      next_attempt_at_iso: "",
      last_error: "",
      received_at_iso: stringValue_(record.received_at_iso) || isoNow_(),
      processed_at_iso: isoNow_(),
    });
    return true;
  } catch (error) {
    const errorMessage = toErrorMessage_(error);
    const isEmailQuotaFailure = isEmailQuotaError_(error);
    const isTerminal = !isEmailQuotaFailure && attemptCount >= 5;
    const nextAttemptAtIso = isTerminal
      ? ""
      : isEmailQuotaFailure
        ? nextEmailQuotaRetryIso_()
        : nextOperationRetryIso_(attemptCount);
    upsertSheetRecord_(SHEETS.operationsQueue, ["operation_id"], {
      operation_id: stringValue_(record.operation_id),
      operation_type: stringValue_(record.operation_type),
      uid: stringValue_(record.uid),
      child_id: stringValue_(record.child_id),
      payload_json: stringValue_(record.payload_json),
      status: isTerminal ? "failed" : "pending",
      attempt_count: attemptCount,
      next_attempt_at_iso: nextAttemptAtIso,
      last_error: errorMessage,
      received_at_iso: stringValue_(record.received_at_iso) || isoNow_(),
      processed_at_iso: isTerminal ? isoNow_() : "",
    });
    return false;
  }
}

function handleOperation_(operationType, payload) {
  switch (operationType) {
    case "child_profile_sync":
      return handleSyncChildProfile_(payload);
    case "behavior_sync":
      return handleSyncBehaviorConfig_(payload);
    case "progress_sync":
      return handleSyncDailyProgressHistory_(payload);
    case "child_delete":
      return handleChildDelete_(payload);
    case "pending_reward_email":
      return handlePendingRewardEmail_(payload);
    case "child_activity_email":
      return handleChildActivityEmail_(payload);
    default:
      throw new Error("نوع العملية غير معروف: " + operationType);
  }
}

function handleChildDelete_(payload) {
  const uid = stringValue_(payload.uid || (payload.user && payload.user.uid));
  const childId = stringValue_(
    payload.childId || (payload.child && payload.child.id),
  );

  console.log("Handling child_delete: uid=" + uid + " childId=" + childId);

  if (!uid || !childId) {
    throw new Error("معرف المستخدم والطفل مطلوب لإتمام عملية الحذف.");
  }

  try {
    // 1. Archive from children sheet
    let childDeleteResult = archiveAndDeleteSheetRecords_(
      SHEETS.children,
      SHEETS.childrenArchive,
      { uid: uid, child_id: childId },
      ["uid", "child_id"],
    );
    if (childDeleteResult.deletedCount === 0) {
      const childDeleteByIdResult = archiveAndDeleteSheetRecords_(
        SHEETS.children,
        SHEETS.childrenArchive,
        { child_id: childId },
        ["uid", "child_id"],
      );
      childDeleteResult = {
        archivedCount:
          childDeleteResult.archivedCount + childDeleteByIdResult.archivedCount,
        deletedCount:
          childDeleteResult.deletedCount + childDeleteByIdResult.deletedCount,
      };
    }

    const hasArchivedChild =
      findSheetRecords_(SHEETS.childrenArchive, { uid: uid, child_id: childId })
        .length > 0;
    const remainingChildRows = findSheetRecords_(SHEETS.children, {
      child_id: childId,
    }).length;
    if (remainingChildRows > 0) {
      throw new Error(
        "Child row still exists after forced delete. uid=" +
          uid +
          " child_id=" +
          childId +
          " remaining_rows=" +
          remainingChildRows,
      );
    }
    if (childDeleteResult.deletedCount === 0 && !hasArchivedChild) {
      throw new Error(
        "Child row was not archived or deleted. uid=" +
          uid +
          " child_id=" +
          childId,
      );
    }

    // 2. Archive from behaviors sheet
    let behaviorDeleteResult = archiveAndDeleteSheetRecords_(
      SHEETS.behaviors,
      SHEETS.behaviorsArchive,
      { uid: uid, child_id: childId },
      ["uid", "child_id"],
    );
    if (behaviorDeleteResult.deletedCount === 0) {
      const behaviorDeleteByIdResult = archiveAndDeleteSheetRecords_(
        SHEETS.behaviors,
        SHEETS.behaviorsArchive,
        { child_id: childId },
        ["uid", "child_id"],
      );
      behaviorDeleteResult = {
        archivedCount:
          behaviorDeleteResult.archivedCount +
          behaviorDeleteByIdResult.archivedCount,
        deletedCount:
          behaviorDeleteResult.deletedCount +
          behaviorDeleteByIdResult.deletedCount,
      };
    }

    // 3. Archive from dailyProgress sheet
    let progressDeleteResult = archiveAndDeleteSheetRecords_(
      SHEETS.dailyProgress,
      SHEETS.dailyProgressArchive,
      { uid: uid, child_id: childId },
      ["uid", "child_id", "date_key"],
    );
    if (progressDeleteResult.deletedCount === 0) {
      const progressDeleteByIdResult = archiveAndDeleteSheetRecords_(
        SHEETS.dailyProgress,
        SHEETS.dailyProgressArchive,
        { child_id: childId },
        ["uid", "child_id", "date_key"],
      );
      progressDeleteResult = {
        archivedCount:
          progressDeleteResult.archivedCount +
          progressDeleteByIdResult.archivedCount,
        deletedCount:
          progressDeleteResult.deletedCount +
          progressDeleteByIdResult.deletedCount,
      };
    }

    const droppedPendingOps = dropPendingSyncOperationsForChild_(uid, childId);

    console.log(
      "child_delete summary: children_deleted=" +
        childDeleteResult.deletedCount +
        " behaviors_deleted=" +
        behaviorDeleteResult.deletedCount +
        " progress_deleted=" +
        progressDeleteResult.deletedCount +
        " dropped_pending_ops=" +
        droppedPendingOps,
    );

    // تسجيل النجاح في email_log للمتابعة
    logEmail_({
      uid: uid,
      email: payload.user ? payload.user.email : "child-delete@risha.app",
      eventType: "child_delete_sync",
      subject: "تم حذف الطفل بنجاح وأرشفة بياناته",
      status: "success",
      details: "Child ID: " + childId,
    });

    console.log(
      "child_delete successfully completed for uid=" +
        uid +
        " childId=" +
        childId,
    );
    return {
      deleted: true,
      uid: uid,
      childId: childId,
      childrenDeleted: childDeleteResult.deletedCount,
      behaviorsDeleted: behaviorDeleteResult.deletedCount,
      progressDeleted: progressDeleteResult.deletedCount,
      droppedPendingOps: droppedPendingOps,
    };
  } catch (e) {
    console.error("Error in handleChildDelete_: " + e.message);
    // تسجيل الفشل
    logEmail_({
      uid: uid,
      email: payload.user ? payload.user.email : "child-delete@risha.app",
      eventType: "child_delete_sync",
      subject: "فشل حذف الطفل وأرشفة بياناته",
      status: "failed",
      details: e.message,
    });
    throw e;
  }
}

function forceDeleteChildNow(uid, childId) {
  const cleanUid = stringValue_(uid);
  const cleanChildId = stringValue_(childId);
  if (!cleanUid || !cleanChildId) {
    throw new Error("uid و childId مطلوبان.");
  }
  return handleChildDelete_({
    uid: cleanUid,
    childId: cleanChildId,
    user: { email: "manual-delete@risha.app" },
  });
}

function archiveAndDeleteSheetRecords_(
  sheetName,
  archiveSheetName,
  keyFields,
  archiveKeyColumns,
) {
  const matches = findSheetRecords_(sheetName, keyFields);
  matches.forEach((record) => {
    upsertSheetRecord_(archiveSheetName, archiveKeyColumns, {
      ...record,
      deleted_at_iso: isoNow_(),
    });
  });
  const deletedCount = deleteMatchingRowsFromSheet_(sheetName, keyFields);
  return {
    archivedCount: matches.length,
    deletedCount: deletedCount,
  };
}

function dropPendingSyncOperationsForChild_(uid, childId) {
  const sheet = getSheet_(SHEETS.operationsQueue);
  const data = sheet.getDataRange().getValues();
  if (data.length <= 1) {
    return 0;
  }

  const headers = data[0].map((header) => stringValue_(header));
  const operationTypeIndex = headers.indexOf("operation_type");
  const statusIndex = headers.indexOf("status");
  const uidIndex = headers.indexOf("uid");
  const childIdIndex = headers.indexOf("child_id");
  if (
    operationTypeIndex === -1 ||
    statusIndex === -1 ||
    uidIndex === -1 ||
    childIdIndex === -1
  ) {
    return 0;
  }

  const clearTypes = {
    child_profile_sync: true,
    behavior_sync: true,
    progress_sync: true,
  };

  let deletedCount = 0;
  for (let i = data.length - 1; i >= 1; i--) {
    const rowUid = stringValue_(data[i][uidIndex]);
    const rowChildId = stringValue_(data[i][childIdIndex]);
    const rowType = stringValue_(data[i][operationTypeIndex]);
    const rowStatus = stringValue_(data[i][statusIndex]).toLowerCase();
    const isPending = rowStatus === "pending" || rowStatus === "";
    if (!isPending || clearTypes[rowType] !== true) {
      continue;
    }

    if (rowChildId !== childId) {
      continue;
    }

    // Match by child id first; keep uid check permissive for legacy rows.
    if (rowUid !== uid && rowUid !== "") {
      // Still delete to avoid child resurrection from stale queue rows.
    }

    if (rowChildId === childId) {
      sheet.deleteRow(i + 1);
      deletedCount++;
    }
  }
  return deletedCount;
}

function findSheetRecords_(sheetName, keyFields) {
  const records = getSheetRecords_(sheetName);
  const matches = records.filter((record) => {
    return Object.keys(keyFields).every((key) => {
      const v1 = stringValue_(record[key]);
      const v2 = stringValue_(keyFields[key]);
      const match = v1 === v2;
      if (!match && Object.keys(keyFields).length > 0) {
        // Log mismatch for debugging
      }
      return match;
    });
  });

  if (matches.length === 0) {
    console.warn(
      "No matches found in " +
        sheetName +
        " for keys: " +
        JSON.stringify(keyFields),
    );
  } else {
    console.log(
      "Found " +
        matches.length +
        " matches in " +
        sheetName +
        " for keys: " +
        JSON.stringify(keyFields),
    );
  }

  return matches;
}

function deleteMatchingRowsFromSheet_(sheetName, keyFields) {
  const sheet = getSheet_(sheetName);
  const data = sheet.getDataRange().getValues();
  const headers = data[0].map((header) => stringValue_(header));
  let deletedCount = 0;

  for (let i = data.length - 1; i >= 1; i--) {
    const record = recordFromRow_(headers, data[i]);
    const matches = Object.keys(keyFields).every((key) => {
      return stringValue_(record[key]) === stringValue_(keyFields[key]);
    });
    if (matches) {
      console.log("Deleting row " + (i + 1) + " from " + sheetName);
      sheet.deleteRow(i + 1);
      deletedCount++;
    }
  }

  console.log(
    "Finished deleting matching rows from " +
      sheetName +
      ". Total deleted: " +
      deletedCount,
  );
  if (deletedCount > 0) {
    mirrorDeleteFromFirestore_(sheetName, keyFields);
  }
  return deletedCount;
}

function handlePendingRewardEmail_(payload) {
  return handleSendEventEmail_(payload);
}

function handleChildActivityEmail_(payload) {
  return handleSendEventEmail_(payload);
}

function drainOperationsQueue_() {
  processOperationsQueue();
}

function isQueueOperationDue_(record) {
  const nextAttemptAtIso = stringValue_(record.next_attempt_at_iso);
  if (!nextAttemptAtIso) {
    return true;
  }
  const nextAttemptAt = parseIsoDate_(nextAttemptAtIso);
  return !nextAttemptAt || nextAttemptAt.getTime() <= Date.now();
}

function nextOperationRetryIso_(attemptCount) {
  const retryMinutes = [1, 5, 15, 45, 120];
  const delayMinutes =
    retryMinutes[
      Math.min(Math.max(attemptCount - 1, 0), retryMinutes.length - 1)
    ];
  return new Date(Date.now() + delayMinutes * 60 * 1000).toISOString();
}

function isEmailQuotaError_(error) {
  const message = toErrorMessage_(error).toLowerCase();
  if (message.indexOf("email") === -1) {
    return false;
  }
  return (
    message.indexOf("service invoked too many times") !== -1 ||
    message.indexOf("too many times") !== -1 ||
    message.indexOf("quota") !== -1 ||
    message.indexOf("مرات كثيرة") !== -1
  );
}

function nextEmailQuotaRetryIso_() {
  return new Date(Date.now() + 6 * 60 * 60 * 1000).toISOString();
}

function hasPendingStatisticsAffectingOperations_() {
  const blockingTypes = {
    child_profile_sync: true,
    behavior_sync: true,
    progress_sync: true,
    child_delete: true,
  };
  return getSheetRecords_(SHEETS.operationsQueue).some((record) => {
    const status = stringValue_(record.status).toLowerCase();
    if (status === "completed" || status === "failed") {
      return false;
    }
    return blockingTypes[stringValue_(record.operation_type)] === true;
  });
}

/**
 * دالة لاختبار مزامنة الطفل يدوياً من داخل محرر قوقل سكريبت
 * لتحديد ما إذا كانت المشكلة من السكريبت أم من التطبيق.
 */
function testChildSync_Manual() {
  console.log("=== بدء اختبار مزامنة طفل يدوياً ===");

  // بيانات تجريبية (قم بتغييرها إذا لزم الأمر)
  const testPayload = {
    action: "sync_child_profile",
    user: {
      uid: "84CHSfeBolZXOxTGKEm2P7UagXS2", // الـ UID الخاص بك من لقطة الشاشة
      email: "basm@example.com", // استبدله ببريدك الحقيقي للاختبار
    },
    child: {
      id: "test_child_" + new Date().getTime(),
      name: "طفل تجريبي " + new Date().toLocaleTimeString(),
      ageYears: 7,
      hasAvatar: false,
    },
  };

  try {
    const result = handleSyncChildProfile_(testPayload);
    console.log("النتيجة: " + JSON.stringify(result));
    console.log(
      "✅ تمت العملية بنجاح. تحقق الآن من جدول 'children' في قوقل شيت.",
    );
  } catch (e) {
    console.error("❌ فشل الاختبار: " + e.message);
  }
}
