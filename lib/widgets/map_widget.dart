import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import '../models/admin_unit.dart';
import '../repositories/map_repository.dart';

// ─── Color Palettes ─────────────────────────────────────────────────

/// Color palette for administrative types.
const Map<String, Color> categoryColors = {
  // Province-level types
  'Thành phố': Color(0xFFFF6B6B),
  'Tỉnh': Color(0xFF4ECDC4),
  'Thủ đô': Color(0xFFFFE66D),
  // Commune-level types
  'Phường': Color(0xFFA29BFE),
  'Xã': Color(0xFF55EFC4),
  'Đặc khu': Color(0xFFFFA502),
  // Legacy types
  'Thành phố trực thuộc TW': Color(0xFFFF6B6B),
  'Quận': Color(0xFFA29BFE),
  'Huyện': Color(0xFF55EFC4),
  'Thị xã': Color(0xFFFFA502),
  'Thị trấn': Color(0xFFD4A574),
  'Quần đảo': Color(0xFF74B9FF),
};

/// Color palette for macro regions — visually distinct, premium feel.
const Map<String, Color> regionColors = {
  'north_central': Color(0xFF26A69A), // Bắc Trung Bộ — Teal
  'northeast': Color(0xFF66BB6A), // Đông Bắc — Emerald
  'northwest': Color(0xFF26C6DA), // Tây Bắc — Cyan
  'red_river_delta': Color(0xFFEF5350), // ĐB Sông Hồng — Ruby
  'south_central': Color(0xFFFFA726), // Nam Trung Bộ — Amber
  'central_highlands': Color(0xFFAB47BC), // Tây Nguyên — Purple
  'southeast': Color(0xFFFF7043), // Đông Nam Bộ — Coral
  'mekong_delta': Color(0xFF42A5F5), // ĐB Sông Cửu Long — Azure
};

