import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_gym/main.dart';

void main() {
  testWidgets('FitPlan app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const FitPlanApp());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
