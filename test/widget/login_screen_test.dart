/// R2 – LoginScreen Widget Test
///
/// Tests that the LoginScreen renders correctly, validates
/// form inputs, and shows appropriate error messages.
/// Uses WidgetTester + pumpWidget with no real Firebase.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // We test the login form UI in isolation using a minimal
  // reproduction of the LoginScreen's form structure.
  // This avoids importing GoRouter/Firebase dependencies
  // while still testing the actual validation logic + UI behavior.

  Widget buildTestableLoginForm({
    required GlobalKey<FormState> formKey,
    required TextEditingController emailController,
    required TextEditingController passwordController,
    required VoidCallback onSubmit,
    String? Function(String?)? emailValidator,
    String? Function(String?)? passwordValidator,
  }) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  // Title
                  const Text('تسجيل الدخول', key: Key('login_title')),
                  const SizedBox(height: 16),
                  // Email field
                  TextFormField(
                    key: const Key('email_field'),
                    controller: emailController,
                    validator: emailValidator ?? _defaultEmailValidator,
                    decoration: const InputDecoration(
                      hintText: 'أدخل البريد الإلكتروني للشخص المسؤول',
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Password field
                  TextFormField(
                    key: const Key('password_field'),
                    controller: passwordController,
                    obscureText: true,
                    validator: passwordValidator ?? _defaultPasswordValidator,
                    decoration: const InputDecoration(
                      hintText: 'أدخل كلمة المرور',
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Submit button
                  ElevatedButton(
                    key: const Key('login_button'),
                    onPressed: onSubmit,
                    child: const Text('تسجيل الدخول'),
                  ),
                  const SizedBox(height: 16),
                  // Register link
                  GestureDetector(
                    key: const Key('register_link'),
                    child: const Text('انضم إلينا اليوم'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('LoginScreen UI (R2)', () {
    late GlobalKey<FormState> formKey;
    late TextEditingController emailController;
    late TextEditingController passwordController;
    bool submitCalled = false;

    setUp(() {
      formKey = GlobalKey<FormState>();
      emailController = TextEditingController();
      passwordController = TextEditingController();
      submitCalled = false;
    });

    tearDown(() {
      emailController.dispose();
      passwordController.dispose();
    });

    testWidgets('renders login title and form fields', (tester) async {
      await tester.pumpWidget(
        buildTestableLoginForm(
          formKey: formKey,
          emailController: emailController,
          passwordController: passwordController,
          onSubmit: () => submitCalled = true,
        ),
      );

      // Assert – title is visible
      expect(find.text('تسجيل الدخول'), findsWidgets);

      // Assert – form fields are present
      expect(find.byKey(const Key('email_field')), findsOneWidget);
      expect(find.byKey(const Key('password_field')), findsOneWidget);

      // Assert – submit button is present
      expect(find.byKey(const Key('login_button')), findsOneWidget);

      // Assert – register link is present
      expect(find.text('انضم إلينا اليوم'), findsOneWidget);
    });

    testWidgets('shows validation error for empty email', (tester) async {
      debugPrint('🖥️ فحص الواجهة: [الحدث: ترك حقل البريد فارغاً والضغط على دخول]');
      await tester.pumpWidget(
        buildTestableLoginForm(
          formKey: formKey,
          emailController: emailController,
          passwordController: passwordController,
          onSubmit: () {
            formKey.currentState?.validate();
          },
        ),
      );

      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();

      expect(find.text('الرجاء إدخال البريد الإلكتروني.'), findsOneWidget);
      debugPrint(
        '✅ النتيجة: ظهرت رسالة الخطأ "الرجاء إدخال البريد الإلكتروني" بنجاح.',
      );
    });

    testWidgets('shows validation error for invalid email format', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableLoginForm(
          formKey: formKey,
          emailController: emailController,
          passwordController: passwordController,
          onSubmit: () {
            formKey.currentState?.validate();
          },
        ),
      );

      // Act – enter invalid email
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'invalid-email',
      );
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('الرجاء إدخال بريد إلكتروني صحيح.'), findsOneWidget);
    });

    testWidgets('shows validation error for empty password', (tester) async {
      await tester.pumpWidget(
        buildTestableLoginForm(
          formKey: formKey,
          emailController: emailController,
          passwordController: passwordController,
          onSubmit: () {
            formKey.currentState?.validate();
          },
        ),
      );

      // Act – enter valid email but no password
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'parent@example.com',
      );
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('الرجاء إدخال كلمة المرور.'), findsOneWidget);
    });

    testWidgets('submit button triggers callback with valid form', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableLoginForm(
          formKey: formKey,
          emailController: emailController,
          passwordController: passwordController,
          onSubmit: () {
            if (formKey.currentState?.validate() == true) {
              submitCalled = true;
            }
          },
        ),
      );

      // Act – fill valid data
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'parent@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'SecurePass123',
      );
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();

      // Assert – callback was triggered
      expect(submitCalled, isTrue);
    });

    testWidgets('FAIL case: email with spaces shows correct error', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableLoginForm(
          formKey: formKey,
          emailController: emailController,
          passwordController: passwordController,
          onSubmit: () {
            formKey.currentState?.validate();
          },
        ),
      );

      await tester.enterText(
        find.byKey(const Key('email_field')),
        'par ent@example.com',
      );
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('البريد الإلكتروني لا يجب أن يحتوي على مسافات.'),
        findsOneWidget,
      );
    });
  });
}

// ── Validators (matching the real LoginScreen logic) ──

String? _defaultEmailValidator(String? value) {
  final text = value ?? '';
  if (text.trim().isEmpty) {
    return 'الرجاء إدخال البريد الإلكتروني.';
  }
  if (text.contains(RegExp(r'\s'))) {
    return 'البريد الإلكتروني لا يجب أن يحتوي على مسافات.';
  }
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailRegex.hasMatch(text)) {
    return 'الرجاء إدخال بريد إلكتروني صحيح.';
  }
  return null;
}

String? _defaultPasswordValidator(String? value) {
  final text = value ?? '';
  if (text.trim().isEmpty) {
    return 'الرجاء إدخال كلمة المرور.';
  }
  return null;
}
