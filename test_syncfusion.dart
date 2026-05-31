import 'dart:convert';
import 'dart:io';
// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_maps/maps.dart';

void main() {
  testWidgets('Test Syncfusion check dataIndex', (WidgetTester tester) async {
    final file = File('assets/provinces_simplified.geojson');
    final raw = file.readAsStringSync();
    final geoJson = json.decode(raw);

    final source = MapShapeSource.memory(
      file.readAsBytesSync(),
      shapeDataField: 'ma',
      dataCount: 34,
      primaryValueMapper: (int index) {
        final props = geoJson['features'][index]['properties'];
        return props['ma'];
      },
    );

    // Create a scaffold
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SfMaps(
            layers: [MapShapeLayer(source: source, selectedIndex: -1)],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    print("Done");
  });
}
