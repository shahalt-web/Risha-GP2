import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('showDialog inside builder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AlertDialog(title: Text('test')),
                  );
                },
                child: const Text('Tap'),
              );
            },
          );
        },
        home: const SizedBox(),
      ),
    );

    await tester.tap(find.text('Tap'));
    await tester.pumpAndSettle();
    expect(find.text('test'), findsOneWidget);
  });
}
