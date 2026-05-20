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
  'Tỉnh':      Color(0xFF4ECDC4),
  'Thủ đô':    Color(0xFFFFE66D),
  // Commune-level types
  'Phường':    Color(0xFFA29BFE),
  'Xã':        Color(0xFF55EFC4),
  'Đặc khu':   Color(0xFFFFA502),
  // Legacy types
  'Thành phố trực thuộc TW': Color(0xFFFF6B6B),
  'Quận':      Color(0xFFA29BFE),
  'Huyện':     Color(0xFF55EFC4),
  'Thị xã':    Color(0xFFFFA502),
  'Thị trấn':  Color(0xFFD4A574),
  'Quần đảo':  Color(0xFF74B9FF),
};

/// Color palette for macro regions — visually distinct, premium feel.
const Map<String, Color> regionColors = {
  'north_central':     Color(0xFF26A69A), // Bắc Trung Bộ — Teal
  'northeast':         Color(0xFF66BB6A), // Đông Bắc — Emerald
  'northwest':         Color(0xFF26C6DA), // Tây Bắc — Cyan
  'red_river_delta':   Color(0xFFEF5350), // ĐB Sông Hồng — Ruby
  'south_central':     Color(0xFFFFA726), // Nam Trung Bộ — Amber
  'central_highlands': Color(0xFFAB47BC), // Tây Nguyên — Purple
  'southeast':         Color(0xFFFF7043), // Đông Nam Bộ — Coral
  'mekong_delta':      Color(0xFF42A5F5), // ĐB Sông Cửu Long — Azure
};

/// Human-readable names for macro regions.
const Map<String, String> regionNames = {
  'north_central':     'Bắc Trung Bộ',
  'northeast':         'Đông Bắc',
  'northwest':         'Tây Bắc',
  'red_river_delta':   'Đồng bằng Sông Hồng',
  'south_central':     'Nam Trung Bộ',
  'central_highlands': 'Tây Nguyên',
  'southeast':         'Đông Nam Bộ',
  'mekong_delta':      'Đồng bằng Sông Cửu Long',
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
  final List<AdminUnit> data;
  final Set<String> activeFilters;
  final int selectedIndex;
  final ValueChanged<int> onSelectionChanged;
  final ValueChanged<int?> onHover;
  final String assetPath;
  final ColorMode colorMode;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  const MapWidget({
    super.key,
    required this.data,
    required this.activeFilters,
    required this.selectedIndex,
    required this.onSelectionChanged,
    required this.onHover,
    required this.assetPath,
    this.colorMode = ColorMode.byType,
    this.onZoomIn,
    this.onZoomOut,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late MapZoomPanBehavior _zoomPanBehavior;

  @override
  void initState() {
    super.initState();
    _zoomPanBehavior = MapZoomPanBehavior(
      enablePanning: true,
      enablePinching: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      zoomLevel: 5.5,
      focalLatLng: const MapLatLng(16.0, 107.5), // Center of Vietnam
      minZoomLevel: 4,
      maxZoomLevel: 12,
      showToolbar: false,
    );
  }

  void zoomIn() {
    final current = _zoomPanBehavior.zoomLevel;
    if (current < 12) {
      _zoomPanBehavior.zoomLevel = current + 1;
    }
  }

  void zoomOut() {
    final current = _zoomPanBehavior.zoomLevel;
    if (current > 4) {
      _zoomPanBehavior.zoomLevel = current - 1;
    }
  }

  MapShapeSource _buildShapeSource() {
    if (widget.colorMode == ColorMode.byRegion) {
      return _buildRegionShapeSource();
    }
    return _buildTypeShapeSource();
  }

  MapShapeSource _buildTypeShapeSource() {
    final categories = widget.activeFilters.isNotEmpty
        ? widget.activeFilters
        : widget.data.map((u) => u.capHanhChinh).toSet();

    final colorMappers = categories.map((cap) {
      return MapColorMapper(
        value: cap,
        color: colorForCategory(cap).withValues(alpha: 0.75),
        text: cap,
      );
    }).toList();

    return MapShapeSource.asset(
      widget.assetPath,
      shapeDataField: 'ten',
      dataCount: widget.data.length,
      primaryValueMapper: (int index) => widget.data[index].ten,
      shapeColorValueMapper: (int index) => widget.data[index].capHanhChinh,
      shapeColorMappers: colorMappers,
    );
  }

  MapShapeSource _buildRegionShapeSource() {
    final regions = widget.data
        .map((u) => u.macroRegion ?? 'unknown')
        .toSet();

    final colorMappers = regions.map((region) {
      return MapColorMapper(
        value: region,
        color: colorForRegion(region).withValues(alpha: 0.75),
        text: regionDisplayName(region),
      );
    }).toList();

    return MapShapeSource.asset(
      widget.assetPath,
      shapeDataField: 'ten',
      dataCount: widget.data.length,
      primaryValueMapper: (int index) => widget.data[index].ten,
      shapeColorValueMapper: (int index) =>
          widget.data[index].macroRegion ?? 'unknown',
      shapeColorMappers: colorMappers,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
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
        SfMapsTheme(
          data: SfMapsThemeData(
            shapeHoverColor: const Color(0x8800E5FF),
            shapeHoverStrokeColor: const Color(0xFF00E5FF),
            shapeHoverStrokeWidth: 2.5,
          ),
          child: SfMaps(
            layers: [
              MapShapeLayer(
                source: _buildShapeSource(),
                zoomPanBehavior: _zoomPanBehavior,
                strokeColor: Colors.white.withValues(alpha: 0.25),
                strokeWidth: 0.8,
                selectedIndex: widget.selectedIndex,
                selectionSettings: const MapSelectionSettings(
                  color: Color(0xBB00E5FF),
                  strokeColor: Color(0xFF00E5FF),
                  strokeWidth: 3.0,
                ),
                onSelectionChanged: (int index) {
                  widget.onSelectionChanged(index);
                },
                initialMarkersCount: 2,
                markerBuilder: (BuildContext context, int index) {
                  if (index == 0) {
                    return MapMarker(
                      latitude: 16.5,
                      longitude: 111.8,
                      child: const _IslandMarker(label: 'Quần đảo Hoàng Sa\n(TP. Đà Nẵng)'),
                    );
                  } else {
                    return MapMarker(
                      latitude: 10.0,
                      longitude: 114.0,
                      child: const _IslandMarker(label: 'Quần đảo Trường Sa\n(Tỉnh Khánh Hòa)'),
                    );
                  }
                },
                shapeTooltipBuilder: (BuildContext context, int index) {
                  if (index < 0 || index >= widget.data.length) {
                    return const SizedBox.shrink();
                  }
                  final unit = widget.data[index];
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.onHover(index);
                  });
                  return _EnhancedTooltip(
                    unit: unit,
                    colorMode: widget.colorMode,
                  );
                },
                tooltipSettings: const MapTooltipSettings(
                  color: Color(0xF01B2838),
                  strokeColor: Color(0xFF00E5FF),
                  strokeWidth: 1.0,
                ),
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
            ],
          ),
        ),

        // Zoom controls
        Positioned(
          right: 16,
          bottom: 100,
          child: _ZoomControls(
            onZoomIn: zoomIn,
            onZoomOut: zoomOut,
          ),
        ),
      ],
    );
  }
}

