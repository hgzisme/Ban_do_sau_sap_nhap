import 'dart:io';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart fix_mapshaper_json.dart <path-to-your-downloaded-json-file>');
    return;
  }
  
  final file = File(args.first);
  if (!await file.exists()) {
    print('Error: File not found!');
    return;
  }
  
  print('Reading ${file.path}...');
  var content = await file.readAsString();
  
  print('Cleaning NaN values...');
  content = content.replaceAll(': NaN', ': null');
  
  final newPath = file.path.replaceAll('.json', '_fixed.json').replaceAll('.geojson', '_fixed.geojson');
  await File(newPath).writeAsString(content);
  
  print('Done! Clean file saved as: $newPath');
  print('You can now drag this fixed file into mapshaper.org!');
}
