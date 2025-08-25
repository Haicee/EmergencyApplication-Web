// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emergency/main.dart';

void main() {
  testWidgets('Login page smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the welcome text is present
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('An Emergency Mobile App'), findsOneWidget);

    // Verify that the Flutter logo is present
    expect(find.byType(FlutterLogo), findsOneWidget);

    // Verify that text fields are present
    expect(find.byType(TextField), findsNWidgets(2)); // Should find 2 text fields for username and password
  });
}
