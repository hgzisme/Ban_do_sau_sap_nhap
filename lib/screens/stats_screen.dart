import 'package:flutter/material.dart';
import '../repositories/map_repository.dart';
import '../widgets/region_stats_widget.dart';
import '../models/admin_unit.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final MapRepository _repo = MapRepository();
  bool _loading = true;
  List<AdminUnit> _provinces = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load provinces data
    final provinces = await _repo.loadData();
    
    if (mounted) {
      setState(() {
        _provinces = provinces;
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                child: RegionStatsWidget(provinces: _provinces),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
