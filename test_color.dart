import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'dart:typedData';

void main() {
  final source = MapShapeSource.memory(
    Uint8List(0),
    shapeDataField: 'id',
    dataCount: 1,
    primaryValueMapper: (i) => '1',
    shapeColorValueMapper: (i) => Colors.red,
  );
  print(source.shapeColorValueMapper!(0) is Color);
}
