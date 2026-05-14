const admin = require("firebase-admin");
const crypto = require("crypto");
const nodemailer = require("nodemailer");
const logger = require("firebase-functions/logger");
const { HttpsError, onCall, onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

const DEFAULT_REGION = "us-central1";
const APP_TIME_ZONE = "Asia/Aden";
const VERIFICATION_CODE_TTL_MINUTES = 10;
const VERIFICATION_RESEND_COOLDOWN_SECONDS = 60;
const DEFAULT_SELECTED_BEHAVIORS = ["morning_athkar"];

const TASK_LIBRARY = Object.freeze([
  {
    behaviorId: "morning_athkar",
    taskId: "quran-reading",
    title: "أذكار الصباح والقراءة",
  },
  {
    behaviorId: "brush_teeth",
    taskId: "brush-time",
    title: "تنظيف الأسنان",
  },
  {
    behaviorId: "drink_water",
    taskId: "water-drink",
    title: "شرب الماء",
  },
  {
    behaviorId: "solve_puzzle",
    taskId: "shape-matching",
    title: "تمرين التفكير",
  },
  {
    behaviorId: "sport_activity",
    taskId: "exercising",
    title: "النشاط الرياضي",
  },
  {
    behaviorId: "read_story",
    taskId: "sleep-story",
    title: "قصة النوم",
  },
]);

let cachedTransporter = null;
let cachedMailerSignature = null;

exports.requestEmailVerificationCode = onCall(
  { region: DEFAULT_REGION },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولًا.");
    }

    const userRef = db.collection("users").doc(userId);
    const userSnapshot = await userRef.get();
    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "تعذر العثور على بيانات الحساب.");
    }

    const userData = userSnapshot.data() || {};
    const email = normalizeString(userData.email);
    if (!email) {
      throw new HttpsError(
        "failed-precondition",
        "الحساب لا يحتوي على بريد إلكتروني صالح."
      );
    }

    if (isUserEmailVerified(userData)) {
      return {
        sent: false,
        cooldownSeconds: 0,
        message: "تم توثيق البريد الإلكتروني مسبقًا.",
      };
    }

    const verificationData = toPlainObject(userData.emailVerification);
    const lastCodeSentAt = toDate(verificationData.lastCodeSentAt);
    const now = new Date();
    const elapsedSeconds = lastCodeSentAt
      ? Math.floor((now.getTime() - lastCodeSentAt.getTime()) / 1000)
      : VERIFICATION_RESEND_COOLDOWN_SECONDS;

    if (elapsedSeconds < VERIFICATION_RESEND_COOLDOWN_SECONDS) {
      const remaining =
        VERIFICATION_RESEND_COOLDOWN_SECONDS - Math.max(elapsedSeconds, 0);
      return {
        sent: false,
        cooldownSeconds: remaining,
        message: `تم إرسال رمز قبل قليل. انتظر ${remaining} ثانية ثم أعد المحاولة.`,
      };
    }

    const code = createVerificationCode();
    const expiresAt = new Date(
      now.getTime() + VERIFICATION_CODE_TTL_MINUTES * 60 * 1000
    );
    const reason = normalizeString(request.data?.reason) || "manual";

    await userRef.set(
      {
        email,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        emailVerification: {
          isVerified: false,
          pendingCodeHash: hashVerificationCode(code),
          pendingCodeExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
          lastCodeSentAt: admin.firestore.FieldValue.serverTimestamp(),
          verifiedAt: null,
        },
      },
      { merge: true }
    );

    await queueEmailEvent({
      userId,
      eventType: "verification_code",
      payload: {
        code,
        expiresInMinutes: VERIFICATION_CODE_TTL_MINUTES,
        reason,
      },
    });

    return {
      sent: true,
      cooldownSeconds: VERIFICATION_RESEND_COOLDOWN_SECONDS,
      message: "تم إرسال رمز التحقق إلى بريدك الإلكتروني.",
    };
  }
);

