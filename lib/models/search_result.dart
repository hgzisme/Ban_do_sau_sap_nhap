import 'admin_unit.dart';
import 'map_detail_level.dart';

enum SearchMatchKind { name, predecessor }

class SearchResult {
  final AdminUnit unit;
  final MapDetailLevel level;
  final SearchMatchKind matchKind;
  final String matchLabel;

  const SearchResult({
    required this.unit,
    required this.level,
    required this.matchKind,
    required this.matchLabel,
  });
}
