import 'package:flutter/material.dart';
import '../models/admin_unit.dart';
import 'map_style.dart'
    show colorForCategory, colorForRegion, regionDisplayName;

/// Panel showing detailed info for a selected/hovered administrative unit.
///
/// Displays the extended fields from Hugging Face data:
/// name, type, area, population, density, capital, decree, predecessors.
class DetailPanelWidget extends StatelessWidget {
  final AdminUnit? unit;
  final VoidCallback? onClose;

  const DetailPanelWidget({super.key, this.unit, this.onClose});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: unit == null ? _placeholder() : _content(unit!),
    );
  }

  Widget _placeholder() {
    return Container(
      key: const ValueKey('empty'),
      padding: const EdgeInsets.all(20),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, color: Colors.white24, size: 40),
          SizedBox(height: 12),
          Text(
            'Click vào một đơn vị\nhành chính trên bản đồ',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _content(AdminUnit u) {
    final catColor = colorForCategory(u.capHanhChinh);

    return Container(
      key: ValueKey(u.ten),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF00E5FF),
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'CHI TIẾT',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                // Close button
                if (onClose != null)
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Name
            Text(
              u.ten,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: catColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                u.capHanhChinh,
                style: TextStyle(
                  color: catColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (u.macroRegion != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorForRegion(u.macroRegion).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: colorForRegion(u.macroRegion).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  regionDisplayName(u.macroRegion),
                  style: TextStyle(
                    color: colorForRegion(u.macroRegion),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Core Stats
            _infoRow(
              Icons.map_outlined,
              const Color(0xFF4FC3F7),
              'Diện tích',
              '${_fmt(u.dienTichKm2)} km²',
            ),
            const SizedBox(height: 8),
            _infoRow(
              Icons.people_outline_rounded,
              const Color(0xFF81C784),
              'Dân số',
              '${_fmtInt(u.danSo)} người',
            ),
            const SizedBox(height: 8),
            _infoRow(
              Icons.speed_rounded,
              const Color(0xFFFFB74D),
              'Mật độ',
              '${_fmt(u.matDo)} người/km²',
            ),

            // Extended info from HuggingFace
            if (u.capital != null) ...[
              const SizedBox(height: 8),
              _infoRow(
                Icons.location_city_rounded,
                const Color(0xFFCE93D8),
                'Thủ phủ',
                [
                  u.capital!,
                  if (u.coordinateSummary != null) u.coordinateSummary!,
                ].join('\n'),
              ),
            ],
            if (u.decree != null) ...[
              const SizedBox(height: 8),
              _infoRow(
                Icons.gavel_rounded,
                const Color(0xFF90CAF9),
                'Nghị quyết',
                u.decree!,
              ),
            ],
            if (u.predecessors != null) ...[
              const SizedBox(height: 12),
              _expandableInfo(
                Icons.merge_type_rounded,
                const Color(0xFFA5D6A7),
                'Tiền thân (sáp nhập từ)',
                u.predecessors!,
              ),
            ],
            if (u.parentTen != null) ...[
              const SizedBox(height: 8),
              _infoRow(
                Icons.account_tree_rounded,
                const Color(0xFFFFCC02),
                'Thuộc',
                u.parentTen!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A collapsible info row for long text like predecessors.
  Widget _expandableInfo(
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(1)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  String _fmtInt(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
}
