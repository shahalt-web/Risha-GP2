import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:risha_v01/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const RishaApp());
}
