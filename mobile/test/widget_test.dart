// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_overdose_detector/main.dart';

void main() {
  testWidgets('App renders login screen correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartOverdoseDetectorApp());

    // Verify that our app starts at LoginScreen and displays Bienvenido.
    expect(find.text('Smart Overdose Detector'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.text('¿Aún no tienes cuenta?'), findsOneWidget);
  });
}

