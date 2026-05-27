import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import '../models/admin_unit.dart';
import '../models/geo_bounds.dart';
import '../models/map_detail_level.dart';
import '../models/map_focus_request.dart';
import '../repositories/map_repository.dart';
import 'map_style.dart';

/// Google Maps-style LOD map: provinces at low zoom, viewport-filtered communes
/// at high zoom. Province base layer handles pan; communes render as sublayer.
class MapLodWidget extends StatefulWidget {
  final MapRepository repository;
  final ValueChanged<AdminUnit?> onSelectionChanged;
  final ValueChanged<MapDetailState>? onDetailStateChanged;
  final ColorMode colorMode;
  final MapFocusRequest? focusRequest;

  const MapLodWidget({
    super.key,
    required this.repository,
    required this.onSelectionChanged,
    this.onDetailStateChanged,
    this.colorMode = ColorMode.byType,
    this.focusRequest,
  });

  @override
  State<MapLodWidget> createState() => _MapLodWidgetState();
}

class _MapLodWidgetState extends State<MapLodWidget> {
  late MapZoomPanBehavior _zoomPanBehavior;
  late MapShapeLayerController _layerController;
  late ValueNotifier<double> _zoomNotifier;

  MapDetailLevel _detailLevel = MapDetailLevel.provinces;
  double _zoomLevel = MapZoomThresholds.defaultZoomLevel;
  Size _mapSize = Size.zero;

  /// Actual map center from Syncfusion gesture callbacks. Shape layers do not
  /// keep [MapZoomPanBehavior.focalLatLng] in sync during pan/zoom.
  MapLatLng? _cameraFocal;
  MapLatLngBounds? _cameraVisibleBounds;

  Set<String> _visibleParentMas = {};
  List<AdminUnit> _visibleCommunes = [];
  Uint8List? _communeGeoJsonBytes;
  bool _isRefreshingCommunes = false;

  Timer? _gestureDebounce;
  MapShapeSource? _provinceSourceCache;
  final Map<String, MapShapeSource> _communeSourceCache = {};
  int? _lastAppliedFocusToken;

  bool _isPointerDown = false;
  bool _pendingGestureSettled = false;

  List<AdminUnit> get _provinces => widget.repository.provinces;

  double _clampZoom(double value) {
    return value.clamp(
      MapZoomThresholds.minZoomLevel,
      MapZoomThresholds.maxZoomLevel,
    );
  }

  MapLatLng _currentFocal() {
    return _cameraFocal ??
        _zoomPanBehavior.focalLatLng ??
        const MapLatLng(15.0, 108.5);
  }

  MapLatLng _focalFromGeoBounds(GeoBounds bounds) {
    return MapLatLng(
      (bounds.south + bounds.north) / 2,
      (bounds.west + bounds.east) / 2,
    );
  }

