import 'package:flutter_test/flutter_test.dart';
import '../lib/repositories/map_repository.dart';

void main() {
  test('search test', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final r = MapRepository();
    await r.loadData();
    final res = r.searchUnits('tphcm');
    for (var result in res) {
      print('tphcm matched: ${result.unit.ten} (kind: ${result.matchKind.name}, label: ${result.matchLabel})');
    }
    
    final res2 = r.searchUnits('thành phố hà nội');
    print('thành phố hà nội count: ${res2.length}');
  });
}
