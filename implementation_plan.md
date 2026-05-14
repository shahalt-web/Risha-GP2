# إصلاح مشكلة تكرار إرسال الإيميلات

## وصف المشكلة
رسائل البريد الإلكتروني (مثل "تمت إضافة طفل جديد") تُرسل مكررة عشرات المرات لنفس المستخدم، مما يسبب ضغطاً على الخدمة وتأخير الرسائل.

## الأسباب الجذرية المكتشفة

### 🔴 سبب رئيسي #1: قفل غير موثوق في `processOperationsQueue`
```javascript
// الكود الحالي يستخدم Property-based lock وهو غير atomic
const isRunning = properties.getProperty("QUEUE_RUNNING");
if (isRunning === "true") { ... }
```
- دالة `processOperationsQueue` تعمل كل **دقيقة** عبر trigger
- القفل الحالي يعتمد على `PropertiesService` وهو **غير ذري (not atomic)**
- نتيجة: عدة تنفيذات متزامنة تقرأ `QUEUE_RUNNING = false` وتعالج **نفس السجلات** المعلقة
- كل تنفيذ يرسل الإيميل ← تكرار 

### 🔴 سبب رئيسي #2: لا يوجد فحص تكرار في `handleSendEventEmail_`
- دالة `handleSendEventEmail_` ترسل الإيميل **مباشرة بدون أي فحص** للتحقق من إرسال سابق
- لا يتم فحص `email_log` قبل الإرسال
- نفس الحدث (child_added + نفس الطفل) يمكن إرساله عدد لا محدود من المرات

### 🔴 سبب رئيسي #3: سباق بين `tryProcessAcceptedOperationImmediately_` والـ trigger
- عند استلام عملية `pending_reward_email`، يتم تنفيذها **فوراً** في `tryProcessAcceptedOperationImmediately_`
- وفي نفس الوقت، trigger الـ `processOperationsQueue` يعمل كل دقيقة ويعالج نفس السجل إذا لم يُحدَّث بعد

### 🟡 سبب ثانوي #4: `flushDurableOutbox` يُستدعى من عدة مسارات في Flutter
- يُستدعى من `_enqueueDurableOperation` (بعد كل إضافة)
- من `enableBackgroundDispatch` (عند تفعيل الخلفية)
- من `startPendingRewardEmailSyncLoop` (كل 45 ثانية)
- من `saveSelectedChildId` (عند تبديل الطفل)
- رغم وجود `_durableOutboxSyncInFlight` guard، قد تتسبب في إرسال نفس العملية مرتين إلى GAS

### 🟡 سبب ثانوي #5: عمليات `child_activity_email` تستخدم `replaceExisting: false`
```dart
await _enqueueDurableOperation(
  operationId: operationId,
  operationType: 'child_activity_email',
  replaceExisting: false,  // ← لا تستبدل العمليات الموجودة
);
```

## التغييرات المقترحة

### Backend: [Code.gs](file:///h:/work/risha_app_project/risha_v01/apps_script/risha_mail_backend/Code.gs)

---

### 1. استبدال القفل في `processOperationsQueue` بـ `LockService.getScriptLock()`

استبدال القفل المبني على `PropertiesService` بقفل ذري حقيقي:

```javascript
function processOperationsQueue() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) {
    console.warn("Skipping queue run: another execution holds the lock.");
    return;
  }
  try {
    // ... process operations ...
  } finally {
    lock.releaseLock();
  }
}
```

---

### 2. إضافة حماية تكرار في `handleSendEventEmail_`

إضافة فحص في `email_log` لمنع إرسال نفس الحدث لنفس المستخدم/الطفل خلال فترة قصيرة (5 دقائق):

```javascript
function wasEventEmailRecentlySent_(uid, eventType, childId, cooldownMs) {
  const logs = getSheetRecords_(SHEETS.emailLog);
  const cutoff = new Date(Date.now() - cooldownMs);
  return logs.some(row => {
    if (stringValue_(row.uid) !== uid) return false;
    if (stringValue_(row.event_type) !== eventType) return false;
    if (stringValue_(row.status) !== "sent") return false;
    const sentAt = parseIsoDate_(row.timestamp_iso);
    if (!sentAt || sentAt.getTime() < cutoff.getTime()) return false;
    // For child-specific events, check child ID in details/subject
    if (childId && stringValue_(row.details).indexOf(childId) === -1 
        && stringValue_(row.subject).indexOf(childId) === -1) return false;
    return true;
  });
}
```

---

### 3. إضافة حماية إعادة القراءة في `processQueueRecord_`

إعادة قراءة حالة السجل من الشيت قبل المعالجة لتجنب سباق التنفيذ:

```javascript
function processQueueRecord_(record) {
  // إعادة قراءة السجل من الشيت للتأكد من عدم معالجته بالفعل
  const freshRecord = findSheetRecords_(SHEETS.operationsQueue, {
    operation_id: stringValue_(record.operation_id),
  })[0];
  if (!freshRecord) return false;
  const status = stringValue_(freshRecord.status).toLowerCase();
  if (status === "completed" || status === "failed") return false;
  // ... continue processing ...
}
```

---

### 4. تحسين `handleEnqueueOperation_` لمنع إضافة عمليات مكررة

التحقق من وجود عملية معلقة بنفس النوع والمستخدم والطفل:

```javascript
// If a pending operation of same type exists for same uid+child, skip
if (isImmutableQueueOperation_(operationType)) {
  const existing = findSheetRecords_(SHEETS.operationsQueue, {
    operation_id: operationId,
  })[0];
  if (existing) {
    const existingStatus = stringValue_(existing.status).toLowerCase();
    if (existingStatus === "completed") {
      return { enqueued: true, alreadyCompleted: true };
    }
    if (existingStatus === "pending") {
      return { enqueued: true, alreadyPending: true };
    }
  }
}
```

---

### 5. إضافة `childId` في details عند تسجيل الإيميل

لتسهيل فحص التكرار عبر `email_log`:

```javascript
sendEmail_({
  ...options,
  details: childId || options.details,
});
```

---

### Frontend: [email_notification_service.dart](file:///h:/work/risha_app_project/risha_v01/lib/shared/services/email_notification_service.dart)

---

### 6. إضافة throttling محلي لمنع تكرار نفس الحدث

إضافة `_recentlySentEvents` set مع TTL لمنع إرسال نفس الحدث خلال فترة قصيرة:

```dart
static final Map<String, DateTime> _recentlySentEvents = {};
static const Duration _eventThrottleDuration = Duration(minutes: 5);

static bool _isEventThrottled(String eventKey) {
  final lastSent = _recentlySentEvents[eventKey];
  if (lastSent == null) return false;
  return DateTime.now().difference(lastSent) < _eventThrottleDuration;
}
```

---

### 7. تبديل `replaceExisting` لعمليات `child_activity_email` المتعلقة بنفس الطفل

تغيير `replaceExisting: false` إلى `true` واستخدام operationId ثابت (بدون microseconds) لنفس الحدث+الطفل:

```dart
operationId: 'child_activity_email:child_added:${childId.trim()}',
// بدلاً من:
// 'child_activity_email:child_added:${childId.trim()}:${DateTime.now()...}'
```

## خطة التحقق

### اختبارات تلقائية
- تشغيل `processOperationsQueue` بشكل متتالي والتأكد من عدم تكرار الإيميلات
- التأكد من أن `handleSendEventEmail_` يرفض إرسال نفس الحدث خلال 5 دقائق

### تحقق يدوي
- مراقبة `email_log` في Google Sheets بعد النشر
- إضافة طفل جديد والتأكد من وصول إيميل واحد فقط