  MapLatLng _focalFromBounds(MapLatLngBounds bounds) {
    return MapLatLng(
      (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
      (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
    );
  }

  void _trackCameraFromZoom(MapZoomDetails details) {
    if (details.newZoomLevel != null) {
      _zoomLevel = _clampZoom(details.newZoomLevel!);
      _zoomNotifier.value = _zoomLevel;
    }
    if (details.newVisibleBounds != null) {
      _cameraVisibleBounds = details.newVisibleBounds;
      _cameraFocal = _focalFromBounds(details.newVisibleBounds!);
    }
  }

  void _trackCameraFromPan(MapPanDetails details) {
    if (details.zoomLevel != null) {
      _zoomLevel = _clampZoom(details.zoomLevel!);
      _zoomNotifier.value = _zoomLevel;
    }
    if (details.newVisibleBounds != null) {
      _cameraVisibleBounds = details.newVisibleBounds;
      _cameraFocal = _focalFromBounds(details.newVisibleBounds!);
    }
  }

  void _refreshCameraFromController() {
    try {
      _zoomLevel = _zoomPanBehavior.zoomLevel;
      _zoomNotifier.value = _zoomLevel;
    } catch (_) {}

    final viewport = _computeViewportBoundsFromPixels();
    if (viewport == null) return;

    _cameraVisibleBounds = MapLatLngBounds(
      MapLatLng(viewport.north, viewport.east),
      MapLatLng(viewport.south, viewport.west),
    );
    _cameraFocal = MapLatLng(
      (viewport.south + viewport.north) / 2,
      (viewport.west + viewport.east) / 2,
    );


  }

  GeoBounds? _computeViewportBoundsFromPixels() {
    if (_mapSize == Size.zero) return null;
    try {
      final points = <({double lat, double lng})>[
        _toLatLngPoint(_layerController.pixelToLatLng(Offset.zero)),
        _toLatLngPoint(
          _layerController.pixelToLatLng(Offset(_mapSize.width, 0)),
        ),
        _toLatLngPoint(
          _layerController.pixelToLatLng(Offset(0, _mapSize.height)),
        ),
        _toLatLngPoint(
          _layerController.pixelToLatLng(
            Offset(_mapSize.width, _mapSize.height),
          ),
        ),
      ];
      return GeoBounds.fromPoints(points);
    } catch (_) {
      return null;
    }
  }

  GeoBounds? _geoBoundsFromLatLngBounds(MapLatLngBounds bounds) {
    return GeoBounds(
      south: bounds.southwest.latitude,
      north: bounds.northeast.latitude,
      west: bounds.southwest.longitude,
      east: bounds.northeast.longitude,
    );
  }

  Set<String> _resolveProvinceMasForCommunes() {
    final focal = _currentFocal();

    final atPoint = widget.repository.provincesAtPoint(
      focal.latitude,
      focal.longitude,
    );
    if (atPoint.isNotEmpty) return atPoint;

    final viewport = _computeViewportBounds();
    if (viewport == null) return {};

    final inBounds = widget.repository.provincesInBounds(
      viewport,
      buffer: MapZoomThresholds.viewportBufferDegrees,
    );
    if (inBounds.isEmpty) return {};

    if (inBounds.length <= 3) return inBounds;

    return widget.repository.provincesClosestTo(
      focal.latitude,
      focal.longitude,
      inBounds,
      maxCount: 3,
    );
  }

  ({Set<String> parentMas, List<AdminUnit> communes, Uint8List geoJsonBytes})?
  _computeCommuneViewportData() {
    final parentMas = _resolveProvinceMasForCommunes();
    if (parentMas.isEmpty) return null;

    return (
      parentMas: parentMas,
      communes: widget.repository.communesForProvinces(parentMas),
      geoJsonBytes: widget.repository.buildCommuneGeoJsonBytes(parentMas),
    );
  }

  @override
  void initState() {
    super.initState();
    _zoomNotifier = ValueNotifier(_zoomLevel);
    _layerController = MapShapeLayerController();
    _zoomPanBehavior = MapZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      zoomLevel: _zoomLevel,
      minZoomLevel: MapZoomThresholds.minZoomLevel,
      maxZoomLevel: MapZoomThresholds.maxZoomLevel,
      showToolbar: false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyDetailState();
    });
  }

