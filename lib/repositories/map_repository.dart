import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show compute;
import '../models/admin_unit.dart';

/// Enum for the two geographic data layers.
enum MapLayer {
  provinces, // 34 tỉnh/thành phố
  communes,  // 3321 phường/xã
}

/// Enum for map coloring mode.
enum ColorMode {
  byType,     // Color by administrative type (Tỉnh, Thành phố, Phường, Xã)
  byRegion,   // Color by macro region (Bắc Trung Bộ, ĐBSCL, etc.)
}

/// Repository to load and parse the local GeoJSON assets from
/// Hugging Face `tmquan/sapnhap-bando-vn`.
///
/// Manages two layers (provinces & communes) and provides filtering
/// and global statistics. Uses Isolate-based parsing via `compute()`
/// to avoid blocking the main UI thread with the 178MB communes file.
class MapRepository {
  List<AdminUnit> _provinces = [];
  List<AdminUnit> _communes = [];

  /// Current active layer.
  MapLayer _activeLayer = MapLayer.provinces;
  MapLayer get activeLayer => _activeLayer;

  List<AdminUnit> get provinces => _provinces;
  List<AdminUnit> get communes => _communes;

  /// Returns units for the currently active layer.
  List<AdminUnit> get activeUnits =>
      _activeLayer == MapLayer.provinces ? _provinces : _communes;

  /// The GeoJSON asset path for the active layer.
  String get activeAssetPath => _activeLayer == MapLayer.provinces
      ? 'assets/provinces.geojson'
      : 'assets/communes.geojson';

  /// Load provinces eagerly on startup. Communes are lazy-loaded.
  Future<List<AdminUnit>> loadData() async {
    final raw = await rootBundle.loadString('assets/provinces.geojson');
    _provinces = await compute(_parseGeoJsonIsolate, raw);
    _activeLayer = MapLayer.provinces;
    return _provinces;
  }

  /// Switch active layer. Lazy-loads communes on first access using
  /// a background Isolate so the UI stays responsive.
  Future<List<AdminUnit>> switchLayer(MapLayer layer) async {
    if (layer == MapLayer.communes && _communes.isEmpty) {
      final raw = await rootBundle.loadString('assets/communes.geojson');
      _communes = await compute(_parseGeoJsonIsolate, raw);
    }
    _activeLayer = layer;
    return activeUnits;
  }

  /// Get all unique administrative levels present in the active data.
  Set<String> getAllCategories() {
    return activeUnits
        .map((u) => u.capHanhChinh)
        .where((c) => c.isNotEmpty && c != 'Không rõ')
        .toSet();
  }

  /// Get all unique macro regions present in the active data.
  Set<String> getAllRegions() {
    return activeUnits
        .map((u) => u.macroRegion)
        .where((r) => r != null && r.isNotEmpty)
        .cast<String>()
        .toSet();
  }

  /// Filter active units by a set of active categories.
  List<AdminUnit> getByCategories(Set<String> activeCategories) {
    if (activeCategories.isEmpty) return activeUnits;
    return activeUnits
        .where((u) => activeCategories.contains(u.capHanhChinh))
        .toList();
  }

  /// Search units by name (partial, case-insensitive).
  List<AdminUnit> search(String query) {
    if (query.isEmpty) return activeUnits;
    final q = query.toLowerCase();
    return activeUnits.where((u) => u.ten.toLowerCase().contains(q)).toList();
  }

  // ─── Global Statistics ───────────────────────────────────────────

  /// Total area of the given list of units (km²).
  double tongDienTich([List<AdminUnit>? subset]) {
    final list = subset ?? activeUnits;
    return list.fold<double>(0, (sum, u) => sum + u.dienTichKm2);
  }

  /// Total population of the given list of units.
  int tongDanSo([List<AdminUnit>? subset]) {
    final list = subset ?? activeUnits;
    return list.fold<int>(0, (sum, u) => sum + u.danSo);
  }

  /// Average population density (people/km²).
  double matDoTrungBinh([List<AdminUnit>? subset]) {
    final dt = tongDienTich(subset);
    if (dt <= 0) return 0;
    return tongDanSo(subset) / dt;
  }
}

/// Top-level function for Isolate-based GeoJSON parsing.
/// Must be a top-level or static function for `compute()`.
List<AdminUnit> _parseGeoJsonIsolate(String raw) {
  // Sanitize NaN values (invalid JSON from HuggingFace dataset)
  raw = raw.replaceAll(RegExp(r':\s*NaN\b'), ': null');
  final Map<String, dynamic> geoJson = json.decode(raw);
  final List features = geoJson['features'] as List;
  return features.map((f) {
    final props = f['properties'] as Map<String, dynamic>;
    return AdminUnit.fromJson(props);
  }).toList();
}
