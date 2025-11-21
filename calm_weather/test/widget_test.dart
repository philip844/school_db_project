// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:calm_weather/main.dart';

void main() {
  testWidgets('WeatherApp renders AuthScreen initially', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WeatherApp());

    // Initially, user is not logged in, so AuthScreen should be shown
    expect(find.byType(AuthScreen), findsOneWidget);
  });
}
