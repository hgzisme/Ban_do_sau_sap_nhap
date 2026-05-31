/// Data model representing an administrative unit (đơn vị hành chính).
///
/// Supports two GeoJSON schemas:
/// 1. Hugging Face `tmquan/sapnhap-bando-vn` (provinces/communes):
///    `{ "ten": "...", "type": "Tỉnh", "area_km2": ..., "population": ..., "density": ..., ... }`
class AdminUnit {
  final String ten;
  final String capHanhChinh; // "type" or "cap_hanh_chinh"
  final double dienTichKm2; // "area_km2" or "dien_tich_km2"
  final int danSo; // "population" or "dan_so"
  final double matDoRaw; // pre-computed "density" from data (0 if not present)

  // Extended fields from Hugging Face data
  final String? ma; // Mã đơn vị
  final String? capital; // Thủ phủ / trung tâm
  final String? decree; // Nghị quyết
  final String? predecessors; // Tiền thân (các đơn vị cũ)
  final String? macroRegion; // Vùng miền
  final String? parentTen; // Tên đơn vị cấp trên
  final String? parentMa; // Mã đơn vị cấp trên
  final double? centerLat; // Tọa độ trung tâm (vĩ độ)
  final double? centerLng; // Tọa độ trung tâm (kinh độ)

  const AdminUnit({
    required this.ten,
    required this.capHanhChinh,
    required this.dienTichKm2,
    required this.danSo,
    this.matDoRaw = 0,
    this.ma,
    this.capital,
    this.decree,
    this.predecessors,
    this.macroRegion,
    this.parentTen,
    this.parentMa,
    this.centerLat,
    this.centerLng,
  });

  /// Mật độ dân số (người/km²). Prefers pre-computed value, else computes.
  double get matDo {
    if (matDoRaw > 0) return matDoRaw;
    return dienTichKm2 > 0 ? danSo / dienTichKm2 : 0;
  }

  String? get coordinateSummary {
    if (centerLat == null || centerLng == null) return null;
    return 'Tọa độ: ${centerLat!.toStringAsFixed(5)}, ${centerLng!.toStringAsFixed(5)}';
  }

  /// Parse from GeoJSON feature properties (auto-detects schema).
  factory AdminUnit.fromJson(
    Map<String, dynamic> json, {
    double? centerLat,
    double? centerLng,
  }) {
    // Detect which schema: HuggingFace uses "type", legacy uses "cap_hanh_chinh"
    // The islands use "name_special_unit" or we can default to "Quần đảo"
    String cap =
        (json['type'] as String?) ??
        (json['cap_hanh_chinh'] as String?) ??
        (json['name_special_unit'] as String?) ??
        'Không rõ';

    if (json['is_archipelago'] == true && cap == 'Không rõ') {
      cap = 'Quần đảo';
    }

    final double area =
        (json['area_km2'] as num?)?.toDouble() ??
        (json['dien_tich_km2'] as num?)?.toDouble() ??
        0.0;

    final int pop =
        (json['population'] as num?)?.toInt() ??
        (json['dan_so'] as num?)?.toInt() ??
        0;

    final double density = (json['density'] as num?)?.toDouble() ?? 0.0;

    final double? parsedCenterLat =
        centerLat ??
        (json['center_lat'] as num?)?.toDouble() ??
        (json['latitude'] as num?)?.toDouble();
    final double? parsedCenterLng =
        centerLng ??
        (json['center_lng'] as num?)?.toDouble() ??
        (json['longitude'] as num?)?.toDouble();

    // Handle NaN strings from JSON
    String? parseStr(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      if (s == 'NaN' || s == 'null' || s.isEmpty) return null;
      return s;
    }

    // Ten can be "ten" or "shapeName" (for islands)
    final String ten =
        (json['ten'] as String?) ??
        (json['shapeName'] as String?) ??
        'Không rõ';

    // macro_region is empty for islands, we can infer from admin_post_merger
    String? macroRegion = parseStr(json['macro_region']);
    if (json['is_archipelago'] == true) {
      if (ten.contains('Hoàng Sa')) macroRegion = 'central_coast';
      if (ten.contains('Trường Sa')) macroRegion = 'central_coast';
    }

    return AdminUnit(
      ten: ten,
      capHanhChinh: cap,
      dienTichKm2: area,
      danSo: pop,
      matDoRaw: density,
      ma: parseStr(json['ma']),
      capital: parseStr(json['capital']),
      decree: parseStr(json['decree']),
      predecessors: parseStr(json['predecessors']),
      macroRegion: macroRegion,
      parentTen:
          parseStr(json['parent_ten']) ?? parseStr(json['admin_post_merger']),
      parentMa: parseStr(json['parent_ma']),
      centerLat: parsedCenterLat,
      centerLng: parsedCenterLng,
    );
  }

  @override
  String toString() => 'AdminUnit($ten, $capHanhChinh)';
}
