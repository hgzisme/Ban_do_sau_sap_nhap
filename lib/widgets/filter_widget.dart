import 'package:flutter/material.dart';
import '../repositories/map_repository.dart';
import 'map_style.dart' show colorForCategory, colorForRegion, regionNames, typeLegendOrder;

/// Sidebar widget with:
/// - Layer switcher (Tỉnh/Thành phố vs Phường/Xã)
/// - Color mode switcher (Theo loại vs Theo vùng miền)
/// - Category filter chips
/// - Select all / Deselect all
class FilterWidget extends StatelessWidget {
  final MapDataMode dataMode;
  final ValueChanged<MapDataMode> onDataModeChanged;

  const FilterWidget({
    super.key,
    required this.dataMode,
    required this.onDataModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      decoration: const BoxDecoration(
        color: Color(0xFF1B2838),
        border: Border(
          right: BorderSide(color: Color(0xFF2A3F54), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_rounded, color: Color(0xFFDA251D), size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'BẢN ĐỒ VIỆT NAM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Sau sáp nhập đơn vị hành chính\nNQ 202/2025/QH15',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A3F54), height: 1),

          // ── Map Display Mode Switcher ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BẢN ĐỒ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1923),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _LayerTab(
                        label: 'Mặc định',
                        icon: Icons.map_rounded,
                        isActive: dataMode == MapDataMode.none,
                        accentColor: const Color(0xFF00E5FF),
                        onTap: () => onDataModeChanged(MapDataMode.none),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'BẢN ĐỒ BIỂU DIỄN THEO VÙNG',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1923),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _LayerTab(
                            label: 'Dân số',
                            icon: Icons.people_alt_rounded,
                            isActive: dataMode == MapDataMode.population,
                            accentColor: Colors.greenAccent,
                            onTap: () => onDataModeChanged(MapDataMode.population),
                          ),
                          const SizedBox(width: 4),
                          _LayerTab(
                            label: 'Mật độ',
                            icon: Icons.blur_on_rounded,
                            isActive: dataMode == MapDataMode.density,
                            accentColor: Colors.orangeAccent,
                            onTap: () => onDataModeChanged(MapDataMode.density),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _LayerTab(
                            label: 'Diện tích',
                            icon: Icons.square_foot_rounded,
                            isActive: dataMode == MapDataMode.area,
                            accentColor: Colors.purpleAccent,
                            onTap: () => onDataModeChanged(MapDataMode.area),
                          ),
                          const SizedBox(width: 4),
                          _LayerTab(
                            label: 'Vùng miền',
                            icon: Icons.category_rounded,
                            isActive: dataMode == MapDataMode.macroRegion,
                            accentColor: Colors.blueAccent,
                            onTap: () => onDataModeChanged(MapDataMode.macroRegion),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (dataMode == MapDataMode.macroRegion) ...[
                  const SizedBox(height: 16),
                  const _MacroRegionLegend(),
                ],
              ],
            ),
          ),
          const Spacer(),

          // ── Footer: Data Source ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF2A3F54), width: 1),
              ),
            ),
            child: const Text(
              'Nguồn: tmquan/sapnhap-bando-vn\nHugging Face Datasets',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 10,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroRegionLegend extends StatelessWidget {
  const _MacroRegionLegend();

  @override
  Widget build(BuildContext context) {
    final List<String> regions = [
      'northern_midlands',
      'central_coast',
      'red_river_delta',
      'mekong_delta',
      'southeast',
      'central_highlands',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1923),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Vùng kinh tế',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...regions.map((region) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colorForRegion(region),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      regionNames[region] ?? region,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Tab button for layer/mode switching.
class _LayerTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;
  final Color accentColor;

  const _LayerTab({
    required this.label,
    required this.icon,
    required this.isActive,
    this.onTap,
    this.accentColor = const Color(0xFF00E5FF),
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isActive ? accentColor.withValues(alpha: 0.4) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? accentColor : Colors.white38,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? accentColor : Colors.white38,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