  @override
  void didUpdateWidget(MapLodWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.colorMode != widget.colorMode) {
      _provinceSourceCache = null;
      _provinceSourceCacheKey = null;
      _communeSourceCache.clear();
      setState(() {});
    }
    if (widget.focusRequest != null &&
        widget.focusRequest!.token != _lastAppliedFocusToken) {
      final request = widget.focusRequest!;
      _lastAppliedFocusToken = request.token;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyFocusRequest(request);
      });
    }
  }

  void _applyFocusRequest(MapFocusRequest request) {
    final unit = request.unit;
    final level = widget.repository.levelForUnit(unit);
    final bounds = widget.repository.boundsForUnit(unit);
    if (bounds == null) return;

    final focal = _focalFromGeoBounds(bounds);
    final targetZoom = _clampZoom(
      level == MapDetailLevel.communes
          ? MapZoomThresholds.focusZoomCommune
          : MapZoomThresholds.focusZoomProvince,
    );

    if (level == MapDetailLevel.communes) {
      final parentMa = unit.parentMa;
      if (parentMa == null || parentMa.isEmpty) return;

      final parentMas = {parentMa};
      setState(() {
        _detailLevel = MapDetailLevel.communes;
        _visibleParentMas = parentMas;
        _visibleCommunes = widget.repository.communesForProvinces(parentMas);
        _communeGeoJsonBytes = widget.repository.buildCommuneGeoJsonBytes(parentMas);
        _isRefreshingCommunes = false;
      });
      _notifyDetailState();
    } else {
      setState(() {
        _detailLevel = MapDetailLevel.provinces;
        _visibleParentMas = {};
        _visibleCommunes = [];
        _communeGeoJsonBytes = null;
        _isRefreshingCommunes = false;
      });
      _notifyDetailState();
    }

    _zoomLevel = targetZoom;
    _zoomNotifier.value = targetZoom;
    _cameraFocal = focal;
    _cameraVisibleBounds = MapLatLngBounds(
      MapLatLng(bounds.north, bounds.east),
      MapLatLng(bounds.south, bounds.west),
    );

    try {
      _zoomPanBehavior.focalLatLng = focal;
      _zoomPanBehavior.zoomLevel = targetZoom;
      _zoomLevel = _clampZoom(_zoomPanBehavior.zoomLevel);
      _zoomNotifier.value = _zoomLevel;
    } catch (_) {}

    widget.onSelectionChanged(unit);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshCameraFromController();
      _scheduleGestureSettled();
    });
  }

  @override
  void dispose() {
    _gestureDebounce?.cancel();
    _zoomNotifier.dispose();
    super.dispose();
  }

  MapDetailLevel _resolveDetailLevel(double zoom) {
    if (_detailLevel == MapDetailLevel.provinces) {
      return zoom >= MapZoomThresholds.zoomInToCommunes
          ? MapDetailLevel.communes
          : MapDetailLevel.provinces;
    }
    return zoom <= MapZoomThresholds.zoomOutToProvinces
        ? MapDetailLevel.provinces
        : MapDetailLevel.communes;
  }

  void _scheduleGestureSettled() {
    _gestureDebounce?.cancel();
    _gestureDebounce = Timer(MapZoomThresholds.viewportDebounce, () {
      if (mounted) _onGestureSettled();
    });
  }

  void _onGestureSettled() {
    if (_isPointerDown) {
      _pendingGestureSettled = true;
      return;
    }
    _pendingGestureSettled = false;

    if (!widget.repository.communesIndexed) return;

    _refreshCameraFromController();

    final targetLevel = _resolveDetailLevel(_zoomLevel);

    if (targetLevel == MapDetailLevel.communes) {
      final data = _computeCommuneViewportData();
      if (data == null) {
        // Syncfusion may not have updated visible bounds yet after zoom.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scheduleGestureSettled();
        });
        return;
      }

      final levelChanged = _detailLevel != MapDetailLevel.communes;
      final viewportChanged = !setEquals(data.parentMas, _visibleParentMas);
      if (!levelChanged && !viewportChanged) return;

      setState(() {
        _detailLevel = MapDetailLevel.communes;
        _visibleParentMas = data.parentMas;
        _visibleCommunes = data.communes;
        _communeGeoJsonBytes = data.geoJsonBytes;
        _isRefreshingCommunes = false;
      });
      widget.onSelectionChanged(null);
      _notifyDetailState();
      return;
    }

    if (_detailLevel == MapDetailLevel.provinces) return;

    setState(() {
      _detailLevel = MapDetailLevel.provinces;
      _visibleParentMas = {};
      _visibleCommunes = [];
      _communeGeoJsonBytes = null;
      _isRefreshingCommunes = false;
    });
    widget.onSelectionChanged(null);
    _notifyDetailState();
  }

  bool _handleWillZoom(MapZoomDetails details) {
    if (details.newZoomLevel != null &&
        details.newZoomLevel! < MapZoomThresholds.minZoomLevel) {
      return false;
    }
    _trackCameraFromZoom(details);
    _scheduleGestureSettled();
    return true;
  }

  bool _handleWillPan(MapPanDetails details) {
    _trackCameraFromPan(details);
    if (_detailLevel == MapDetailLevel.communes ||
        _zoomLevel >= MapZoomThresholds.zoomInToCommunes) {
      _scheduleGestureSettled();
    }
    return true;
  }

  GeoBounds? _computeViewportBounds() {
    if (_cameraVisibleBounds != null) {
      return _geoBoundsFromLatLngBounds(_cameraVisibleBounds!);
    }
    return _computeViewportBoundsFromPixels();
  }

  ({double lat, double lng}) _toLatLngPoint(MapLatLng latLng) {
    return (lat: latLng.latitude, lng: latLng.longitude);
  }

  void _notifyDetailState() {
    widget.onDetailStateChanged?.call(
      MapDetailState(
        level: _detailLevel,
        visibleUnitCount: _detailLevel == MapDetailLevel.provinces
            ? _provinces.length
            : _visibleCommunes.length,
        isRefreshing: _isRefreshingCommunes,
      ),
    );
  }

  MapShapeSource _buildProvinceSource() {
    final cacheKey = widget.colorMode.name;
    if (_provinceSourceCache != null &&
        _provinceSourceCacheKey == cacheKey) {
      return _provinceSourceCache!;
    }
    _provinceSourceCacheKey = cacheKey;
    _provinceSourceCache = _buildMemoryShapeSource(
      _provinces,
      widget.repository.provinceGeoJsonBytes,
    );
    return _provinceSourceCache!;
  }

  String? _provinceSourceCacheKey;

  MapShapeSource _buildCommuneSource() {
    if (_visibleCommunes.isEmpty || _communeGeoJsonBytes == null) {
      // Provide a tiny invisible dummy polygon inside Vietnam to prevent Syncfusion bounds calculation crashes on empty layers
      const dummyGeoJson = '{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[105.0,15.0],[105.0,15.0001],[105.0001,15.0001],[105.0,15.0]]]},"properties":{}}]}';
      return MapShapeSource.memory(
        Uint8List.fromList(utf8.encode(dummyGeoJson)),
      );
    }

    final cacheKey =
        '${widget.colorMode.name}:${widget.repository.cacheKeyForProvinces(_visibleParentMas)}';
    final cached = _communeSourceCache[cacheKey];
    if (cached != null) return cached;

    final source = _buildMemoryShapeSource(_visibleCommunes, _communeGeoJsonBytes!);
    _communeSourceCache[cacheKey] = source;
    return source;
  }

  MapShapeSource _buildMemoryShapeSource(
    List<AdminUnit> data,
    Uint8List geoJsonBytes,
  ) {
    if (widget.colorMode == ColorMode.byRegion) {
      return _buildRegionMemorySource(data, geoJsonBytes);
    }
    return _buildTypeMemorySource(data, geoJsonBytes);
  }

  List<MapColorMapper> _typeColorMappers(List<AdminUnit> data) {
    final categories = data.map((u) => u.capHanhChinh).toSet();
    return categories
        .map(
          (cap) => MapColorMapper(
            value: cap,
            color: colorForCategory(cap).withValues(alpha: 0.75),
            text: cap,
          ),
        )
        .toList();
  }

  List<MapColorMapper> _regionColorMappers(List<AdminUnit> data) {
    final regions = data.map((u) => u.macroRegion ?? 'unknown').toSet();
    return regions
        .map(
          (region) => MapColorMapper(
            value: region,
            color: colorForRegion(region).withValues(alpha: 0.75),
            text: regionDisplayName(region),
          ),
        )
        .toList();
  }

  MapShapeSource _buildTypeMemorySource(
    List<AdminUnit> data,
    Uint8List geoJsonBytes,
  ) {
    return MapShapeSource.memory(
      geoJsonBytes,
      shapeDataField: 'ten',
      dataCount: data.length,
      primaryValueMapper: (int index) => data[index].ten,
      shapeColorValueMapper: (int index) => data[index].capHanhChinh,
      shapeColorMappers: _typeColorMappers(data),
    );
  }

  MapShapeSource _buildRegionMemorySource(
    List<AdminUnit> data,
    Uint8List geoJsonBytes,
  ) {
    return MapShapeSource.memory(
      geoJsonBytes,
      shapeDataField: 'ten',
      dataCount: data.length,
      primaryValueMapper: (int index) => data[index].ten,
      shapeColorValueMapper: (int index) =>
          data[index].macroRegion ?? 'unknown',
      shapeColorMappers: _regionColorMappers(data),
    );
  }

  void _commitZoomLevel(double value) {
    final clamped = _clampZoom(value);
    _zoomLevel = clamped;
    _zoomNotifier.value = clamped;
    try {
      _zoomPanBehavior.zoomLevel = clamped;
      _zoomLevel = _clampZoom(_zoomPanBehavior.zoomLevel);
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshCameraFromController();
      _scheduleGestureSettled();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_provinces.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text(
              'Không có dữ liệu để hiển thị.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final showCommuneOverlay = _detailLevel == MapDetailLevel.communes &&
        _visibleCommunes.isNotEmpty &&
        _communeGeoJsonBytes != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        _mapSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Listener(
                onPointerDown: (_) => _isPointerDown = true,
                onPointerUp: (_) {
                  _isPointerDown = false;
                  if (_pendingGestureSettled && mounted) {
                    _onGestureSettled();
                  }
                },
                onPointerCancel: (_) {
                  _isPointerDown = false;
                  if (_pendingGestureSettled && mounted) {
                    _onGestureSettled();
                  }
                },
                child: SfMapsTheme(
                  data: SfMapsThemeData(
                  shapeHoverColor: const Color(0x8800E5FF),
                  shapeHoverStrokeColor: const Color(0xFF00E5FF),
                  shapeHoverStrokeWidth: 2.5,
                ),
                child: SfMaps(
                  layers: [
                    MapShapeLayer(
                      key: ValueKey('provinces-${widget.colorMode.name}'),
                      controller: _layerController,
                      source: _buildProvinceSource(),
                      zoomPanBehavior: _zoomPanBehavior,
                      onWillZoom: _handleWillZoom,
                      onWillPan: _handleWillPan,
                      loadingBuilder: (BuildContext context) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00E5FF),
                          ),
                        );
                      },
                      strokeColor: Colors.white.withValues(
                        alpha: showCommuneOverlay ? 0.12 : 0.22,
                      ),
                      strokeWidth: showCommuneOverlay ? 0.5 : 0.8,
                      selectedIndex: -1,
                      selectionSettings: const MapSelectionSettings(
                        color: Color(0xBB00E5FF),
                        strokeColor: Color(0xFF00E5FF),
                        strokeWidth: 3.0,
                      ),
                      onSelectionChanged: showCommuneOverlay
                          ? null
                          : (int index) {
                              if (index >= 0 && index < _provinces.length) {
                                widget.onSelectionChanged(_provinces[index]);
                              }
                            },
                      sublayers: [
                        MapShapeSublayer(
                          source: _buildCommuneSource(),
                          strokeColor: showCommuneOverlay 
                              ? Colors.white.withValues(alpha: 0.55)
                              : Colors.transparent,
                          strokeWidth: showCommuneOverlay ? 1.0 : 0.0,
                          selectedIndex: -1,
                          selectionSettings: const MapSelectionSettings(
                            color: Color(0xBB00E5FF),
                            strokeColor: Color(0xFF00E5FF),
                            strokeWidth: 3.0,
                          ),
                          onSelectionChanged: showCommuneOverlay
                              ? (int index) {
                                  if (index >= 0 &&
                                      index < _visibleCommunes.length) {
                                    widget.onSelectionChanged(
                                      _visibleCommunes[index],
                                    );
                                  }
                                }
                              : null,
                        ),
                      ],
                      initialMarkersCount: showCommuneOverlay ? 0 : 2,
                      markerBuilder: showCommuneOverlay
                          ? null
                          : (BuildContext context, int index) {
                              if (index == 0) {
                                return MapMarker(
                                  latitude: 16.5,
                                  longitude: 111.8,
                                  child: const _IslandMarker(
                                    label:
                                        'Quần đảo Hoàng Sa\n(TP. Đà Nẵng)',
                                  ),
                                );
                              }
                              return MapMarker(
                                latitude: 10.0,
                                longitude: 114.0,
                                child: const _IslandMarker(
                                  label:
                                      'Quần đảo Trường Sa\n(Tỉnh Khánh Hòa)',
                                ),
                              );
                            },
                      legend: showCommuneOverlay
                          ? null
                          : MapLegend(
                              MapElement.shape,
                              position: MapLegendPosition.bottom,
                              overflowMode: MapLegendOverflowMode.wrap,
                              padding: const EdgeInsets.all(12),
                              textStyle: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            ),
            Positioned(
              right: 16,
              bottom: 100,
              child: _ZoomControls(
                zoomNotifier: _zoomNotifier,
                onCommitZoom: _commitZoomLevel,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ZoomControls extends StatefulWidget {
  final ValueNotifier<double> zoomNotifier;
  final ValueChanged<double> onCommitZoom;

  const _ZoomControls({
    required this.zoomNotifier,
    required this.onCommitZoom,
  });

  @override
  State<_ZoomControls> createState() => _ZoomControlsState();
}

class _ZoomControlsState extends State<_ZoomControls> {
  late double _currentZoomLevel;

  @override
  void initState() {
    super.initState();
    _currentZoomLevel = widget.zoomNotifier.value;
    widget.zoomNotifier.addListener(_onZoomChanged);
  }

  @override
  void didUpdateWidget(_ZoomControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoomNotifier != widget.zoomNotifier) {
      oldWidget.zoomNotifier.removeListener(_onZoomChanged);
      widget.zoomNotifier.addListener(_onZoomChanged);
      _currentZoomLevel = widget.zoomNotifier.value;
    }
  }

  @override
  void dispose() {
    widget.zoomNotifier.removeListener(_onZoomChanged);
    super.dispose();
  }

  void _onZoomChanged() {
    if (!mounted) return;
    setState(() => _currentZoomLevel = widget.zoomNotifier.value);
  }

  void _commitZoomLevel(double value) {
    final clamped = value.clamp(
      MapZoomThresholds.minZoomLevel,
      MapZoomThresholds.maxZoomLevel,
    );
    setState(() => _currentZoomLevel = clamped);
    widget.onCommitZoom(clamped);
  }

  void _zoomIn() =>
      _commitZoomLevel(_currentZoomLevel + 0.5);
  void _zoomOut() => _commitZoomLevel(_currentZoomLevel - 0.5);

  @override
  Widget build(BuildContext context) {
    final displayZoom = _currentZoomLevel.toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xDD1B2838),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3F54)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomButton(
            icon: Icons.add_rounded,
            onTap: _zoomIn,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          ),
          Container(height: 1, width: 36, color: const Color(0xFF2A3F54)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 120,
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: const Color(0xFF00E5FF),
                    inactiveTrackColor: const Color(0xFF2A3F54),
                    thumbColor: Colors.white,
                    overlayColor: const Color(
                      0xFF00E5FF,
                    ).withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    value: _currentZoomLevel.clamp(
                      MapZoomThresholds.minZoomLevel,
                      MapZoomThresholds.maxZoomLevel,
                    ),
                    min: MapZoomThresholds.minZoomLevel,
                    max: MapZoomThresholds.maxZoomLevel,
                    onChanged: (value) {
                      setState(() => _currentZoomLevel = value);
                    },
                    onChangeEnd: _commitZoomLevel,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${displayZoom}x',
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(height: 1, width: 36, color: const Color(0xFF2A3F54)),
          _ZoomButton(
            icon: Icons.remove_rounded,
            onTap: _zoomOut,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(11),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _ZoomButton({
    required this.icon,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        hoverColor: const Color(0xFF00E5FF).withValues(alpha: 0.1),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}

class _IslandMarker extends StatelessWidget {
  final String label;

  const _IslandMarker({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.5),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
