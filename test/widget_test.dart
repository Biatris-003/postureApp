import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_posture_app/main.dart';

void main() {
  testWidgets('App compiles and shows login screen initially', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SmartPostureApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
  });
}
