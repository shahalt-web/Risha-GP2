import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:risha_v01/shared/widgets/overlay_permission_startup_gate.dart';

void main() {
  testWidgets('shows dialog when placed in MaterialApp.builder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return OverlayPermissionStartupGate(
            isPermissionGranted: () async => false,
            openPermissionSettings: () async {},
            child: child ?? const SizedBox(),
          );
        },
        home: const Scaffold(body: Text('Home')),
      ),
    );

    await tester.pump();
    await tester.pump();
    
    expect(find.byKey(const Key('overlay_permission_prompt')), findsOneWidget);
  });
}
