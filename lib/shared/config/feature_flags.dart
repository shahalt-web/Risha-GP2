class FeatureFlags {
  const FeatureFlags._();

  // مفتاح تصحيح مؤقت: يعطل تدفق قفل السكون الأصلي في أندرويد.
  static const bool disableSleepLockTemporarily = false;

  // مفتاح تصحيح مؤقت: يبقي بطاقات المهام اليومية تفاعلية لمراجعة واجهة المستخدم.
  // اضبطه على false لاستعادة تعطيل البطاقات بناءً على الوقت/الإنجاز بشكل طبيعي.
  static const bool keepDailyCardsEnabledTemporarily = false;

  // مفتاح تصحيح مؤقت: يتجاوز قيود إكمال المهام اليومية بحيث يمكن اختبار جميع البطاقات.
  // عندما يكون true، لا تعيد الشاشات المكتملة تلقائياً الطفل إلى الشاشة الرئيسية اليومية.
  static const bool bypassDailyTaskCompletionRestrictionsTemporarily = false;

  // مفتاح تصحيح مؤقت: لاختبار ميزة راحة الاستخدام بسرعة.
  // عندما يكون true ستظهر نافذة الراحة بعد مدة الاختبار من دخول
  // واجهة الطفل الرئيسية اليومية (/child-home/daily-home)
  // بدلاً من انتظار حساب ساعتين من استخدام الجهاز.
  // لإلغاء وضع الاختبار بسرعة: اضبطه على false.
  static const bool enableUsageRestQuickTestMode = false;

  // مدة الانتظار في وضع الاختبار السريع قبل إظهار نافذة الراحة.
  static const Duration usageRestQuickTestDelay = Duration(minutes: 10);
}
