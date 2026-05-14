class AppsScriptEmailConfig {
  const AppsScriptEmailConfig._();

  static const String webAppUrl =
      //رابط الخدمة الرئيسي
      //"https://script.google.com/macros/s/AKfycbxZQM6va_m3rv82v6a3Z8RiS3MPe_QOmaOAEDMWnVQMub8Bm1-C6bMkdXmdlarP2SBBTA/exec"
      //الرابط الخدمة الاحتياطي
      "https://script.google.com/macros/s/AKfycbyg00GCxtn_3E9M_FlmdnObYMvVy1KzBrRxLau8JohacUZHvSzUW6mpOlfdL47QRq8o/exec";
  static const String sharedSecret =
      'EBMSMTheBestNoOnCanDefatMeEverNever-that-I-create-this-pro-app';
  static const String timeZone = 'Asia/Aden';
  static const Duration requestTimeout = Duration(seconds: 45);

  static bool get isConfigured =>
      webAppUrl.trim().isNotEmpty && sharedSecret.trim().isNotEmpty;
}
