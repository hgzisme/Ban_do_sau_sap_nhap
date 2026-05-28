// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  final files = ['assets/provinces.geojson', 'assets/communes.json'];
  final regex = RegExp(r':\s*NaN\b');
  
  for (final path in files) {
    print('Processing $path...');
    final file = File(path);
    if (!await file.exists()) {
      print('File not found: $path');
      continue;
    }
    
    var content = await file.readAsString();
    int count = 0;
    content = content.replaceAllMapped(regex, (match) {
      count++;
      return ': null';
    });
    
    await file.writeAsString(content);
    print('Replaced $count occurrences in $path');
  }
  print('Done!');
}
