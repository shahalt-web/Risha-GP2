import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:risha_v01/shared/config/apps_script_email_config.dart';

void main() async {
  final url = AppsScriptEmailConfig.webAppUrl;
  final secret = AppsScriptEmailConfig.sharedSecret;

  final payload = {
    'secret': secret,
    'action': 'verify_password_reset_code',
    'payload': {'email': 'basemmunassar@gmail.com', 'code': '123456'},
  };

  // ignore: avoid_print
  print('Sending request...');
  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );

  // ignore: avoid_print
  print('Status: ${response.statusCode}');
  // ignore: avoid_print
  print('Body: ${response.body}');
}
