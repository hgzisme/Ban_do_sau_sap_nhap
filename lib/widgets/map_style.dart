import 'package:flutter/material.dart';
import '../models/admin_unit.dart';
import '../repositories/map_repository.dart';

const Map<String, Color> categoryColors = {
  'Thành phố': Color(0xFFFF6B6B),
  'Tỉnh': Color(0xFF4ECDC4),
  'Thủ đô': Color(0xFFFFE66D),
  'Phường': Color(0xFFA29BFE),
  'Xã': Color(0xFF55EFC4),
  'Đặc khu': Color(0xFFFFA502),
  'Thành phố trực thuộc TW': Color(0xFFFF6B6B),
  'Quận': Color(0xFFA29BFE),
  'Huyện': Color(0xFF55EFC4),
  'Thị xã': Color(0xFFFFA502),
  'Thị trấn': Color(0xFFD4A574),
  'Quần đảo': Color(0xFF74B9FF),
};

/// Display order for the sidebar type legend (province + commune levels).
const List<String> typeLegendOrder = [
  'Thủ đô',
  'Thành phố',
  'Tỉnh',
  'Phường',
  'Xã',
  'Đặc khu',
];

const Map<String, Color> regionColors = {
  'northern_midlands': Color(0xFF1F4E79),
  'central_coast': Color(0xFFC57B15),
  'red_river_delta': Color(0xFF4C8A14),
  'mekong_delta': Color(0xFF79BA13),
  'southeast': Color(0xFF000000),
  'central_highlands': Color(0xFF7A4F32),
};

const Map<String, String> regionNames = {
  'northern_midlands': 'Trung du và miền núi phía Bắc',
  'central_coast': 'Bắc Trung Bộ & Duyên hải miền Trung',
  'red_river_delta': 'Đồng bằng sông Hồng',
  'mekong_delta': 'Đồng bằng sông Cửu Long',
  'southeast': 'Đông Nam Bộ',
  'central_highlands': 'Tây Nguyên',
};

Color colorForCategory(String cap) {
  return categoryColors[cap] ?? const Color(0xFF90A4AE);
}

Color colorForRegion(String? region) {
  if (region == null) return const Color(0xFF546E7A);
  return regionColors[region] ?? const Color(0xFF546E7A);
}

String regionDisplayName(String? region) {
  if (region == null) return 'Không rõ';
  return regionNames[region] ?? region;
}

Color colorForUnit(AdminUnit unit, ColorMode colorMode) {
  if (colorMode == ColorMode.byRegion) {
    return colorForRegion(unit.macroRegion);
  }
  return colorForCategory(unit.capHanhChinh);
}
 
