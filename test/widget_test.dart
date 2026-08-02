import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinu/main.dart';

void main() {
  testWidgets('Shows daily summary and meals', (WidgetTester tester) async {
    await tester.pumpWidget(const SiNuApp());
    expect(find.text('TODAY'), findsOneWidget);

    final mealFinder = find.text('Meal 1');
    await tester.dragUntilVisible(
      mealFinder,
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(mealFinder, findsOneWidget);
  });
}
