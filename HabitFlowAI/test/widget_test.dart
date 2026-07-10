import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitflowai/main.dart';

void main() {
  testWidgets('app shows habits screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HabitFlowApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('habit dialog shows color choices', (WidgetTester tester) async {
    await tester.pumpWidget(const HabitFlowApp());
    await tester.pump();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(find.text('Color'), findsOneWidget);
  });

  test('habit reminders serialize with notification and alarm flags', () {
    final habit = HabitItem(
      id: '1',
      title: 'Hydrate',
      notificationEnabled: true,
      alarmEnabled: true,
      reminderTime: '08:30',
    );

    final json = habit.toJson();
    final restored = HabitItem.fromJson(json);

    expect(json['notificationEnabled'], isTrue);
    expect(json['alarmEnabled'], isTrue);
    expect(json['reminderTime'], '08:30');
    expect(restored.notificationEnabled, isTrue);
    expect(restored.alarmEnabled, isTrue);
    expect(restored.reminderTime, '08:30');
  });
}
