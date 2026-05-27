import 'dart:io';

void main() async {
  final files = ['assets/provinces.geojson', 'assets/communes.json'];
  for (final path in files) {
    final file = File(path);
    final content = await file.readAsString();
    final index = content.indexOf('rent_ma": NaN');
    if (index != -1) {
      print('Found in $path at index $index');
      print(content.substring(index - 20, index + 30));
    } else {
      print('Not found in $path');
    }
  }
}
