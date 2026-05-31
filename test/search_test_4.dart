import 'package:flutter_test/flutter_test.dart';
import '../lib/repositories/map_repository.dart';

void main() {
  test('search test', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final r = MapRepository();
    await r.loadData();

    String sanitizeQuery(String query) {
      var q = MapRepository.removeDiacritics(query.toLowerCase().trim());
      final prefixes = [
        'thanh pho ',
        'tp ',
        'tp. ',
        'tinh ',
        'quan ',
        'huyen ',
        'thi xa ',
        'tx ',
        'tx. ',
        'phuong ',
        'xa ',
        'thi tran ',
        'tt ',
        'tt. ',
      ];
      for (final prefix in prefixes) {
        if (q.startsWith(prefix)) {
          q = q.substring(prefix.length).trim();
          break;
        }
      }
      return q;
    }

    print('Sanitized "thành phố hà nội": ${sanitizeQuery('thành phố hà nội')}');
    print('Sanitized "Quận 1": ${sanitizeQuery('Quận 1')}');
    print('Sanitized "Tp. Hồ Chí Minh": ${sanitizeQuery('Tp. Hồ Chí Minh')}');
    print('Sanitized "TX. Dĩ An": ${sanitizeQuery('TX. Dĩ An')}');

    // Test if q='1' matches Quận 1
    final q1 = '1';
    var found1 = 0;
    for (final unit in r.communes) {
      final name = MapRepository.removeDiacritics(unit.ten.toLowerCase());
      if (name.startsWith(q1)) {
        found1++;
      }
    }
    print('Found communes starting with "1": $found1');
  });
}
