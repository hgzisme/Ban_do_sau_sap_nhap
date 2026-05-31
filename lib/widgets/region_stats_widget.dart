import 'package:flutter/material.dart';
import '../models/admin_unit.dart';
import 'map_style.dart' show colorForRegion, regionNames;

class RegionStatsWidget extends StatelessWidget {
  final List<AdminUnit> provinces;

  const RegionStatsWidget({super.key, required this.provinces});

  @override
  Widget build(BuildContext context) {
    // 1. Calculate population per region
    final map = <String, int>{};
    for (var p in provinces) {
      if (p.macroRegion != null) {
        map[p.macroRegion!] = (map[p.macroRegion!] ?? 0) + p.danSo;
      }
    }

    // Sort regions by population descending
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) return const SizedBox();

    final maxPop = entries.first.value;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                color: Color(0xFF00E5FF),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'PHÂN BỐ DÂN SỐ THEO VÙNG KINH TẾ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ...entries.map((entry) {
            final region = entry.key;
            final pop = entry.value;
            final ratio = maxPop > 0 ? pop / maxPop : 0.0;
            // Ensure color is bright enough for dark theme, otherwise use a fallback
            Color color = colorForRegion(region);
            if (color == const Color(0xFF000000)) {
              // Southeast uses black in the python script, we change it to a distinct color for dark mode
              color = const Color(0xFFE0E0E0);
            }
            final name = regionNames[region] ?? region;

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${_fmtInt(pop)} người',
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 10,
                            width: constraints.maxWidth,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 1200),
                            curve: Curves.easeOutCubic,
                            height: 10,
                            width: constraints.maxWidth * ratio,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _fmtInt(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
}
