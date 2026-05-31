import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('assets/provinces_simplified.geojson');
  final jsonStr = file.readAsStringSync();
  final data = json.decode(jsonStr);
  final features = data['features'] as List;

  final regions = <String>{};
  for (final f in features) {
    final props = f['properties'];
    if (props['macro_region'] != null) {
      regions.add(props['macro_region']);
    }
  }
  print(regions.join(', '));
}
