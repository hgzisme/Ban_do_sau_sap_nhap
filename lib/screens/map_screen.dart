import 'package:flutter/material.dart';
import '../models/admin_unit.dart';
import '../repositories/map_repository.dart';
import '../widgets/map_widget.dart';
import '../widgets/filter_widget.dart';
import '../widgets/global_stats_widget.dart';
import '../widgets/detail_panel_widget.dart';

/// Main screen composing the sidebar filter, map, stats dashboard, and detail panel.
///
/// Manages dual-layer state (provinces / communes), category filtering,
/// and color mode switching.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapRepository _repo = MapRepository();

  bool _loading = true;
  bool _isLoadingLayer = false;
  List<AdminUnit> _filteredUnits = [];
  Set<String> _allCategories = {};
  Set<String> _activeCategories = {};
  int _selectedIndex = -1;
  AdminUnit? _selectedUnit;
  AdminUnit? _hoveredUnit;
  ColorMode _colorMode = ColorMode.byType;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final units = await _repo.loadData();
    final cats = _repo.getAllCategories();
    setState(() {
      _allCategories = cats;
      _activeCategories = Set.from(cats); // All active by default
      _filteredUnits = units;
      _loading = false;
    });
  }

  Future<void> _onLayerChanged(MapLayer layer) async {
    if (layer == _repo.activeLayer) return;

    setState(() {
      _isLoadingLayer = true;
      _selectedIndex = -1;
      _selectedUnit = null;
      _hoveredUnit = null;
    });

    await _repo.switchLayer(layer);
    final cats = _repo.getAllCategories();

    setState(() {
      _allCategories = cats;
      _activeCategories = Set.from(cats);
      _filteredUnits = _repo.activeUnits;
      _isLoadingLayer = false;
    });
  }

  void _onColorModeChanged(ColorMode mode) {
    setState(() => _colorMode = mode);
  }

  void _onToggleCategory(String cat) {
    setState(() {
      if (_activeCategories.contains(cat)) {
        _activeCategories.remove(cat);
      } else {
        _activeCategories.add(cat);
      }
      _updateFiltered();
    });
  }

  void _onSelectAll() {
    setState(() {
      _activeCategories = Set.from(_allCategories);
      _updateFiltered();
    });
  }

  void _onDeselectAll() {
    setState(() {
      _activeCategories.clear();
      _updateFiltered();
    });
  }

  void _updateFiltered() {
    _filteredUnits = _repo.getByCategories(_activeCategories);
    _selectedIndex = -1;
    _selectedUnit = null;
  }

  void _onSelectionChanged(int index) {
    setState(() {
      if (index < 0 || index >= _filteredUnits.length) {
        _selectedIndex = -1;
        _selectedUnit = null;
      } else {
        _selectedIndex = index;
        _selectedUnit = _filteredUnits[index];
      }
    });
  }

  void _onHover(int? index) {
    if (index != null && index >= 0 && index < _filteredUnits.length) {
      final unit = _filteredUnits[index];
      if (_hoveredUnit?.ten != unit.ten) {
        setState(() => _hoveredUnit = unit);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1923),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LoadingSpinner(),
              SizedBox(height: 20),
              Text(
                'Đang tải dữ liệu bản đồ...',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Determine which unit to show in detail panel (selected overrides hovered)
    final detailUnit = _selectedUnit ?? _hoveredUnit;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: Row(
        children: [
          // ── LEFT SIDEBAR ──
          FilterWidget(
            allCategories: _allCategories,
            activeCategories: _activeCategories,
            onToggle: _onToggleCategory,
            onSelectAll: _onSelectAll,
            onDeselectAll: _onDeselectAll,
            activeLayer: _repo.activeLayer,
            onLayerChanged: _onLayerChanged,
            isLoadingLayer: _isLoadingLayer,
            colorMode: _colorMode,
            onColorModeChanged: _onColorModeChanged,
          ),

          // ── MAP + OVERLAYS ──
          Expanded(
            child: Stack(
              children: [
                // Map
                Container(
                  color: const Color(0xFF0A1628),
                  child: _isLoadingLayer
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LoadingSpinner(),
                              SizedBox(height: 20),
                              Text(
                                'Đang tải dữ liệu cấp Phường/Xã...\n(3.321 đơn vị — đang xử lý trong nền)',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : MapWidget(
                          data: _filteredUnits,
                          activeFilters: _activeCategories,
                          selectedIndex: _selectedIndex,
                          onSelectionChanged: _onSelectionChanged,
                          onHover: _onHover,
                          assetPath: _repo.activeAssetPath,
                          colorMode: _colorMode,
                        ),
                ),

                // Top-left: Title bar
                Positioned(
                  top: 16,
                  left: 16,
                  child: _buildTitleBar(),
                ),

                // Top-right: Layer indicator
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildLayerBadge(),
                ),

                // Bottom-right: Global stats
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: GlobalStatsWidget(
                    tongDienTich: _repo.tongDienTich(_filteredUnits),
                    tongDanSo: _repo.tongDanSo(_filteredUnits),
                    matDoTrungBinh: _repo.matDoTrungBinh(_filteredUnits),
                    soLuongDonVi: _filteredUnits.length,
                  ),
                ),

                // Bottom-left: Detail panel
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 280,
                      constraints: const BoxConstraints(maxHeight: 420),
                      decoration: BoxDecoration(
                        color: const Color(0xCC1B2838),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: DetailPanelWidget(unit: detailUnit),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC1B2838),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.15)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, color: Color(0xFFDA251D), size: 20),
          SizedBox(width: 8),
          Text(
            'Bản đồ hành chính Việt Nam sau sáp nhập',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerBadge() {
    final isProvinces = _repo.activeLayer == MapLayer.provinces;
    final layerColor = isProvinces ? const Color(0xFF4ECDC4) : const Color(0xFFA29BFE);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC1B2838),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: layerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isProvinces ? Icons.map_rounded : Icons.location_city_rounded,
            size: 16,
            color: layerColor,
          ),
          const SizedBox(width: 6),
          Text(
            isProvinces
                ? 'Cấp Tỉnh/TP (${_filteredUnits.length} đơn vị)'
                : 'Cấp Phường/Xã (${_filteredUnits.length} đơn vị)',
            style: TextStyle(
              color: layerColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium loading spinner with pulsing animation.
class _LoadingSpinner extends StatefulWidget {
  const _LoadingSpinner();

  @override
  State<_LoadingSpinner> createState() => _LoadingSpinnerState();
}

class _LoadingSpinnerState extends State<_LoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00E5FF), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00E5FF),
                strokeWidth: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}
