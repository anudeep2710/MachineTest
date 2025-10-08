import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Renders simple text widget', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Text('Hello, Team Scheduler')),
    ));

    expect(find.text('Hello, Team Scheduler'), findsOneWidget);
  });
}
