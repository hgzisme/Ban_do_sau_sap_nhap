import 'package:flutter_test/flutter_test.dart';
import '../lib/repositories/map_repository.dart';

void main() {
  test('search test', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final r = MapRepository();
    await r.loadData();
    print('ho chi minh: ${r.searchUnits('ho chi minh').length}');
    print('da nang: ${r.searchUnits('da nang').length}');
    print('tphcm: ${r.searchUnits('tphcm').length}');
    print('tp hcm: ${r.searchUnits('tp hcm').length}');
  });
}
 
