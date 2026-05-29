import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/admin_unit.dart';
import '../models/geo_bounds.dart';
import '../models/map_detail_level.dart';
import '../models/search_result.dart';

/// Enum for the two geographic data layers.
enum MapLayer {
  provinces,
  communes,
}

/// Enum for map coloring mode (legacy, used by map_widget).
enum ColorMode {
  byType,
  byRegion,
}

/// Enum for Choropleth data visualization mode.
enum MapDataMode {
  none,
  population,
  density,
  area,
  macroRegion,
}


/// Snapshot of map LOD state for UI badges.
class MapDetailState {
  final MapDetailLevel level;
  final int visibleUnitCount;
  final bool isRefreshing;

  const MapDetailState({
    required this.level,
    required this.visibleUnitCount,
    this.isRefreshing = false,
  });
}

/// Repository to load and parse the local GeoJSON assets from
/// Hugging Face `tmquan/sapnhap-bando-vn`.
class MapRepository {
  List<AdminUnit> _provinces = [];
  List<AdminUnit> _communes = [];
  Map<String, GeoBounds> _provinceBounds = {};
  Map<String, GeoBounds> _communeBoundsByMa = {};
  Map<String, List<AdminUnit>> _communesByParentMa = {};
  Map<String, List<String>> _rawFeatureStringsByParentMa = {};
  String? _provinceGeoJson;

  MapLayer _activeLayer = MapLayer.provinces;
  MapLayer get activeLayer => _activeLayer;

  List<AdminUnit> get provinces => _provinces;
  List<AdminUnit> get communes => _communes;
  Map<String, GeoBounds> get provinceBounds => _provinceBounds;
  String get provinceGeoJson =>
      _provinceGeoJson ?? '{"type":"FeatureCollection","features":[]}';
  bool get communesIndexed => _communesByParentMa.isNotEmpty;
  bool get isLoaded => _provinces.isNotEmpty;

  int maxProvincePopulation = 0;
  int minProvincePopulation = 0;
  double maxProvinceDensity = 0.0;
  double minProvinceDensity = 0.0;
  double maxProvinceArea = 0.0;
  double minProvinceArea = 0.0;

  List<AdminUnit> get activeUnits =>
      _activeLayer == MapLayer.provinces ? _provinces : _communes;

  String get activeAssetPath => _activeLayer == MapLayer.provinces
      ? 'assets/provinces.geojson'
      : 'assets/communes.json';

  Future<List<AdminUnit>> loadData() async {
    final raw = await rootBundle.loadString('assets/provinces.geojson');
    final Map<String, dynamic> geoJson = json.decode(raw);
    final List features = geoJson['features'] as List;

    _provinces = [];
    _provinceBounds = {};
    for (final feature in features) {
      final map = feature as Map<String, dynamic>;
      final props = map['properties'] as Map<String, dynamic>;

      final ma = props['ma']?.toString();
      double? centerLat = props['center_lat'] != null ? (props['center_lat'] as num).toDouble() : null;
      double? centerLng = props['center_lng'] != null ? (props['center_lng'] as num).toDouble() : null;
      if (ma != null && ma.isNotEmpty) {
        final geometry = map['geometry'];
        if (geometry != null) {
          final bounds = _boundsFromGeometry(geometry);
          _provinceBounds[ma] = bounds;
          if (centerLat == null || centerLng == null) {
            // Use the largest polygon's center to avoid island outliers skewing
            final center = _mainlandCenterFromGeometry(geometry);
            centerLat = center.$1;
            centerLng = center.$2;
          }
        }
      }

      final unit = AdminUnit.fromJson(props, centerLat: centerLat, centerLng: centerLng);
      _provinces.add(unit);
    }

    _provinceGeoJson = raw;
    _activeLayer = MapLayer.provinces;
    
    if (_provinces.isNotEmpty) {
      maxProvincePopulation = _provinces.map((u) => u.danSo).reduce(math.max);
      minProvincePopulation = _provinces.map((u) => u.danSo).reduce(math.min);
      maxProvinceDensity = _provinces.map((u) => u.matDo).reduce(math.max);
      minProvinceDensity = _provinces.map((u) => u.matDo).reduce(math.min);
      maxProvinceArea = _provinces.map((u) => u.dienTichKm2).reduce(math.max);
      minProvinceArea = _provinces.map((u) => u.dienTichKm2).reduce(math.min);
    }
    
    // Preload communes so that they are instantly available for searching
    await preloadCommunes();

    return _provinces;
  }

