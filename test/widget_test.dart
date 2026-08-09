import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:social_hub_flutter/src/widgets/app_logo.dart';

void main() {
  testWidgets('AppLogo renders in widget tree', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppLogo(),
          ),
        ),
      ),
    );

    expect(find.byType(AppLogo), findsOneWidget);
  });
}
