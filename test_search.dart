import 'dart:convert';
import 'dart:io';
import 'lib/repositories/map_repository.dart';

void main() async {
  final r = MapRepository();
  await r.loadData();
  final res = r.searchUnits('can tho');
  print('Found: ${res.length}');
}
