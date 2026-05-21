import 'package:flutter/material.dart';
import '../repositories/map_repository.dart';
import 'map_widget.dart' show categoryColors, regionNames, colorForRegion;

/// Sidebar widget with:
/// - Layer switcher (Tỉnh/Thành phố vs Phường/Xã)
/// - Color mode switcher (Theo loại vs Theo vùng miền)
/// - Category filter chips
/// - Select all / Deselect all
class FilterWidget extends StatelessWidget {
  final Set<String> allCategories;
  final Set<String> activeCategories;
  final ValueChanged<String> onToggle;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final MapLayer activeLayer;
  final ValueChanged<MapLayer> onLayerChanged;
  final bool isLoadingLayer;
  final ColorMode colorMode;
  final ValueChanged<ColorMode> onColorModeChanged;

  const FilterWidget({
    super.key,
    required this.allCategories,
    required this.activeCategories,
    required this.onToggle,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.activeLayer,
    required this.onLayerChanged,
    this.isLoadingLayer = false,
    required this.colorMode,
    required this.onColorModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = allCategories.toList()..sort();

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

          // ── Layer Switcher ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CẤP ĐỊA GIỚI',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1923),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2A3F54)),
                  ),
                  child: Row(
                    children: [
                      _LayerTab(
                        label: 'Tỉnh / TP',
                        icon: Icons.map_rounded,
                        isActive: activeLayer == MapLayer.provinces,
                        onTap: isLoadingLayer ? null : () => onLayerChanged(MapLayer.provinces),
                      ),
                      _LayerTab(
                        label: 'Phường / Xã',
                        icon: Icons.location_city_rounded,
                        isActive: activeLayer == MapLayer.communes,
                        onTap: isLoadingLayer ? null : () => onLayerChanged(MapLayer.communes),
                      ),
                    ],
                  ),
                ),
                if (isLoadingLayer)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Đang tải dữ liệu...',
                          style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A3F54), height: 1),

          // ── Color Mode Switcher ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CHẾ ĐỘ MÀU SẮC',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1923),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2A3F54)),
                  ),
                  child: Row(
                    children: [
                      _LayerTab(
                        label: 'Theo loại',
                        icon: Icons.category_rounded,
                        isActive: colorMode == ColorMode.byType,
                        onTap: () => onColorModeChanged(ColorMode.byType),
                        accentColor: const Color(0xFF4ECDC4),
                      ),
                      _LayerTab(
                        label: 'Theo vùng',
                        icon: Icons.public_rounded,
                        isActive: colorMode == ColorMode.byRegion,
                        onTap: () => onColorModeChanged(ColorMode.byRegion),
                        accentColor: const Color(0xFFFF6B6B),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A3F54), height: 1),

          // (Category filter removed as requested)
          const Spacer(),


          // ── Region Legend (when in region mode) ──
          if (colorMode == ColorMode.byRegion)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF2A3F54), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CHÚ GIẢI VÙNG MIỀN',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: regionNames.entries.map((entry) {
                      final color = colorForRegion(entry.key);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              entry.value,
                              style: TextStyle(
                                color: color,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),

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

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF223344),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white54, size: 15),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