  Future<List<AdminUnit>> preloadCommunes() async {
    if (_communes.isNotEmpty) return _communes;
    final raw = await rootBundle.loadString('assets/communes.json');
    final Map<String, dynamic> geoJson = json.decode(raw);
    final List features = geoJson['features'] as List;

    for (final feature in features) {
      final map = Map<String, dynamic>.from(feature as Map);
      final props = map['properties'] as Map<String, dynamic>;

      final ma = props['ma']?.toString();
      double? centerLat = props['center_lat'] != null ? (props['center_lat'] as num).toDouble() : null;
      double? centerLng = props['center_lng'] != null ? (props['center_lng'] as num).toDouble() : null;
      if (ma != null && ma.isNotEmpty) {
        final geometry = map['geometry'];
        if (geometry != null) {
          final bounds = _boundsFromGeometry(geometry);
          _communeBoundsByMa[ma] = bounds;
          if (centerLat == null || centerLng == null) {
            // Use the largest polygon's center to avoid island outliers skewing
            final center = _mainlandCenterFromGeometry(geometry);
            centerLat = center.$1;
            centerLng = center.$2;
          }
        }
      }

      final unit = AdminUnit.fromJson(props, centerLat: centerLat, centerLng: centerLng);
      _communes.add(unit);

      final parentMa = props['parent_ma']?.toString();
      if (parentMa == null || parentMa.isEmpty) continue;

      _communesByParentMa.putIfAbsent(parentMa, () => []).add(unit);
      _rawFeatureStringsByParentMa.putIfAbsent(parentMa, () => []).add(json.encode(map));
    }
    return _communes;
  }

  Future<List<AdminUnit>> switchLayer(MapLayer layer) async {
    if (layer == MapLayer.communes && _communes.isEmpty) {
      await preloadCommunes();
    }
    _activeLayer = layer;
    return activeUnits;
  }

  Set<String> provincesInBounds(GeoBounds viewport, {double buffer = 0.2}) {
    if (_provinceBounds.isEmpty) return {};
    final expanded = viewport.expand(buffer);
    final result = <String>{};
    for (final entry in _provinceBounds.entries) {
      if (entry.value.intersects(expanded)) {
        result.add(entry.key);
      }
    }
    return result;
  }

