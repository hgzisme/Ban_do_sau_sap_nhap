import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show compute;
import '../models/admin_unit.dart';
import '../models/geo_bounds.dart';
import '../models/map_detail_level.dart';
import '../models/search_result.dart';

/// Enum for the two geographic data layers.
enum MapLayer {
  provinces,
  communes,
}

/// Enum for map coloring mode.
enum ColorMode {
  byType,
  byRegion,
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
  Map<String, List<Map<String, dynamic>>> _rawFeaturesByParentMa = {};
  String? _provinceGeoJson;

  MapLayer _activeLayer = MapLayer.provinces;
  MapLayer get activeLayer => _activeLayer;

  List<AdminUnit> get provinces => _provinces;
  List<AdminUnit> get communes => _communes;
  Map<String, GeoBounds> get provinceBounds => _provinceBounds;
  String get provinceGeoJson =>
      _provinceGeoJson ?? '{"type":"FeatureCollection","features":[]}';
  bool get communesIndexed => _communesByParentMa.isNotEmpty;

  List<AdminUnit> get activeUnits =>
      _activeLayer == MapLayer.provinces ? _provinces : _communes;

  String get activeAssetPath => _activeLayer == MapLayer.provinces
      ? 'assets/provinces.geojson'
      : 'assets/communes.json';

  Future<List<AdminUnit>> loadData() async {
    final raw = await rootBundle.loadString('assets/provinces.geojson');
    final result = await compute(_parseProvincesIsolate, raw);
    _provinces = result.units;
    _provinceBounds = result.boundsByMa;
    _provinceGeoJson = raw;
    _activeLayer = MapLayer.provinces;
    return _provinces;
  }

  Future<List<AdminUnit>> preloadCommunes() async {
    if (_communes.isNotEmpty) return _communes;
    final raw = await rootBundle.loadString('assets/communes.json');
    final result = await compute(_parseCommunesIsolate, raw);
    _communes = result.units;
    _communesByParentMa = result.communesByParentMa;
    _rawFeaturesByParentMa = result.rawFeaturesByParentMa;
    _communeBoundsByMa = result.boundsByMa;
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
    final features = <Map<String, dynamic>>[];
    for (final ma in parentMas) {
      features.addAll(_rawFeaturesByParentMa[ma] ?? const []);
    }
    return json.encode({'type': 'FeatureCollection', 'features': features});
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

  List<SearchResult> searchUnits(String query, {int limit = 20}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final q = trimmed.toLowerCase();
    final scored = <_ScoredSearchResult>[];

    void consider(AdminUnit unit, MapDetailLevel level) {
      final name = unit.ten.toLowerCase();
      if (name.startsWith(q)) {
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
      if (name.contains(q)) {
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
      if (predecessors != null && predecessors.toLowerCase().contains(q)) {
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

class _ProvinceParseResult {
  final List<AdminUnit> units;
  final Map<String, GeoBounds> boundsByMa;

  const _ProvinceParseResult(this.units, this.boundsByMa);
}

class _CommuneParseResult {
  final List<AdminUnit> units;
  final Map<String, List<AdminUnit>> communesByParentMa;
  final Map<String, List<Map<String, dynamic>>> rawFeaturesByParentMa;
  final Map<String, GeoBounds> boundsByMa;

  const _CommuneParseResult(
    this.units,
    this.communesByParentMa,
    this.rawFeaturesByParentMa,
    this.boundsByMa,
  );
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

_ProvinceParseResult _parseProvincesIsolate(String raw) {
  raw = raw.replaceAll(RegExp(r':\s*NaN\b'), ': null');
  final Map<String, dynamic> geoJson = json.decode(raw);
  final List features = geoJson['features'] as List;

  final units = <AdminUnit>[];
  final boundsByMa = <String, GeoBounds>{};

  for (final feature in features) {
    final map = feature as Map<String, dynamic>;
    final props = map['properties'] as Map<String, dynamic>;
    final unit = AdminUnit.fromJson(props);
    units.add(unit);

    final ma = props['ma']?.toString();
    if (ma != null && ma.isNotEmpty) {
      final geometry = map['geometry'];
      if (geometry != null) {
        boundsByMa[ma] = _boundsFromGeometry(geometry);
      }
    }
  }

  return _ProvinceParseResult(units, boundsByMa);
}

_CommuneParseResult _parseCommunesIsolate(String raw) {
  raw = raw.replaceAll(RegExp(r':\s*NaN\b'), ': null');
  final Map<String, dynamic> geoJson = json.decode(raw);
  final List features = geoJson['features'] as List;

  final units = <AdminUnit>[];
  final communesByParentMa = <String, List<AdminUnit>>{};
  final rawFeaturesByParentMa = <String, List<Map<String, dynamic>>>{};
  final boundsByMa = <String, GeoBounds>{};

  for (final feature in features) {
    final map = Map<String, dynamic>.from(feature as Map);
    final props = map['properties'] as Map<String, dynamic>;
    final unit = AdminUnit.fromJson(props);
    units.add(unit);

    final ma = props['ma']?.toString();
    if (ma != null && ma.isNotEmpty) {
      final geometry = map['geometry'];
      if (geometry != null) {
        boundsByMa[ma] = _boundsFromGeometry(geometry);
      }
    }

    final parentMa = props['parent_ma']?.toString();
    if (parentMa == null || parentMa.isEmpty) continue;

    communesByParentMa.putIfAbsent(parentMa, () => []).add(unit);
    rawFeaturesByParentMa.putIfAbsent(parentMa, () => []).add(map);
  }

  return _CommuneParseResult(
    units,
    communesByParentMa,
    rawFeaturesByParentMa,
    boundsByMa,
  );
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