// ─── Zoom Controls ──────────────────────────────────────────────────

class _ZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
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
            onTap: onZoomIn,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          ),
          Container(height: 1, width: 36, color: const Color(0xFF2A3F54)),
          _ZoomButton(
            icon: Icons.remove_rounded,
            onTap: onZoomOut,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
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

// ─── Enhanced Dynamic Tooltip ───────────────────────────────────────

class _EnhancedTooltip extends StatelessWidget {
  final AdminUnit unit;
  final ColorMode colorMode;

  const _EnhancedTooltip({
    required this.unit,
    required this.colorMode,
  });

  @override
  Widget build(BuildContext context) {
    final mainColor = colorForUnit(unit, colorMode);
    final regionName = regionDisplayName(unit.macroRegion);

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Gradient header bar ──
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  mainColor,
                  mainColor.withValues(alpha: 0.3),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title + Type badge ──
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        unit.ten,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // ── Badges row ──
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Type badge
                    _badge(
                      unit.capHanhChinh,
                      colorForCategory(unit.capHanhChinh),
                    ),
                    // Region badge
                    if (unit.macroRegion != null)
                      _badge(
                        regionName,
                        colorForRegion(unit.macroRegion),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // ── Quick stats chips ──
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _statChip(
                        Icons.map_outlined,
                        const Color(0xFF4FC3F7),
                        '${_fmt(unit.dienTichKm2)} km²',
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        Icons.people_outline_rounded,
                        const Color(0xFF81C784),
                        _fmtInt(unit.danSo),
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        Icons.speed_rounded,
                        const Color(0xFFFFB74D),
                        '${_fmt(unit.matDo)}/km²',
                      ),
                    ],
                  ),
                ),

                // ── Capital ──
                if (unit.capital != null) ...[
                  const SizedBox(height: 6),
                  _infoLine(
                    Icons.location_city_rounded,
                    const Color(0xFFCE93D8),
                    'Thủ phủ: ${unit.capital!}',
                  ),
                ],

                // ── Predecessors summary ──
                if (unit.predecessors != null) ...[
                  const SizedBox(height: 4),
                  _infoLine(
                    Icons.merge_type_rounded,
                    const Color(0xFFA5D6A7),
                    _predecessorSummary(unit.predecessors!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, Color color, String value) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Summarize predecessors to avoid very long tooltip text.
  String _predecessorSummary(String raw) {
    // Count comma-separated items
    final parts = raw.split(RegExp(r',\s*'));
    if (parts.length <= 2) return 'Sáp nhập từ: $raw';
    return 'Sáp nhập từ ${parts.length} đơn vị';
  }

  String _fmt(double v) => v.toStringAsFixed(1).replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );

  String _fmtInt(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
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


