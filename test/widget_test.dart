// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vietnam_merged_map/main.dart';
import 'package:vietnam_merged_map/models/admin_unit.dart';
import 'package:vietnam_merged_map/widgets/detail_panel_widget.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Detail panel shows coordinates in thủ phủ row', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetailPanelWidget(
            unit: const AdminUnit(
              ten: 'Hà Nội',
              capHanhChinh: 'Tỉnh',
              dienTichKm2: 3359.0,
              danSo: 8400000,
              capital: 'Hà Nội',
              centerLat: 21.02851,
              centerLng: 105.85420,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Hà Nội'), findsWidgets);
    expect(find.textContaining('Tọa độ'), findsOneWidget);
    expect(find.textContaining('21.02851, 105.85420'), findsOneWidget);
  });
}
