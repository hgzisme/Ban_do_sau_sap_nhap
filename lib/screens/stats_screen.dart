import 'package:flutter/material.dart';
import '../repositories/map_repository.dart';
import '../widgets/global_stats_widget.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final MapRepository _repo = MapRepository();
  bool _loading = true;
  
  double _tongDienTich = 0;
  int _tongDanSo = 0;
  double _matDoTrungBinh = 0;
  int _soLuongTinh = 0;
  int _soLuongXa = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load provinces data
    final provinces = await _repo.loadData();
    
    // Load communes data for stats
    final repo2 = MapRepository();
    await repo2.switchLayer(MapLayer.communes);
    final communes = repo2.activeUnits;

    if (mounted) {
      setState(() {
        _tongDienTich = _repo.tongDienTich(provinces);
        _tongDanSo = _repo.tongDanSo(provinces);
        _matDoTrungBinh = _repo.matDoTrungBinh(provinces);
        _soLuongTinh = provinces.length;
        _soLuongXa = communes.length;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF00E5FF)),
            SizedBox(height: 16),
            Text(
              'Đang tổng hợp số liệu...',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            )
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.public_rounded, size: 64, color: Color(0xFF00E5FF)),
              ),
              const SizedBox(height: 48),
              
              // Use the GlobalStatsWidget with a scale transform to make it larger
              Transform.scale(
                scale: 1.2,
                child: GlobalStatsWidget(
                  tongDienTich: _tongDienTich,
                  tongDanSo: _tongDanSo,
                  matDoTrungBinh: _matDoTrungBinh,
                  soLuongDonVi: _soLuongTinh, // Represents province level
                ),
              ),
              
              const SizedBox(height: 70),
              
              // Additional detailed dashboard panel
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2838),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSubStat(
                      Icons.map_rounded, 
                      'Cấp Tỉnh/TP', 
                      '$_soLuongTinh đơn vị', 
                      const Color(0xFF4ECDC4),
                    ),
                    const SizedBox(width: 48),
                    Container(width: 1, height: 48, color: const Color(0xFF2A3F54)),
                    const SizedBox(width: 48),
                    _buildSubStat(
                      Icons.location_city_rounded, 
                      'Cấp Phường/Xã', 
                      '$_soLuongXa đơn vị', 
                      const Color(0xFFA29BFE),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubStat(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