  Set<String> provincesAtPoint(double lat, double lng) {
    final containing = <String>{};
    for (final entry in _provinceBounds.entries) {
      if (entry.value.contains(lat, lng)) {
        containing.add(entry.key);
      }
    }
    if (containing.isNotEmpty) return containing;

    String? nearestMa;
    var nearestDist = double.infinity;
    for (final entry in _provinceBounds.entries) {
      final b = entry.value;
      final centerLat = (b.south + b.north) / 2;
      final centerLng = (b.west + b.east) / 2;
      final dist = _squaredDistance(lat, lng, centerLat, centerLng);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestMa = entry.key;
      }
    }
    return nearestMa == null ? {} : {nearestMa};
  }

  /// Pick the [maxCount] provinces nearest to a focal point from a candidate set.
  Set<String> provincesClosestTo(
    double lat,
    double lng,
    Set<String> candidates, {
    int maxCount = 3,
  }) {
    if (candidates.isEmpty) return {};
    if (candidates.length <= maxCount) return candidates;

    final ranked = candidates.toList()
      ..sort((a, b) {
        final boundsA = _provinceBounds[a];
        final boundsB = _provinceBounds[b];
        if (boundsA == null || boundsB == null) return 0;
        final centerA = (
          lat: (boundsA.south + boundsA.north) / 2,
          lng: (boundsA.west + boundsA.east) / 2,
        );
        final centerB = (
          lat: (boundsB.south + boundsB.north) / 2,
          lng: (boundsB.west + boundsB.east) / 2,
        );
        final distA = _squaredDistance(lat, lng, centerA.lat, centerA.lng);
        final distB = _squaredDistance(lat, lng, centerB.lat, centerB.lng);
        return distA.compareTo(distB);
      });

    return ranked.take(maxCount).toSet();
  }

  List<AdminUnit> communesForProvinces(Set<String> parentMas) {
    if (parentMas.isEmpty) return [];
    final result = <AdminUnit>[];
    for (final ma in parentMas) {
      result.addAll(_communesByParentMa[ma] ?? const []);
    }
    return result;
  }

  String buildCommuneGeoJson(Set<String> parentMas) {
    final buffer = StringBuffer();
    buffer.write('{"type":"FeatureCollection","features":[');
    bool first = true;
    for (final ma in parentMas) {
      final featureStrings = _rawFeatureStringsByParentMa[ma];
      if (featureStrings != null) {
        for (final featureString in featureStrings) {
          if (!first) buffer.write(',');
          buffer.write(featureString);
          first = false;
        }
      }
    }
    buffer.write(']}');
    return buffer.toString();
  }

  String cacheKeyForProvinces(Set<String> parentMas) {
    final sorted = parentMas.toList()..sort();
    return sorted.join(',');
  }

  Set<String> getAllCategories() {
    return activeUnits
        .map((u) => u.capHanhChinh)
        .where((c) => c.isNotEmpty && c != 'Không rõ')
        .toSet();
  }

  Set<String> getAllRegions() {
    return activeUnits
        .map((u) => u.macroRegion)
        .where((r) => r != null && r.isNotEmpty)
        .cast<String>()
        .toSet();
  }

  List<AdminUnit> getByCategories(Set<String> activeCategories) {
    if (activeCategories.isEmpty) return activeUnits;
    return activeUnits
        .where((u) => activeCategories.contains(u.capHanhChinh))
        .toList();
  }

  List<AdminUnit> search(String query) {
    if (query.isEmpty) return activeUnits;
    final q = query.toLowerCase();
    return activeUnits.where((u) => u.ten.toLowerCase().contains(q)).toList();
  }

  MapDetailLevel levelForUnit(AdminUnit unit) {
    final parentMa = unit.parentMa;
    if (parentMa != null && parentMa.isNotEmpty) {
      return MapDetailLevel.communes;
    }
    return MapDetailLevel.provinces;
  }

  GeoBounds? boundsForUnit(AdminUnit unit) {
    final ma = unit.ma;
    if (ma == null || ma.isEmpty) return null;

    if (levelForUnit(unit) == MapDetailLevel.communes) {
      return _communeBoundsByMa[ma] ??
          (unit.parentMa != null ? _provinceBounds[unit.parentMa!] : null);
    }
    return _provinceBounds[ma];
  }

  static String removeDiacritics(String str) {
    const withDiacritics =
        'áàãảạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđÁÀÃẢẠĂẮẰẲẴẶÂẤẦẨẪẬÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ';
    const withoutDiacritics =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    for (int i = 0; i < withDiacritics.length; i++) {
      str = str.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return str;
  }

  List<SearchResult> searchUnits(String query, {int limit = 20}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final q = removeDiacritics(trimmed.toLowerCase());
    final scored = <_ScoredSearchResult>[];

    void consider(AdminUnit unit, MapDetailLevel level) {
      final originalName = unit.ten.toLowerCase();
      final name = removeDiacritics(originalName);
      if (name.startsWith(q) || originalName.startsWith(q)) {
        scored.add(
          _ScoredSearchResult(
            unit: unit,
            level: level,
            matchKind: SearchMatchKind.name,
            matchLabel: unit.ten,
            rank: 0,
          ),
        );
        return;
      }
      if (name.contains(q) || originalName.contains(q)) {
        scored.add(
          _ScoredSearchResult(
            unit: unit,
            level: level,
            matchKind: SearchMatchKind.name,
            matchLabel: unit.ten,
            rank: 1,
          ),
        );
        return;
      }

      final predecessors = unit.predecessors;
      if (predecessors != null) {
        final origPred = predecessors.toLowerCase();
        final pred = removeDiacritics(origPred);
        if (pred.contains(q) || origPred.contains(q)) {
          scored.add(
          _ScoredSearchResult(
            unit: unit,
            level: level,
            matchKind: SearchMatchKind.predecessor,
            matchLabel: predecessors,
            rank: 2,
          ),
        );
        }
      }
    }

    for (final unit in _provinces) {
      consider(unit, MapDetailLevel.provinces);
    }
    for (final unit in _communes) {
      consider(unit, MapDetailLevel.communes);
    }

    scored.sort((a, b) {
      final rankCompare = a.rank.compareTo(b.rank);
      if (rankCompare != 0) return rankCompare;
      final levelCompare = a.level.index.compareTo(b.level.index);
      if (levelCompare != 0) return levelCompare;
      return a.unit.ten.compareTo(b.unit.ten);
    });

    return scored
        .take(limit)
        .map(
          (entry) => SearchResult(
            unit: entry.unit,
            level: entry.level,
            matchKind: entry.matchKind,
            matchLabel: entry.matchLabel,
          ),
        )
        .toList();
  }

  


  double tongDienTich([List<AdminUnit>? subset]) {
    final list = subset ?? activeUnits;
    return list.fold<double>(0, (sum, u) => sum + u.dienTichKm2);
  }

  int tongDanSo([List<AdminUnit>? subset]) {
    final list = subset ?? activeUnits;
    return list.fold<int>(0, (sum, u) => sum + u.danSo);
  }

  double matDoTrungBinh([List<AdminUnit>? subset]) {
    final dt = tongDienTich(subset);
    if (dt <= 0) return 0;
    return tongDanSo(subset) / dt;
  }
}

