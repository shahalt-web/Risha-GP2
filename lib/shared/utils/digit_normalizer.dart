class DigitNormalizer {
  DigitNormalizer._();

  static const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  static const _englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

  static String normalize(String input) {
    var result = input;
    for (var i = 0; i < _arabicDigits.length; i++) {
      result = result.replaceAll(_arabicDigits[i], _englishDigits[i]);
    }
    return result;
  }
}