/// Human-readable names for macro regions.
const Map<String, String> regionNames = {
  'north_central': 'Bắc Trung Bộ',
  'northeast': 'Đông Bắc',
  'northwest': 'Tây Bắc',
  'red_river_delta': 'Đồng bằng Sông Hồng',
  'south_central': 'Nam Trung Bộ',
  'central_highlands': 'Tây Nguyên',
  'southeast': 'Đông Nam Bộ',
  'mekong_delta': 'Đồng bằng Sông Cửu Long',
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

/// Get color for a unit based on the current color mode.
Color colorForUnit(AdminUnit unit, ColorMode colorMode) {
  if (colorMode == ColorMode.byRegion) {
    return colorForRegion(unit.macroRegion);
  }
  return colorForCategory(unit.capHanhChinh);
}

// ─── Map Widget ─────────────────────────────────────────────────────

/// The core map widget that renders GeoJSON data using Syncfusion Maps.
///
/// Supports:
/// - Drag/pan and smooth scroll zoom
/// - Hover highlight + dynamic tooltip
/// - Category or region-based coloring
/// - Selection callback
/// - Zoom controls (+/−)
class MapWidget extends StatefulWidget {
  final List<AdminUnit> provincesData;
  final List<AdminUnit> communesData;
  final String provincesAssetPath;
  final String communesAssetPath;
  final bool communesLoaded;
  final Set<String> activeFilters;
  final ValueChanged<AdminUnit?> onSelectionChanged;
  final ValueChanged<double>? onZoomChanged;
  final ColorMode colorMode;

  const MapWidget({
    super.key,
    required this.provincesData,
    required this.communesData,
    required this.provincesAssetPath,
    required this.communesAssetPath,
    required this.communesLoaded,
    required this.activeFilters,
    required this.onSelectionChanged,
    this.onZoomChanged,
    this.colorMode = ColorMode.byType,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late MapZoomPanBehavior _zoomPanBehavior;
  bool _isMapReady = false;
  bool _showCommunes = false;
  Timer? _zoomTimer;
  double _lastZoom = 0;

  @override
  void initState() {
    super.initState();
    _zoomPanBehavior = MapZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      zoomLevel: 4.5,
      focalLatLng: const MapLatLng(
        15.0,
        108.5,
      ), // Center to cover both mainland and islands
      minZoomLevel: 1.0,
      maxZoomLevel: 15,
      showToolbar: false,
    );
    _showCommunes = _shouldShowCommunes(_zoomPanBehavior.zoomLevel);
    _startReadyTimer();
    // Poll zoom level periodically and notify parent when it changes.
    _zoomTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final z = _zoomPanBehavior.zoomLevel;
      final shouldShowCommunes = _shouldShowCommunes(z);
      final zoomChanged = (z - _lastZoom).abs() > 0.05;

      if (zoomChanged) {
        _lastZoom = z;
      }

      if (shouldShowCommunes != _showCommunes && mounted) {
        setState(() {
          _showCommunes = shouldShowCommunes;
        });
      }

      if (zoomChanged) {
        widget.onZoomChanged?.call(z);
      }
    });
  }

  bool _shouldShowCommunes(double zoom) {
    return widget.communesLoaded &&
        widget.communesData.isNotEmpty &&
        zoom >= 5.2;
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provincesAssetPath != widget.provincesAssetPath ||
        oldWidget.communesAssetPath != widget.communesAssetPath) {
      setState(() => _isMapReady = false);
      _startReadyTimer();
    }
  }

  void _startReadyTimer() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _isMapReady = true);
      }
    });
  }

  @override
  void dispose() {
    _zoomTimer?.cancel();
    super.dispose();
  }

  MapShapeSource _buildTypeShapeSourceFor(
    List<AdminUnit> data,
    String assetPath,
  ) {
    final categories = widget.activeFilters.isNotEmpty
        ? widget.activeFilters
        : data.map((u) => u.capHanhChinh).toSet();

    final colorMappers = categories.map((cap) {
      return MapColorMapper(
        value: cap,
        color: colorForCategory(cap).withValues(alpha: 0.75),
        text: cap,
      );
    }).toList();

    return MapShapeSource.asset(
      assetPath,
      shapeDataField: 'ten',
      dataCount: data.length,
      primaryValueMapper: (int index) => data[index].ten,
      shapeColorValueMapper: (int index) => data[index].capHanhChinh,
      shapeColorMappers: colorMappers,
    );
  }

  MapShapeSource _buildRegionShapeSourceFor(
    List<AdminUnit> data,
    String assetPath,
  ) {
    final regions = data.map((u) => u.macroRegion ?? 'unknown').toSet();

    final colorMappers = regions.map((region) {
      return MapColorMapper(
        value: region,
        color: colorForRegion(region).withValues(alpha: 0.75),
        text: regionDisplayName(region),
      );
    }).toList();

    return MapShapeSource.asset(
      assetPath,
      shapeDataField: 'ten',
      dataCount: data.length,
      primaryValueMapper: (int index) => data[index].ten,
      shapeColorValueMapper: (int index) =>
          data[index].macroRegion ?? 'unknown',
      shapeColorMappers: colorMappers,
    );
  }

  @override
  Widget build(BuildContext context) {
    // If both datasets are empty, show empty state.
    if (widget.provincesData.isEmpty && widget.communesData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text(
              'Không có dữ liệu để hiển thị.\nHãy chọn ít nhất một danh mục.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Main map
        AbsorbPointer(
          absorbing: !_isMapReady,
          child: SfMapsTheme(
            data: SfMapsThemeData(
              shapeHoverColor: const Color(0x8800E5FF),
              shapeHoverStrokeColor: const Color(0xFF00E5FF),
              shapeHoverStrokeWidth: 2.5,
            ),
            child: SfMaps(
              layers: [
                // Provinces layer (always present)
                MapShapeLayer(
                  source: widget.colorMode == ColorMode.byRegion
                      ? _buildRegionShapeSourceFor(
                          widget.provincesData,
                          widget.provincesAssetPath,
                        )
                      : _buildTypeShapeSourceFor(
                          widget.provincesData,
                          widget.provincesAssetPath,
                        ),
                  zoomPanBehavior: _zoomPanBehavior,
                  strokeColor: Colors.white.withValues(alpha: 0.22),
                  strokeWidth: 0.8,
                  selectedIndex: -1,
                  selectionSettings: const MapSelectionSettings(
                    color: Color(0xBB00E5FF),
                    strokeColor: Color(0xFF00E5FF),
                    strokeWidth: 3.0,
                  ),
                  onSelectionChanged: (int index) {
                    if (!_showCommunes &&
                        index >= 0 &&
                        index < widget.provincesData.length) {
                      widget.onSelectionChanged(widget.provincesData[index]);
                    }
                  },
                  initialMarkersCount: _showCommunes ? 0 : 2,
                  markerBuilder: (BuildContext context, int index) {
                    if (index == 0) {
                      return MapMarker(
                        latitude: 16.5,
                        longitude: 111.8,
                        child: const _IslandMarker(
                          label: 'Quần đảo Hoàng Sa\n(TP. Đà Nẵng)',
                        ),
                      );
                    } else {
                      return MapMarker(
                        latitude: 10.0,
                        longitude: 114.0,
                        child: const _IslandMarker(
                          label: 'Quần đảo Trường Sa\n(Tỉnh Khánh Hòa)',
                        ),
                      );
                    }
                  },
                  legend: MapLegend(
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

                // Communes layer (only when zoomed in and data available)
                if (_showCommunes)
                  MapShapeLayer(
                    source: widget.colorMode == ColorMode.byRegion
                        ? _buildRegionShapeSourceFor(
                            widget.communesData,
                            widget.communesAssetPath,
                          )
                        : _buildTypeShapeSourceFor(
                            widget.communesData,
                            widget.communesAssetPath,
                          ),
                    zoomPanBehavior: _zoomPanBehavior,
                    strokeColor: Colors.white.withValues(alpha: 0.55),
                    strokeWidth: 1.0,
                    selectedIndex: -1,
                    selectionSettings: const MapSelectionSettings(
                      color: Color(0xBB00E5FF),
                      strokeColor: Color(0xFF00E5FF),
                      strokeWidth: 2.5,
                    ),
                    onSelectionChanged: (int index) {
                      if (index >= 0 && index < widget.communesData.length) {
                        widget.onSelectionChanged(widget.communesData[index]);
                      }
                    },
                    initialMarkersCount: 0,
                  ),
              ],
            ),
          ),
        ),

        // Zoom controls
        Positioned(
          right: 16,
          bottom: 100,
          child: AbsorbPointer(
            absorbing: !_isMapReady,
            child: _ZoomControls(zoomPanBehavior: _zoomPanBehavior),
          ),
        ),
      ],
    );
  }
}

// ─── Zoom Controls ──────────────────────────────────────────────────

class _ZoomControls extends StatefulWidget {
  final MapZoomPanBehavior zoomPanBehavior;

  const _ZoomControls({required this.zoomPanBehavior});

  @override
  State<_ZoomControls> createState() => _ZoomControlsState();
}

class _ZoomControlsState extends State<_ZoomControls> {
  Timer? _timer;
  double _lastZoom = 0;
  double _currentZoomLevel = 0;

  @override
  void initState() {
    super.initState();
    _lastZoom = widget.zoomPanBehavior.zoomLevel;
    _currentZoomLevel = _lastZoom;
    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      final currentZoom = widget.zoomPanBehavior.zoomLevel;
      if (currentZoom != _lastZoom && mounted) {
        setState(() {
          _lastZoom = currentZoom;
          _currentZoomLevel = currentZoom;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _commitZoomLevel(double value) {
    final clamped = value.clamp(1.0, 15.0);
    setState(() {
      _currentZoomLevel = clamped;
    });

    try {
      widget.zoomPanBehavior.zoomLevel = clamped;
      _lastZoom = widget.zoomPanBehavior.zoomLevel;
    } catch (_) {
      // Syncfusion can throw on web while the map layer is still resolving.
    }
  }

  void _zoomIn() {
    _commitZoomLevel(_currentZoomLevel + 1);
  }

  void _zoomOut() {
    _commitZoomLevel(_currentZoomLevel - 1);
  }

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
            padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                    value: _currentZoomLevel,
                    min: 1,
                    max: 15,
                    onChanged: (value) {
                      setState(() {
                        _currentZoomLevel = value;
                      });
                    },
                    onChangeEnd: _commitZoomLevel,
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
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


// ─── Island Markers ─────────────────────────────────────────────────

class _IslandMarker extends StatelessWidget {
  final String label;

  const _IslandMarker({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Small icon representing island cluster
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
        // Text label
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }
}
