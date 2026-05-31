import 'dart:math' as math;
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
  bool _hasError = false;
  String _errorMessage = '';
  MapDataMode _dataMode = MapDataMode.none;
  final ValueNotifier<AdminUnit?> _selectedUnit = ValueNotifier(null);
  MapFocusRequest? _focusRequest;
  int _focusToken = 0;
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
    try {
      await _repo.loadData();
      await _repo.preloadCommunes();
      
      if (_repo.provinces.isEmpty) {
        throw Exception("Không tìm thấy dữ liệu bản đồ trong hệ thống!");
      }
      
      setState(() {
        _loading = false;
        _hasError = false;
        _mapDetailState = MapDetailState(
          level: MapDetailLevel.provinces,
          visibleUnitCount: _repo.provinces.length,
        );
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi tải dữ liệu: $_errorMessage"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }



  void _onSelectionChanged(AdminUnit? unit) {
    _selectedUnit.value = unit;
  }

  void _onDetailStateChanged(MapDetailState state) {
    setState(() => _mapDetailState = state);
  }

  void _closeDetail() {
    _selectedUnit.value = null;
  }

  void _onSearchResult(SearchResult? result) {
    if (result == null) {
      _closeDetail();
      return;
    }
    _selectedUnit.value = result.unit;
    setState(() {
      _focusRequest = MapFocusRequest(
        unit: result.unit,
        token: ++_focusToken,
      );
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

    if (_hasError) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F1923),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Lỗi Khởi Tạo Dữ Liệu',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _hasError = false;
                  });
                  _loadData();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử Lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: const Color(0xFF0F1923),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: Row(
        children: [
          FilterWidget(
            dataMode: _dataMode,
            onDataModeChanged: (mode) {
              setState(() {
                _dataMode = mode;
              });
            },
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: const Color(0xFF0F1923),
                  child: ValueListenableBuilder<AdminUnit?>(
                    valueListenable: _selectedUnit,
                    builder: (context, unit, child) {
                      return MapLodWidget(
                        repository: _repo,
                        dataMode: _dataMode,
                        onSelectionChanged: _onSelectionChanged,
                        onDetailStateChanged: _onDetailStateChanged,
                        focusRequest: _focusRequest,
                        selectedUnit: unit,
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: MapSearchOverlay(
                    repository: _repo,
                    onResultSelected: _onSearchResult,
                  ),
                ),
                Positioned(top: 16, right: 16, child: _buildLayerBadge()),
                if (_dataMode != MapDataMode.none && _dataMode != MapDataMode.macroRegion)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: _VerticalLegendWidget(
                      minVal: _dataMode == MapDataMode.density
                          ? _repo.minProvinceDensity
                          : (_dataMode == MapDataMode.area ? _repo.minProvinceArea : _repo.minProvincePopulation.toDouble()),
                      maxVal: _dataMode == MapDataMode.density
                          ? _repo.maxProvinceDensity
                          : (_dataMode == MapDataMode.area ? _repo.maxProvinceArea : _repo.maxProvincePopulation.toDouble()),
                      mode: _dataMode,
                    ),
                  ),
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
                      child: ValueListenableBuilder<AdminUnit?>(
                        valueListenable: _selectedUnit,
                        builder: (context, unit, child) {
                          return DetailPanelWidget(
                            unit: unit,
                            onClose: _closeDetail,
                          );
                        },
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
    final layerColor =
        isProvince ? const Color(0xFF4ECDC4) : const Color(0xFFA29BFE);
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

class _VerticalLegendWidget extends StatelessWidget {
  final double minVal;
  final double maxVal;
  final MapDataMode mode;

  const _VerticalLegendWidget({
    required this.minVal,
    required this.maxVal,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final isDensity = mode == MapDataMode.density;
    final isArea = mode == MapDataMode.area;
    
    final title = isDensity ? 'Mật độ (người/km²)' : (isArea ? 'Diện tích (km²)' : 'Dân số (người)');
    
    final List<Color> gradientColors;
    if (isDensity) {
      gradientColors = [
        const Color(0x33FF9800), // 20% Orange
        const Color(0xFFFF9800), // 100% Orange
      ];
    } else if (isArea) {
      gradientColors = [
        const Color(0x33E040FB), // 20% PurpleAccent
        const Color(0xFFE040FB), // 100% PurpleAccent
      ];
    } else {
      gradientColors = [
        const Color(0x3300E676), // 20% Green
        const Color(0xFF00E676), // 100% Green
      ];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xCC1B2838),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              title,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, letterSpacing: 1.1),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 12,
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: gradientColors,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 250,
            width: 32, // fixed width for labels to align correctly
            child: Stack(
              clipBehavior: Clip.none,
              children: List.generate(6, (index) {
                double ratio = index / 5; // 0.0 to 1.0
                double val;
                if (isDensity) {
                  double logMin = math.log(minVal <= 0 ? 1 : minVal);
                  double logMax = math.log(maxVal <= 0 ? 1 : maxVal);
                  val = math.exp(logMin + (logMax - logMin) * ratio);
                } else {
                  val = minVal + (maxVal - minVal) * ratio;
                }
                String label;
                if (isDensity) {
                  label = val > 1000 ? '${(val / 1000).toStringAsFixed(1)}K' : val.round().toString();
                } else if (isArea) {
                  label = val > 1000 ? '${(val / 1000).toStringAsFixed(1)}K' : val.round().toString();
                } else {
                  label = '${(val / 1000000).toStringAsFixed(1)}M';
                }
                return Positioned(
                  bottom: (250 - 14) * ratio, // 14 is approx text height
                  left: 0,
                  child: Text(
                    label,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
 
