import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vietnam_merged_map/models/admin_unit.dart';
import 'package:vietnam_merged_map/models/map_detail_level.dart';
import 'package:vietnam_merged_map/models/search_result.dart';
import 'package:vietnam_merged_map/repositories/map_repository.dart';
import 'package:vietnam_merged_map/widgets/map_search_overlay.dart';

class _FakeMapRepository extends MapRepository {
  _FakeMapRepository(this.results);

  final List<SearchResult> results;

  @override
  List<SearchResult> searchUnits(String query, {int limit = 20}) {
    return results;
  }
}

void main() {
  testWidgets('selected search result replaces the input text', (
    WidgetTester tester,
  ) async {
    final selected = AdminUnit(
      ten: 'Tỉnh Khánh Hòa',
      capHanhChinh: 'Tỉnh',
      dienTichKm2: 5000,
      danSo: 1000000,
      ma: 'KH',
    );
    final repo = _FakeMapRepository([
      SearchResult(
        unit: selected,
        level: MapDetailLevel.provinces,
        matchKind: SearchMatchKind.name,
        matchLabel: selected.ten,
      ),
    ]);

    SearchResult? picked;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapSearchOverlay(
            repository: repo,
            onResultSelected: (result) => picked = result,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Khánh');
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Tỉnh Khánh Hòa'));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, 'Tỉnh Khánh Hòa');
    expect(picked?.unit.ten, 'Tỉnh Khánh Hòa');
  });

  testWidgets('reset token clears stale search state', (
    WidgetTester tester,
  ) async {
    final repo = _FakeMapRepository(const []);

    var resetToken = 0;
    late StateSetter setState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, updateState) {
            setState = updateState;
            return Scaffold(
              body: MapSearchOverlay(
                repository: repo,
                resetToken: resetToken,
                onResultSelected: (_) {},
              ),
            );
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Khánh Hòa');
    await tester.pump();

    setState(() {
      resetToken++;
    });
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, isEmpty);
  });
}
