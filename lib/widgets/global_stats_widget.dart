import 'package:flutter/material.dart';
import 'dart:ui';

/// Dashboard widget showing national-level statistics.
class GlobalStatsWidget extends StatelessWidget {
  final double tongDienTich;
  final int tongDanSo;
  final double matDoTrungBinh;
  final int soLuongDonVi;

  const GlobalStatsWidget({
    super.key,
    required this.tongDienTich,
    required this.tongDanSo,
    required this.matDoTrungBinh,
    required this.soLuongDonVi,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xCC1B2838),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.analytics_rounded,
                    color: Color(0xFF00E5FF),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'THỐNG KÊ CẢ NƯỚC',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StatCard(
                icon: Icons.map_outlined,
                iconColor: const Color(0xFF4FC3F7),
                label: 'Tổng diện tích',
                value: '${_fmt(tongDienTich)} km²',
              ),
              const SizedBox(height: 10),
              _StatCard(
                icon: Icons.people_outline_rounded,
                iconColor: const Color(0xFF81C784),
                label: 'Tổng dân số',
                value: '${_fmtInt(tongDanSo)} người',
              ),
              const SizedBox(height: 10),
              _StatCard(
                icon: Icons.speed_rounded,
                iconColor: const Color(0xFFFFB74D),
                label: 'Mật độ trung bình',
                value: '${_fmt(matDoTrungBinh)} người/km²',
              ),
              const SizedBox(height: 10),
              _StatCard(
                icon: Icons.location_city_rounded,
                iconColor: const Color(0xFFCE93D8),
                label: 'Số đơn vị HC',
                value: '$soLuongDonVi đơn vị',
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(double v) => v
      .toStringAsFixed(1)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  static String _fmtInt(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
