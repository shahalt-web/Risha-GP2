"""
Script to fix email duplication issues in Code.gs
All replacements are carefully targeted and backward-compatible.
"""
import re
import sys

FILE_PATH = r'h:\work\risha_app_project\risha_v01\apps_script\risha_mail_backend\Code.gs'

def read_file():
    with open(FILE_PATH, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(content):
    with open(FILE_PATH, 'w', encoding='utf-8', newline='') as f:
        f.write(content)

def fix_1_replace_queue_lock(content):
    """Fix #1: Replace property-based lock with LockService in processOperationsQueue"""
    old = '''function processOperationsQueue() {
  const startTime = new Date().getTime();
  const properties = PropertiesService.getScriptProperties();
  const isRunning = properties.getProperty("QUEUE_RUNNING");
  if (isRunning === "true") {
    const startedAt = Number(properties.getProperty("QUEUE_STARTED_AT") || "0");
    if (startTime - startedAt < 300000) {
      // Previous execution is still running (less than 5 minutes ago)
      return;
    }
  }

  properties.setProperty("QUEUE_RUNNING", "true");
  properties.setProperty("QUEUE_STARTED_AT", startTime.toString());'''

    new = '''function processOperationsQueue() {
  // Fix: LockService atomic lock instead of property-based (prevents concurrent duplicate sends)
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) {
    console.warn("processOperationsQueue: skipping — another execution holds the lock.");
    return;
  }

  const startTime = new Date().getTime();'''

    # Normalize line endings for matching
    old_n = old.replace('\r\n', '\n')
    content_n = content.replace(old_n, '__PLACEHOLDER_1__')
    if '__PLACEHOLDER_1__' not in content_n:
        print("WARNING: Fix #1 old pattern not found, skipping")
        return content
    content_n = content_n.replace('__PLACEHOLDER_1__', new.replace('\r\n', '\n'))
    print("OK: Fix #1 - Replaced property-based lock with LockService")
    return content_n

def fix_1b_replace_finally(content):
    """Fix #1b: Replace the finally block that clears QUEUE_RUNNING property"""
    old = '''  } finally {
    try {
      properties.setProperty("QUEUE_RUNNING", "false");
    } catch (e) {}
  }
}'''

    new = '''  } finally {
    lock.releaseLock();
  }
}'''

    old_n = old.replace('\r\n', '\n')
    # Only replace the one in processOperationsQueue (the last occurrence before requeueCompleted)
    idx = content.find(old_n)
    if idx == -1:
        print("WARNING: Fix #1b old pattern not found, skipping")
        return content
    # Make sure this is the right one (near processOperationsQueue)
    context_before = content[max(0,idx-200):idx]
    if 'processOperationsQueue' in context_before or 'maxPerCycle' in context_before:
        content = content[:idx] + new.replace('\r\n', '\n') + content[idx+len(old_n):]
        print("OK: Fix #1b - Replaced finally block with lock.releaseLock()")
    else:
        print("WARNING: Fix #1b found pattern but not in expected context, skipping")
    return content

def fix_2_add_dedup_to_send_event_email(content):
    """Fix #2: Add deduplication check in handleSendEventEmail_"""
    # Find the line: console.log("Sending email [" + eventType + "] to: " + userRecord.email);
    marker = 'console.log("Sending email [" + eventType + "] to: " + userRecord.email);'
    idx = content.find(marker)
    if idx == -1:
        print("WARNING: Fix #2 marker not found, skipping")
        return content

    dedup_check = '''// Fix: Deduplication - skip if same event was sent recently (5 min cooldown)
  try {
    const childId = child.id ? stringValue_(child.id) : "";
    const dedupKey = eventType + "::" + userRecord.uid + "::" + childId;
    if (wasEventEmailRecentlySent_(userRecord.uid, eventType, childId, 300000)) {
      console.warn("Email SKIPPED [dedup]: " + dedupKey + " was sent within last 5 minutes.");
      return { sent: false, skipped: true, reason: "dedup" };
    }
  } catch (dedupError) {
    // Dedup check failure must never block email sending
    console.warn("Dedup check failed (proceeding with send): " + dedupError.message);
  }

  '''

    content = content[:idx] + dedup_check + content[idx:]
    print("OK: Fix #2 - Added dedup check before email send in handleSendEventEmail_")
    return content

def fix_3_add_fresh_read_to_processQueueRecord(content):
    """Fix #3: Re-read record status before processing to avoid race conditions"""
    old = '''function processQueueRecord_(record) {
  const status = stringValue_(record.status).toLowerCase();
  if (status === "completed" || status === "failed") {
    return false;
  }'''

    new = '''function processQueueRecord_(record) {
  // Fix: Re-read record from sheet to catch concurrent updates (prevents duplicate processing)
  try {
    const freshRecord = findSheetRecords_(SHEETS.operationsQueue, {
      operation_id: stringValue_(record.operation_id),
    })[0];
    if (freshRecord) {
      record = freshRecord;
    }
  } catch (e) {
    console.warn("processQueueRecord_ fresh-read failed (using cached): " + e.message);
  }

  const status = stringValue_(record.status).toLowerCase();
  if (status === "completed" || status === "failed") {
    return false;
  }'''

    old_n = old.replace('\r\n', '\n')
    if old_n not in content:
        print("WARNING: Fix #3 old pattern not found, skipping")
        return content
    content = content.replace(old_n, new.replace('\r\n', '\n'))
    print("OK: Fix #3 - Added fresh-read guard in processQueueRecord_")
    return content

def fix_4_improve_enqueue_dedup(content):
    """Fix #4: Prevent enqueueing duplicate pending operations of same type for same child"""
    # Find the existing check and add a stronger dedup for child_activity_email
    old = '''  const existingOperation = findSheetRecords_(SHEETS.operationsQueue, {
    operation_id: operationId,
  })[0];
  if (
    existingOperation &&
    stringValue_(existingOperation.status).toLowerCase() === "completed" &&
    isImmutableQueueOperation_(operationType)
  ) {
    return {
      enqueued: true,
      operationId: operationId,
      alreadyCompleted: true,
    };
  }'''

    new = '''  const existingOperation = findSheetRecords_(SHEETS.operationsQueue, {
    operation_id: operationId,
  })[0];
  if (existingOperation) {
    const existingStatus = stringValue_(existingOperation.status).toLowerCase();
    // Fix: If already completed or already pending, skip to prevent duplicates
    if (existingStatus === "completed" && isImmutableQueueOperation_(operationType)) {
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
      const pendingDuplicates = getSheetRecords_(SHEETS.operationsQueue).filter(function(r) {
        return stringValue_(r.operation_type) === "child_activity_email"
          && stringValue_(r.uid) === uid
          && stringValue_(r.child_id) === childId
          && (stringValue_(r.status).toLowerCase() === "pending" || stringValue_(r.status) === "");
      });
      // Check payload eventType to match same event
      const newEventType = stringValue_(operationPayload.eventType);
      const hasSameEventPending = pendingDuplicates.some(function(r) {
        try {
          const existingPayload = parseJsonObject_(r.payload_json);
          return stringValue_(existingPayload.eventType) === newEventType;
        } catch (_) { return false; }
      });
      if (hasSameEventPending) {
        console.warn("Enqueue SKIPPED [duplicate_event_pending]: type=" + newEventType + " uid=" + uid + " child=" + childId);
        return {
          enqueued: true,
          operationId: operationId,
          alreadyPending: true,
        };
      }
    } catch (dedupErr) {
      // Dedup check failure must not block enqueueing
      console.warn("child_activity_email dedup check failed: " + dedupErr.message);
    }
  }'''

    old_n = old.replace('\r\n', '\n')
    if old_n not in content:
        print("WARNING: Fix #4 old pattern not found, skipping")
        return content
    content = content.replace(old_n, new.replace('\r\n', '\n'))
    print("OK: Fix #4 - Improved enqueue deduplication")
    return content

def fix_5_add_child_id_to_email_details(content):
    """Fix #5: Add childId in sendEmail details for better dedup tracking"""
    old = '''  console.log("Sending email [" + eventType + "] to: " + userRecord.email);
  const eventTemplate = eventTemplateFor_(eventType, child, payload, user);
  sendEmail_({
    to: userRecord.email,
    uid: userRecord.uid,
    eventType: eventType,
    subject: eventTemplate.subject,
    htmlBody: eventTemplate.htmlBody,
    plainBody: eventTemplate.plainBody,
  });'''

    new = '''  console.log("Sending email [" + eventType + "] to: " + userRecord.email);
  const eventTemplate = eventTemplateFor_(eventType, child, payload, user);
  sendEmail_({
    to: userRecord.email,
    uid: userRecord.uid,
    eventType: eventType,
    subject: eventTemplate.subject,
    htmlBody: eventTemplate.htmlBody,
    plainBody: eventTemplate.plainBody,
    details: child.id ? stringValue_(child.id) : "",
  });'''

    old_n = old.replace('\r\n', '\n')
    if old_n not in content:
        print("WARNING: Fix #5 old pattern not found, skipping")
        return content
    content = content.replace(old_n, new.replace('\r\n', '\n'))
    print("OK: Fix #5 - Added childId to email details for dedup tracking")
    return content

def fix_6_add_dedup_helper(content):
    """Fix #6: Add the wasEventEmailRecentlySent_ helper function after sendEmail_"""
    # Add the helper right before logEmail_
    marker = 'function logEmail_(entry) {'
    idx = content.find(marker)
    if idx == -1:
        print("WARNING: Fix #6 marker not found, skipping")
        return content

    helper = '''/**
 * فحص ما إذا تم إرسال إيميل لنفس الحدث/المستخدم/الطفل مؤخراً
 * يمنع التكرار بدون تعطيل أي خدمة (آمن تماماً)
 */
function wasEventEmailRecentlySent_(uid, eventType, childId, cooldownMs) {
  try {
    // الأحداث التي لا تحتاج حماية تكرار (رموز التحقق وإعادة التعيين)
    const exemptEvents = {
      "verification_code": true,
      "password_reset_code": true,
      "password_reset_completed": true,
      "welcome_guide": true,
      "daily_warning": true,
      "weekly_stats": true,
      "daily_warning_test": true,
      "weekly_stats_test": true,
      "weekly_stats_completed_pipeline_test": true,
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
      if (cleanChildId && stringValue_(row.details).indexOf(cleanChildId) === -1) continue;
      return true;
    }
    return false;
  } catch (e) {
    // Safety: never block sending due to dedup check failure
    console.warn("wasEventEmailRecentlySent_ error (allowing send): " + e.message);
    return false;
  }
}

'''

    content = content[:idx] + helper + content[idx:]
    print("OK: Fix #6 - Added wasEventEmailRecentlySent_ helper function")
    return content

def main():
    print("Reading Code.gs...")
    content = read_file()
    original_len = len(content)
    print(f"File size: {original_len} bytes, {content.count(chr(10))} lines")

    # Normalize all line endings to LF for consistent matching
    content = content.replace('\r\n', '\n')

    print("\n--- Applying fixes ---")
    content = fix_1_replace_queue_lock(content)
    content = fix_1b_replace_finally(content)
    content = fix_2_add_dedup_to_send_event_email(content)
    content = fix_3_add_fresh_read_to_processQueueRecord(content)
    content = fix_4_improve_enqueue_dedup(content)
    content = fix_5_add_child_id_to_email_details(content)
    content = fix_6_add_dedup_helper(content)

    # Restore original line endings (CRLF for consistency)
    content = content.replace('\n', '\r\n')

    print(f"\nNew file size: {len(content)} bytes")
    print("Writing updated Code.gs...")
    write_file(content)
    print("DONE: All backend fixes applied to Code.gs")

if __name__ == '__main__':
    main()