double _squaredDistance(double lat1, double lng1, double lat2, double lng2) {
  final dLat = lat1 - lat2;
  final dLng = lng1 - lng2;
  return dLat * dLat + dLng * dLng;
}

class _ScoredSearchResult {
  final AdminUnit unit;
  final MapDetailLevel level;
  final SearchMatchKind matchKind;
  final String matchLabel;
  final int rank;

  const _ScoredSearchResult({
    required this.unit,
    required this.level,
    required this.matchKind,
    required this.matchLabel,
    required this.rank,
  });
}



/// Returns the center (lat, lng) of the largest polygon in a geometry.
/// For MultiPolygon, picks the polygon with the biggest bounding box area
/// so that distant island clusters don't drag the center away from the mainland.
(double, double) _mainlandCenterFromGeometry(dynamic geometry) {
  final geoMap = geometry as Map<String, dynamic>;
  final type = geoMap['type'] as String? ?? '';
  final coords = geoMap['coordinates'];

  GeoBounds ringBounds(List ring) {
    var s = 90.0, n = -90.0, w = 180.0, e = -180.0;
    for (final pt in ring) {
      if (pt is List && pt.length >= 2) {
        final lng = (pt[0] as num).toDouble();
        final lat = (pt[1] as num).toDouble();
        if (lat < s) s = lat;
        if (lat > n) n = lat;
        if (lng < w) w = lng;
        if (lng > e) e = lng;
      }
    }
    return GeoBounds(south: s, north: n, west: w, east: e);
  }

  double bboxArea(GeoBounds b) => (b.north - b.south) * (b.east - b.west);

  if (type == 'Polygon' && coords is List) {
    // Single polygon — use first ring (outer)
    final bounds = ringBounds(coords[0] as List);
    return ((bounds.south + bounds.north) / 2, (bounds.west + bounds.east) / 2);
  }

  if (type == 'MultiPolygon' && coords is List) {
    // Pick the polygon with the largest bounding box area
    GeoBounds? best;
    double bestArea = -1;
    for (final poly in coords) {
      if (poly is List && poly.isNotEmpty) {
        final ring = poly[0] as List; // outer ring
        final b = ringBounds(ring);
        final a = bboxArea(b);
        if (a > bestArea) {
          bestArea = a;
          best = b;
        }
      }
    }
    if (best != null) {
      return ((best.south + best.north) / 2, (best.west + best.east) / 2);
    }
  }

  // Fallback: full bounding box center
  final fallback = _boundsFromGeometry(geometry);
  return ((fallback.south + fallback.north) / 2, (fallback.west + fallback.east) / 2);
}

GeoBounds _boundsFromGeometry(dynamic geometry) {
  final coords = (geometry as Map<String, dynamic>)['coordinates'];
  var south = 90.0;
  var north = -90.0;
  var west = 180.0;
  var east = -180.0;

  void visit(dynamic node) {
    if (node is List) {
      if (node.length >= 2 && node[0] is num && node[1] is num) {
        final lng = (node[0] as num).toDouble();
        final lat = (node[1] as num).toDouble();
        if (lat < south) south = lat;
        if (lat > north) north = lat;
        if (lng < west) west = lng;
        if (lng > east) east = lng;
        return;
      }
      for (final child in node) {
        visit(child);
      }
    }
  }

  visit(coords);
  return GeoBounds(south: south, north: north, west: west, east: east);
}
