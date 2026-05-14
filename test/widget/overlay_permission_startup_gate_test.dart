import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:risha_v01/shared/widgets/overlay_permission_startup_gate.dart';

void main() {
  testWidgets('shows the digital balance overlay permission prompt on startup', (
    tester,
  ) async {
    var openSettingsCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: OverlayPermissionStartupGate(
          isPermissionGranted: () async => false,
          openPermissionSettings: () async {
            openSettingsCount++;
          },
          child: const SizedBox(key: Key('app_content')),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('overlay_permission_prompt')), findsOneWidget);
    expect(
      find.byKey(const Key('overlay_permission_risha_image')),
      findsOneWidget,
    );
    expect(
      find.text(
        'يرجى السماح لتطبيق ريشه بالظهور فوق التطبيقات حتى تعمل ميزه التوازن الرقمي بشكل صحيح',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('overlay_permission_allow_button')));
    await tester.pump();

    expect(openSettingsCount, 1);
  });

  testWidgets('does not show the prompt when overlay permission is granted', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OverlayPermissionStartupGate(
          isPermissionGranted: () async => true,
          openPermissionSettings: () async {},
          child: const SizedBox(key: Key('app_content')),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('app_content')), findsOneWidget);
    expect(find.byKey(const Key('overlay_permission_prompt')), findsNothing);
  });

  testWidgets('closes the prompt after permission is granted and app resumes', (
    tester,
  ) async {
    var granted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OverlayPermissionStartupGate(
          isPermissionGranted: () async => granted,
          openPermissionSettings: () async {},
          child: const SizedBox(key: Key('app_content')),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('overlay_permission_prompt')), findsOneWidget);

    granted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('overlay_permission_prompt')), findsNothing);
  });
}
