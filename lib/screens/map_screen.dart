import 'package:flutter/material.dart';
import '../models/admin_unit.dart';
import '../models/map_detail_level.dart';
import '../models/map_focus_request.dart';
import '../models/search_result.dart';
import '../repositories/map_repository.dart';
import '../widgets/detail_panel_widget.dart';
import '../widgets/filter_widget.dart';
import '../widgets/map_lod_widget.dart';
import '../widgets/map_search_overlay.dart';

/// Main screen composing the sidebar filter, map, and detail panel.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapRepository _repo = MapRepository();

  bool _loading = true;
  AdminUnit? _selectedUnit;
  ColorMode _colorMode = ColorMode.byType;
  MapFocusRequest? _focusRequest;
  int _focusToken = 0;
  int _searchResetToken = 0;
  MapDetailState _mapDetailState = MapDetailState(
    level: MapDetailLevel.provinces,
    visibleUnitCount: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _repo.loadData();
    await _repo.preloadCommunes();
    setState(() {
      _loading = false;
      _mapDetailState = MapDetailState(
        level: MapDetailLevel.provinces,
        visibleUnitCount: _repo.provinces.length,
      );
    });
  }

  void _onColorModeChanged(ColorMode mode) {
    setState(() => _colorMode = mode);
  }

  void _onToggleCategory(String cat) {}

  void _onSelectAll() {}

  void _onDeselectAll() {}

  void _onSelectionChanged(AdminUnit? unit) {
    setState(() => _selectedUnit = unit);
  }

  void _onDetailStateChanged(MapDetailState state) {
    setState(() => _mapDetailState = state);
  }

  void _closeDetail() {
    setState(() {
      _selectedUnit = null;
      _searchResetToken++;
    });
  }

  void _onSearchResult(SearchResult result) {
    setState(() {
      _selectedUnit = result.unit;
      _focusRequest = MapFocusRequest(unit: result.unit, token: ++_focusToken);
    });
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

    final detailUnit = _selectedUnit;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: Row(
        children: [
          FilterWidget(
            allCategories: const {},
            activeCategories: const {},
            onToggle: _onToggleCategory,
            onSelectAll: _onSelectAll,
            onDeselectAll: _onDeselectAll,
            colorMode: _colorMode,
            onColorModeChanged: _onColorModeChanged,
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: const Color(0xFF0F1923),
                  child: MapLodWidget(
                    key: ValueKey('maplod-${_focusToken}'),
                    repository: _repo,
                    selectedUnit: _selectedUnit,
                    onSelectionChanged: _onSelectionChanged,
                    onDetailStateChanged: _onDetailStateChanged,
                    colorMode: _colorMode,
                    focusRequest: _focusRequest,
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: MapSearchOverlay(
                    repository: _repo,
                    resetToken: _searchResetToken,
                    onResultSelected: _onSearchResult,
                  ),
                ),
                Positioned(top: 16, right: 16, child: _buildLayerBadge()),
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
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: DetailPanelWidget(
                        unit: detailUnit,
                        onClose: _closeDetail,
                      ),
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

  Widget _buildLayerBadge() {
    final isProvince = _mapDetailState.level == MapDetailLevel.provinces;
    final layerColor = isProvince
        ? const Color(0xFF4ECDC4)
        : const Color(0xFFA29BFE);
    final count = _mapDetailState.visibleUnitCount;
    final label = isProvince
        ? 'Cấp Tỉnh/TP ($count đơn vị)'
        : 'Cấp Phường/Xã ($count trong vùng)';

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
            isProvince ? Icons.map_rounded : Icons.location_city_rounded,
            size: 16,
            color: layerColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: layerColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_mapDetailState.isRefreshing) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: layerColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