exports.verifyEmailVerificationCode = onCall(
  { region: DEFAULT_REGION },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولًا.");
    }

    const code = normalizeString(request.data?.code);
    if (!/^\d{6}$/.test(code)) {
      throw new HttpsError(
        "invalid-argument",
        "رمز التحقق يجب أن يتكون من 6 أرقام."
      );
    }

    const userRef = db.collection("users").doc(userId);
    const userSnapshot = await userRef.get();
    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "تعذر العثور على بيانات الحساب.");
    }

    const userData = userSnapshot.data() || {};
    if (isUserEmailVerified(userData)) {
      return {
        verified: true,
        message: "البريد الإلكتروني موثق بالفعل.",
      };
    }

    const verificationData = toPlainObject(userData.emailVerification);
    const pendingCodeHash = normalizeString(verificationData.pendingCodeHash);
    const pendingCodeExpiresAt = toDate(verificationData.pendingCodeExpiresAt);
    if (!pendingCodeHash || !pendingCodeExpiresAt) {
      throw new HttpsError(
        "failed-precondition",
        "لا يوجد رمز تحقق نشط. اطلب رمزًا جديدًا أولًا."
      );
    }

    if (pendingCodeExpiresAt.getTime() < Date.now()) {
      throw new HttpsError(
        "failed-precondition",
        "انتهت صلاحية رمز التحقق. اطلب رمزًا جديدًا."
      );
    }

    if (pendingCodeHash !== hashVerificationCode(code)) {
      throw new HttpsError("invalid-argument", "رمز التحقق غير صحيح.");
    }

    await userRef.set(
      {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        "emailVerification.isVerified": true,
        "emailVerification.pendingCodeHash": admin.firestore.FieldValue.delete(),
        "emailVerification.pendingCodeExpiresAt":
          admin.firestore.FieldValue.delete(),
        "emailVerification.lastCodeSentAt":
          admin.firestore.FieldValue.serverTimestamp(),
        "emailVerification.verifiedAt":
          admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    const email = normalizeString(userData.email);
    if (email) {
      try {
        await auth.updateUser(userId, { emailVerified: true });
      } catch (error) {
        logger.warn("Failed to mirror verification state into Firebase Auth.", {
          userId,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    const welcomeGuideData = toPlainObject(userData.welcomeGuide);
    if (!welcomeGuideData.sentAt) {
      await queueEmailEvent({
        userId,
        eventType: "welcome_guide",
        payload: {
          verifiedAt: new Date().toISOString(),
        },
      });
    }

    return {
      verified: true,
      message: "تم توثيق البريد الإلكتروني بنجاح.",
    };
  }
);

exports.handlePendingRewardAction = onRequest(
  { region: DEFAULT_REGION },
  async (req, res) => {
    try {
      const result = await handlePendingRewardActionRequest_(req);
      res.status(200).send(result);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      logger.warn("Pending reward action failed.", { error: message });
      res.status(400).send(buildPendingRewardActionHtml_("فشل الطلب", message));
    }
  }
);

async function handlePendingRewardActionRequest_(req) {
  const userId = normalizeString(req.query.userId || req.body.userId);
  const childId = normalizeString(req.query.childId || req.body.childId);
  const rewardId = normalizeString(req.query.rewardId || req.body.rewardId);
  const token = normalizeString(req.query.token || req.body.token);
  const decision = normalizeString(req.query.decision || req.body.decision);

  if (!userId || !childId || !rewardId || !token || !decision) {
    return buildPendingRewardActionHtml_(
      "رابط غير صالح",
      "تعذر معالجة الرابط. تأكد من استخدام الرابط الكامل المرسل إلى بريدك الإلكتروني."
    );
  }
  if (decision !== "approve" && decision !== "reject") {
    return buildPendingRewardActionHtml_(
      "خيار غير صالح",
      "قرار الطلب غير معروف. يجب أن يكون \"approve\" أو \"reject\"."
    );
  }

  const childDoc = db
    .collection("users")
    .doc(userId)
    .collection("children")
    .doc(childId);
  const childSnapshot = await childDoc.get();
  if (!childSnapshot.exists) {
    return buildPendingRewardActionHtml_(
      "الطفل غير موجود",
      "تعذر العثور على بيانات الطفل المطلوب. تأكد من أن الحساب مرتبط بهذا الطفل."
    );
  }

  const walletData = childSnapshot.data() || {};
  const pendingRewards = Array.isArray(walletData.pendingRewards)
    ? walletData.pendingRewards
    : [];
  const rewardIndex = pendingRewards.findIndex(
    (item) => normalizeString(item?.id) === rewardId
  );
  if (rewardIndex === -1) {
    return buildPendingRewardActionHtml_(
      "المكافأة غير موجودة",
      "لم يتم العثور على طلب المكافأة. ربما تم حذفه أو أن الرابط غير صالح."
    );
  }

  const reward = pendingRewards[rewardIndex] || {};
  const currentStatus = normalizeString(reward.status);
  if (currentStatus !== "pending") {
    return buildPendingRewardActionHtml_(
      "تم معالجة الطلب",
      "تم بالفعل " +
        (currentStatus === "approved" ? "الموافقة على" : "رفض") +
        " هذا الطلب.");
  }

  const expectedToken = normalizeString(
    decision === "approve" ? reward.approvalToken : reward.rejectionToken
  );
  if (!expectedToken || expectedToken !== token) {
    return buildPendingRewardActionHtml_(
      "رمز غير صالح",
      "تعذر التحقق من الرابط. ربما انتهت صلاحيته أو تم تغييره.");
  }

  const nowIso = new Date().toISOString();
  const updatedReward = Object.assign({}, reward, {
    status: decision === "approve" ? "approved" : "rejected",
    approvedAt: decision === "approve" ? nowIso : reward.approvedAt,
    rejectedAt: decision === "reject" ? nowIso : reward.rejectedAt,
  });

  const updatedPendingRewards = [...pendingRewards];
  updatedPendingRewards[rewardIndex] = updatedReward;

  const updates = {
    pendingRewards: updatedPendingRewards,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const currentCoins = Number.isFinite(Number(walletData.coins))
    ? Number(walletData.coins)
    : 0;
  const rewardCoins = Number.isFinite(Number(reward.coins))
    ? Number(reward.coins)
    : 0;
  const taskId = normalizeString(reward.taskId);
  const rewardType = normalizeString(reward.rewardType);
  const isTaskCompletion = rewardType === "task_completion" && taskId;

  if (decision === "approve") {
    if (isTaskCompletion) {
      const rewardRequestedAt = normalizeString(reward.requestedAt) || new Date().toISOString();
      const todayKey = dateKeyFor(new Date(rewardRequestedAt));
      const dailyProgress = normalizeDailyTaskProgress(
        walletData.dailyTaskProgress,
        todayKey
      );
      const completedTaskIds = new Set(dailyProgress.completedTaskIds);
      const alreadyCompletedTask = completedTaskIds.has(taskId);
      if (!alreadyCompletedTask) {
        completedTaskIds.add(taskId);
        const awardedCoinsByTaskId = Object.assign(
          {},
          dailyProgress.awardedCoinsByTaskId,
          {
            [taskId]: rewardCoins,
          }
        );
        const nextTotalTaskCount = Math.max(
          dailyProgress.totalTaskCount,
          completedTaskIds.size
        );
        const nextProgress = {
          dateKey: todayKey,
          completedTaskIds: [...completedTaskIds],
          totalTaskCount: nextTotalTaskCount,
          awardedCoinsByTaskId,
        };
        const history = normalizeTaskProgressHistory(walletData.taskProgressHistory);
        history[todayKey] = nextProgress;
        updates.dailyTaskProgress = nextProgress;
        updates.taskProgressHistory = history;

        const currentLevelState = normalizeLevelState(
          walletData.levelState,
          nextTotalTaskCount
        );
        updates.levelState = advanceLevelState(
          currentLevelState,
          nextTotalTaskCount
        );
        updates.coins = currentCoins + rewardCoins;
      }
    } else {
      updates.coins = currentCoins + rewardCoins;
    }
  }

  await childDoc.set(updates, { merge: true });

  return buildPendingRewardActionHtml_(
    decision === "approve" ? "تمت الموافقة" : "تم الرفض",
    decision === "approve"
      ? "تم اعتماد مكافأة الطفل وإضافتها إلى رصيده." 
      : "تم رفض طلب المكافأة بنجاح."
  );
}

function buildPendingRewardActionHtml_(title, message) {
  return `<!doctype html>
<html lang="ar">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtml(title)}</title>
</head>
<body style="background:#f7f1e2;color:#3f2f1e;font-family:Tahoma,Arial,sans-serif;direction:rtl;padding:24px;">
  <div style="max-width:640px;margin:0 auto;background:#fffaf2;border-radius:20px;padding:28px;border:1px solid #ede1c7;">
    <h1 style="margin-top:0;font-size:28px;color:#4b3425;">${escapeHtml(title)}</h1>
    <p style="font-size:18px;line-height:1.7;color:#5c4937;">${escapeHtml(message)}</p>
  </div>
</body>
</html>`;
}

exports.sendQueuedEmail = onDocumentCreated(
  {
    document: "users/{userId}/email_events/{eventId}",
    region: DEFAULT_REGION,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }

    const userId = event.params.userId;
    const eventData = snapshot.data() || {};
    const eventType = normalizeString(eventData.eventType);
    const payload = toPlainObject(eventData.payload);

    const userSnapshot = await db.collection("users").doc(userId).get();
    if (!userSnapshot.exists) {
      await markEmailEvent(
        snapshot.ref,
        "failed",
        "تعذر العثور على بيانات صاحب الحساب."
      );
      return;
    }

    const userData = userSnapshot.data() || {};
    const email = normalizeString(userData.email);
    if (!email) {
      await markEmailEvent(
        snapshot.ref,
        "failed",
        "الحساب لا يحتوي على بريد إلكتروني صالح."
      );
      return;
    }

    const policy = getEventPolicy(eventType);
    const skipReason = getSkipReasonForEvent({
      userData,
      policy,
    });
    if (skipReason) {
      await markEmailEvent(snapshot.ref, "skipped", skipReason);
      return;
    }

    const message = buildEmailMessage({
      eventType,
      userData,
      payload,
    });
    if (!message) {
      await markEmailEvent(
        snapshot.ref,
        "skipped",
        "نوع الحدث غير مدعوم للبريد."
      );
      return;
    }

    try {
      const transporter = getTransporter();
      const result = await transporter.sendMail({
        from: buildFromAddress(),
        to: email,
        subject: message.subject,
        text: message.text,
        html: message.html,
      });

      await snapshot.ref.set(
        {
          status: "sent",
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          providerMessageId: result.messageId || null,
          errorMessage: admin.firestore.FieldValue.delete(),
        },
        { merge: true }
      );

      if (eventType === "welcome_guide") {
        await db.collection("users").doc(userId).set(
          {
            welcomeGuide: {
              sentAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
    } catch (error) {
      logger.error("Failed to send queued email.", {
        userId,
        eventType,
        error: error instanceof Error ? error.message : String(error),
      });
      await markEmailEvent(
        snapshot.ref,
        "failed",
        error instanceof Error ? error.message : "فشل إرسال البريد الإلكتروني."
      );
    }
  }
);

exports.sendWeeklyStatisticsEmails = onSchedule(
  {
    schedule: "0 18 * * 5",
    timeZone: APP_TIME_ZONE,
    region: DEFAULT_REGION,
  },
  async () => {
    logger.info(
      "Skipping Cloud Functions weekly stats schedule because Apps Script is the sole scheduler."
    );
  }
);

exports.sendDailyInactivityWarnings = onSchedule(
  {
    schedule: "0 21 * * *",
    timeZone: APP_TIME_ZONE,
    region: DEFAULT_REGION,
  },
  async () => {
    logger.info(
      "Skipping Cloud Functions daily warnings schedule because Apps Script is the sole scheduler."
    );
  }
);

function shouldScheduleForUser(userData, settingKey) {
  const settings = getEmailSettings(userData);
  if (!settings.enabled || !settings[settingKey]) {
    return false;
  }
  return isUserEmailVerified(userData) && normalizeString(userData.email);
}

function getSkipReasonForEvent({ userData, policy }) {
  const settings = getEmailSettings(userData);
  if (!settings.enabled) {
    return "الإشعارات البريدية معطلة لهذا الحساب.";
  }
  if (policy.settingKey && !settings[policy.settingKey]) {
    return "هذا النوع من الرسائل البريدية معطل لهذا الحساب.";
  }
  if (!policy.allowUnverified && !isUserEmailVerified(userData)) {
    return "لا يتم إرسال هذا البريد قبل توثيق البريد الإلكتروني.";
  }
  return "";
}

function getEventPolicy(eventType) {
  switch (eventType) {
    case "verification_code":
      return { settingKey: "verification", allowUnverified: true };
    case "welcome_guide":
      return { settingKey: "welcomeGuide", allowUnverified: false };
    case "login":
      return { settingKey: "login", allowUnverified: false };
    case "child_added":
    case "child_updated":
    case "child_switched":
      return { settingKey: "childActivity", allowUnverified: false };
    case "weekly_stats":
      return { settingKey: "weeklyStats", allowUnverified: false };
    case "daily_warning":
      return { settingKey: "dailyWarnings", allowUnverified: false };
    default:
      return { settingKey: "", allowUnverified: false };
  }
}

function getEmailSettings(userData) {
  const rawSettings = toPlainObject(userData.emailNotificationSettings);
  return {
    enabled: rawSettings.enabled !== false,
    verification: rawSettings.verification !== false,
    welcomeGuide: rawSettings.welcomeGuide !== false,
    login: rawSettings.login !== false,
    childActivity: rawSettings.childActivity !== false,
    weeklyStats: rawSettings.weeklyStats !== false,
    dailyWarnings: rawSettings.dailyWarnings !== false,
  };
}

function isUserEmailVerified(userData) {
  const emailVerification = toPlainObject(userData.emailVerification);
  return emailVerification.isVerified === true;
}

function buildEmailMessage({ eventType, userData, payload }) {
  switch (eventType) {
    case "verification_code":
      return buildVerificationCodeEmail(payload);
    case "welcome_guide":
      return buildWelcomeGuideEmail(userData);
    case "login":
      return buildLoginEmail();
    case "child_added":
      return buildChildAddedEmail(payload);
    case "child_updated":
      return buildChildUpdatedEmail(payload);
    case "child_switched":
      return buildChildSwitchedEmail(payload);
    case "weekly_stats":
      return buildWeeklyStatsEmail(payload);
    case "daily_warning":
      return buildDailyWarningEmail(payload);
    default:
      return null;
  }
}

function buildVerificationCodeEmail(payload) {
  const code = normalizeString(payload.code);
  if (!/^\d{6}$/.test(code)) {
    return null;
  }

  const expiresInMinutes = toInt(payload.expiresInMinutes, 10);
  const subject = "رمز التحقق لحساب ريشة";
  const text = [
    "مرحبًا بك في ريشة.",
    "",
    `رمز التحقق الخاص بك هو: ${code}`,
    `صلاحية الرمز: ${expiresInMinutes} دقائق.`,
    "",
    "إذا لم تطلب إنشاء هذا الحساب، يمكنك تجاهل هذه الرسالة.",
  ].join("\n");

  const html = wrapEmailTemplate({
    title: "رمز التحقق",
    body: `
      <p>مرحبًا بك في <strong>ريشة</strong>.</p>
      <p>استخدم الرمز التالي لإكمال التحقق من البريد الإلكتروني:</p>
      <div style="margin:20px 0;padding:16px 20px;background:#f6ead3;border-radius:18px;text-align:center;font-size:34px;font-weight:700;letter-spacing:10px;color:#7c5723;">
        ${escapeHtml(code)}
      </div>
      <p>صلاحية الرمز: <strong>${escapeHtml(
        String(expiresInMinutes)
      )} دقائق</strong>.</p>
      <p>إذا لم تطلب إنشاء هذا الحساب، يمكنك تجاهل هذه الرسالة.</p>
    `,
  });

  return { subject, text, html };
}

function buildWelcomeGuideEmail(userData) {
  const email = normalizeString(userData.email);
  const subject = "أهلًا بك في ريشة";
  const text = [
    "تم تفعيل حسابك في ريشة بنجاح.",
    "",
    "لبداية سهلة:",
    "1. أضف ملف الطفل أو الأطفال.",
    "2. اختر السلوكيات اليومية المناسبة.",
    "3. اضبط الماء والنشاط والنوم.",
    "4. تابع الإنجاز اليومي والإحصائيات الأسبوعية من بريدك.",
    "",
    `البريد المرتبط بالحساب: ${email || "غير محدد"}`,
  ].join("\n");

  const html = wrapEmailTemplate({
    title: "مرحبًا بك في ريشة",
    body: `
      <p>تم تفعيل حسابك في <strong>ريشة</strong> بنجاح.</p>
      <p>هذه أفضل بداية للاستخدام:</p>
      <ol style="padding-right:18px;line-height:1.9;color:#5c4937;">
        <li>أضف ملف الطفل أو الأطفال.</li>
        <li>اختر السلوكيات اليومية المناسبة لكل طفل.</li>
        <li>اضبط روتين الماء والنشاط والنوم.</li>
        <li>تابع الأداء اليومي وستصل إليك الإحصائيات والتنبيهات عبر البريد.</li>
      </ol>
      <p>البريد المرتبط بالحساب: <strong>${escapeHtml(
        email || "غير محدد"
      )}</strong></p>
    `,
  });

  return { subject, text, html };
}

function buildLoginEmail() {
  const formattedTime = formatDateTimeArabic(new Date(), APP_TIME_ZONE);
  const subject = "تم تسجيل الدخول إلى حساب ريشة";
  const text = [
    "تم تسجيل الدخول إلى حساب ريشة.",
    `وقت الدخول: ${formattedTime}`,
  ].join("\n");

  const html = wrapEmailTemplate({
    title: "تسجيل دخول جديد",
    body: `
      <p>تم تسجيل الدخول إلى حساب ريشة بنجاح.</p>
      <p>وقت الدخول: <strong>${escapeHtml(formattedTime)}</strong></p>
    `,
  });

  return { subject, text, html };
}

function buildChildAddedEmail(payload) {
  const childName = normalizeString(payload.childName) || "طفل جديد";
  const subject = "تمت إضافة طفل جديد في ريشة";
  const text = `تمت إضافة الطفل "${childName}" إلى الحساب بنجاح.`;
  const html = wrapEmailTemplate({
    title: "إضافة طفل جديد",
    body: `<p>تمت إضافة الطفل <strong>${escapeHtml(
      childName
    )}</strong> إلى الحساب بنجاح.</p>`,
  });

  return { subject, text, html };
}

function buildChildUpdatedEmail(payload) {
  const childName = normalizeString(payload.childName) || "الطفل";
  const subject = "تم تعديل بيانات طفل في ريشة";
  const text = `تم تعديل بيانات الطفل "${childName}" في الحساب.`;
  const html = wrapEmailTemplate({
    title: "تعديل بيانات طفل",
    body: `<p>تم تعديل بيانات الطفل <strong>${escapeHtml(
      childName
    )}</strong> بنجاح.</p>`,
  });

  return { subject, text, html };
}

function buildChildSwitchedEmail(payload) {
  const childName = normalizeString(payload.childName) || "أحد الأطفال";
  const subject = "تم التبديل بين حسابات الأطفال في ريشة";
  const text = `تم اختيار الحساب النشط للطفل "${childName}".`;
  const html = wrapEmailTemplate({
    title: "تبديل الحساب النشط",
    body: `<p>تم اختيار الحساب النشط للطفل <strong>${escapeHtml(
      childName
    )}</strong>.</p>`,
  });

  return { subject, text, html };
}

function buildWeeklyStatsEmail(payload) {
  const startDateKey = normalizeString(payload.startDateKey);
  const endDateKey = normalizeString(payload.endDateKey);
  const childSummaries = Array.isArray(payload.childSummaries)
    ? payload.childSummaries
    : [];
  if (childSummaries.length === 0) {
    return null;
  }

  const subject = "الإحصائية الأسبوعية من ريشة";
  const textBlocks = childSummaries.map((summary) => {
    const childName = normalizeString(summary.childName) || "الطفل";
    const completedTasks = toInt(summary.completedTasks, 0);
    const totalTasks = toInt(summary.totalTasks, 0);
    const completionRate = toInt(summary.completionRate, 0);
    return [
      childName,
      `الإنجاز: ${completedTasks}/${totalTasks}`,
      `النسبة: ${completionRate}%`,
    ].join("\n");
  });

  const cardsHtml = childSummaries
    .map((summary) => {
      const childName = normalizeString(summary.childName) || "الطفل";
      const completedTasks = toInt(summary.completedTasks, 0);
      const totalTasks = toInt(summary.totalTasks, 0);
      const completionRate = toInt(summary.completionRate, 0);
      const activeDays = toInt(summary.activeDays, 0);
      return `
        <div style="margin-top:14px;padding:16px;background:#fff;border-radius:16px;border:1px solid #eee2c9;">
          <div style="font-size:20px;font-weight:700;color:#7c5723;margin-bottom:8px;">${escapeHtml(
            childName
          )}</div>
          <div style="color:#5c4937;line-height:1.9;">
            <div>الإنجاز: <strong>${completedTasks}/${totalTasks}</strong></div>
            <div>نسبة الإنجاز: <strong>${completionRate}%</strong></div>
            <div>الأيام النشطة: <strong>${activeDays}</strong></div>
          </div>
        </div>
      `;
    })
    .join("");

  const text = [
    "الإحصائية الأسبوعية من ريشة",
    `${startDateKey} - ${endDateKey}`,
    "",
    ...textBlocks,
  ].join("\n\n");

  const html = wrapEmailTemplate({
    title: "الإحصائية الأسبوعية",
    body: `
      <p>هذه خلاصة الأداء الأسبوعي للفترة من <strong>${escapeHtml(
        startDateKey
      )}</strong> إلى <strong>${escapeHtml(endDateKey)}</strong>.</p>
      ${cardsHtml}
    `,
  });

  return { subject, text, html };
}

function buildDailyWarningEmail(payload) {
  const childName = normalizeString(payload.childName) || "الطفل";
  const remainingTasks = Array.isArray(payload.remainingTasks)
    ? payload.remainingTasks
        .map((item) => normalizeString(item))
        .filter(Boolean)
    : [];
  if (remainingTasks.length === 0) {
    return null;
  }

  const completionRate = toInt(payload.completionRate, 0);
  const dateKey = normalizeString(payload.dateKey) || dateKeyFor(new Date());
  const subject = "تنبيه نهاية اليوم من ريشة";
  const text = [
    `لم يكتمل يوم الطفل "${childName}" بعد.`,
    `نسبة الإنجاز الحالية: ${completionRate}%`,
    `التاريخ: ${dateKey}`,
    "",
    "السلوكيات أو المهام المتبقية:",
    ...remainingTasks.map((item) => `- ${item}`),
  ].join("\n");

  const itemsHtml = remainingTasks
    .map((item) => `<li style="margin-bottom:8px;">${escapeHtml(item)}</li>`)
    .join("");

  const html = wrapEmailTemplate({
    title: "تنبيه نهاية اليوم",
    body: `
      <p>لم يكتمل يوم الطفل <strong>${escapeHtml(childName)}</strong> بعد.</p>
      <p>نسبة الإنجاز الحالية: <strong>${completionRate}%</strong></p>
      <p>التاريخ: <strong>${escapeHtml(dateKey)}</strong></p>
      <p>السلوكيات أو المهام المتبقية:</p>
      <ul style="padding-right:18px;color:#5c4937;line-height:1.9;">
        ${itemsHtml}
      </ul>
    `,
  });

  return { subject, text, html };
}

function wrapEmailTemplate({ title, body }) {
  return `
    <div dir="rtl" style="background:#f7f1e2;padding:32px 18px;font-family:Tahoma,Arial,sans-serif;">
      <div style="max-width:640px;margin:0 auto;background:#fffaf2;border-radius:24px;padding:28px;border:1px solid #efe3ca;">
        <div style="font-size:28px;font-weight:700;color:#d6a23c;margin-bottom:18px;text-align:center;">
          ${escapeHtml(title)}
        </div>
        <div style="font-size:16px;color:#5c4937;line-height:1.9;">
          ${body}
        </div>
      </div>
    </div>
  `;
}

function getTransporter() {
  const config = getMailerConfig();
  const signature = JSON.stringify({
    host: config.host,
    port: config.port,
    secure: config.secure,
    user: config.user,
    fromEmail: config.fromEmail,
  });

  if (cachedTransporter && cachedMailerSignature === signature) {
    return cachedTransporter;
  }

  cachedTransporter = nodemailer.createTransport({
    host: config.host,
    port: config.port,
    secure: config.secure,
    auth: {
      user: config.user,
      pass: config.pass,
    },
  });
  cachedMailerSignature = signature;
  return cachedTransporter;
}

function getMailerConfig() {
  const host = normalizeString(process.env.SMTP_HOST);
  const port = toInt(process.env.SMTP_PORT, 587);
  const secure = normalizeString(process.env.SMTP_SECURE) === "true";
  const user = normalizeString(process.env.SMTP_USER);
  const pass = normalizeString(process.env.SMTP_PASS);
  const fromEmail = normalizeString(process.env.SMTP_FROM_EMAIL) || user;
  const fromName = normalizeString(process.env.SMTP_FROM_NAME) || "ريشة";

  if (!host || !user || !pass || !fromEmail) {
    throw new Error(
      "SMTP configuration is incomplete. Set SMTP_HOST, SMTP_PORT, SMTP_SECURE, SMTP_USER, SMTP_PASS, SMTP_FROM_EMAIL, and SMTP_FROM_NAME."
    );
  }

  return {
    host,
    port,
    secure,
    user,
    pass,
    fromEmail,
    fromName,
  };
}

function buildFromAddress() {
  const config = getMailerConfig();
  return `"${config.fromName.replace(/"/g, "")}" <${config.fromEmail}>`;
}

async function queueEmailEvent({ userId, eventType, payload, eventId }) {
  const collectionRef = db
    .collection("users")
    .doc(userId)
    .collection("email_events");
  const docRef = eventId ? collectionRef.doc(eventId) : collectionRef.doc();
  const eventData = {
    eventType,
    payload: payload || {},
    locale: "ar",
    source: "functions",
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  try {
    if (eventId) {
      await docRef.create(eventData);
    } else {
      await docRef.set(eventData);
    }
    return true;
  } catch (error) {
    if (isAlreadyExistsError(error)) {
      return false;
    }
    throw error;
  }
}

async function markEmailEvent(docRef, status, message) {
  await docRef.set(
    {
      status,
      errorMessage: message || null,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

function getSelectedBehaviorIds(childData) {
  const behaviorSettings = toPlainObject(childData.behaviorSettings);
  const selectedBehaviorIds = normalizeStringArray(
    behaviorSettings.selectedBehaviorIds
  );
  return selectedBehaviorIds.length > 0
    ? selectedBehaviorIds
    : DEFAULT_SELECTED_BEHAVIORS;
}

function buildExpectedTasks(selectedBehaviorIds) {
  const selectedIds = new Set(selectedBehaviorIds);
  const seenTaskIds = new Set();
  const tasks = [];

  for (const task of TASK_LIBRARY) {
    if (!selectedIds.has(task.behaviorId)) {
      continue;
    }
    if (seenTaskIds.has(task.taskId)) {
      continue;
    }
    seenTaskIds.add(task.taskId);
    tasks.push(task);
  }

  return tasks;
}

function getHistoryMap(childData) {
  const rawHistory = toPlainObject(childData.taskProgressHistory);
  const history = {};

  for (const [dateKey, rawValue] of Object.entries(rawHistory)) {
    history[dateKey] = progressFromRaw(rawValue);
  }

  const legacyProgress = progressFromRaw(childData.dailyTaskProgress);
  if (
    legacyProgress.dateKey &&
    (!history[legacyProgress.dateKey] ||
      legacyProgress.completedTaskIds.length >
        history[legacyProgress.dateKey].completedTaskIds.length)
  ) {
    history[legacyProgress.dateKey] = legacyProgress;
  }

  return history;
}

function progressFromRaw(rawValue) {
  const raw = toPlainObject(rawValue);
  const completedTaskIds = normalizeStringArray(raw.completedTaskIds);
  return {
    dateKey: normalizeString(raw.dateKey),
    completedTaskIds,
    totalTaskCount: Math.max(toInt(raw.totalTaskCount, 0), completedTaskIds.length),
  };
}

function emptyProgress() {
  return {
    dateKey: "",
    completedTaskIds: [],
    totalTaskCount: 0,
  };
}

function buildPreviousDateKeys({ days, excludeToday }) {
  const keys = [];
  const startOffset = excludeToday ? 1 : 0;

  for (
    let offset = days - 1 + startOffset;
    offset >= startOffset;
    offset -= 1
  ) {
    const date = new Date(Date.now() - offset * 24 * 60 * 60 * 1000);
    keys.push(dateKeyFor(date, APP_TIME_ZONE));
  }

  return keys;
}

function dateKeyFor(date, timeZone = APP_TIME_ZONE) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

function formatDateTimeArabic(date, timeZone = APP_TIME_ZONE) {
  return new Intl.DateTimeFormat("ar", {
    timeZone,
    dateStyle: "full",
    timeStyle: "short",
  }).format(date);
}

function createVerificationCode() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, "0");
}

function hashVerificationCode(code) {
  return crypto.createHash("sha256").update(code).digest("hex");
}

function normalizeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizeStringArray(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return [...new Set(value.map((item) => normalizeString(item)).filter(Boolean))];
}

function toPlainObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return value;
}

function toDate(value) {
  if (!value) {
    return null;
  }
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  if (typeof value.toDate === "function") {
    return value.toDate();
  }
  if (typeof value === "string" || typeof value === "number") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function toInt(value, fallback) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string" && value.trim()) {
    const parsed = Number.parseInt(value.trim(), 10);
    return Number.isNaN(parsed) ? fallback : parsed;
  }
  return fallback;
}

function normalizeLevelState(levelState, fallbackTargetTasks) {
  const rawLevelState = toPlainObject(levelState);
  const targetTasks = Math.max(
    toInt(rawLevelState.targetTasks, fallbackTargetTasks),
    fallbackTargetTasks,
  );
  const pendingRewardLevels = Array.isArray(rawLevelState.pendingRewardLevels)
    ? rawLevelState.pendingRewardLevels
        .map((value) => toInt(value, -1))
        .filter((value) => value > 0)
    : [];

  const level = Math.max(toInt(rawLevelState.level, 0), 0);
  const progressTasks = Math.max(toInt(rawLevelState.progressTasks, 0), 0);

  const shouldRebaseFirstLevel =
    level === 0 &&
    progressTasks === 0 &&
    pendingRewardLevels.length === 0 &&
    targetTasks === 1 &&
    fallbackTargetTasks !== 1;
  if (shouldRebaseFirstLevel) {
    return {
      level: 0,
      progressTasks: 0,
      targetTasks: fallbackTargetTasks,
      pendingRewardLevels,
    };
  }

  return {
    level,
    progressTasks,
    targetTasks,
    pendingRewardLevels,
  };
}

function advanceLevelState(levelState, fallbackTargetTasks) {
  const normalized = normalizeLevelState(levelState, fallbackTargetTasks);
  let nextLevel = normalized.level;
  let nextProgressTasks = normalized.progressTasks + 1;
  let nextTargetTasks = normalized.targetTasks;
  const nextPendingRewardLevels = Array.from(normalized.pendingRewardLevels);

  while (nextProgressTasks >= nextTargetTasks) {
    nextProgressTasks -= nextTargetTasks;
    nextLevel += 1;
    nextPendingRewardLevels.push(nextLevel);
    nextTargetTasks = Math.ceil((nextTargetTasks * 4) / 3);
  }

  return {
    level: nextLevel,
    progressTasks: nextProgressTasks,
    targetTasks: nextTargetTasks,
    pendingRewardLevels: nextPendingRewardLevels,
  };
}

function normalizeDailyTaskProgress(rawProgress, fallbackDateKey) {
  const progress = toPlainObject(rawProgress);
  const completedTaskIds = Array.isArray(progress.completedTaskIds)
    ? normalizeStringArray(progress.completedTaskIds)
    : [];
  const awardedCoinsByTaskId = {};
  if (
    progress.awardedCoinsByTaskId &&
    typeof progress.awardedCoinsByTaskId === "object" &&
    !Array.isArray(progress.awardedCoinsByTaskId)
  ) {
    Object.entries(progress.awardedCoinsByTaskId).forEach(([key, value]) => {
      const taskId = normalizeString(key);
      if (taskId) {
        awardedCoinsByTaskId[taskId] = toInt(value, 0);
      }
    });
  }
  const totalTaskCount = Math.max(
    toInt(progress.totalTaskCount, completedTaskIds.length),
    completedTaskIds.length,
  );

  return {
    dateKey: normalizeString(progress.dateKey) || fallbackDateKey,
    completedTaskIds,
    totalTaskCount,
    awardedCoinsByTaskId,
  };
}

function normalizeTaskProgressHistory(rawHistory) {
  if (!rawHistory || typeof rawHistory !== "object" || Array.isArray(rawHistory)) {
    return {};
  }

  const history = {};
  Object.entries(rawHistory).forEach(([dateKey, value]) => {
    if (!dateKey || typeof dateKey !== "string" || !dateKey.trim()) {
      return;
    }
    history[dateKey.trim()] = normalizeDailyTaskProgress(value, dateKey.trim());
  });
  return history;
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function isAlreadyExistsError(error) {
  if (!error) {
    return false;
  }

  const code = error.code;
  return code === 6 || code === "already-exists" || code === "ALREADY_EXISTS";
}
