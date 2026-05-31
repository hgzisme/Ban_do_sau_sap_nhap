import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'stats_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isMenuOpen = false;
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _menuItems = [
    {
      'title': 'Bản đồ sáp nhập',
      'icon': Icons.map_rounded,
      'content': const MapScreen(), 
    },
    {
      'title': 'Thống kê tổng quan',
      'icon': Icons.bar_chart_rounded,
      'content': const StatsScreen(),
    },
    {
      'title': 'Hướng dẫn sử dụng',
      'icon': Icons.menu_book_rounded,
      'content': _buildPlaceholder('Hướng dẫn sử dụng chi tiết về bản đồ'),
    },
    {
      'title': 'Cài đặt',
      'icon': Icons.settings_rounded,
      'content': _buildPlaceholder('Cài đặt hệ thống'),
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _selectMenu(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _toggleMenu();
  }

  static Widget _buildPlaceholder(String text) {
    return Container(
      color: const Color(0xFF0F1923),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction_rounded, size: 64, color: Color(0xFF00E5FF)),
            const SizedBox(height: 16),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tính năng đang được phát triển...',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine slide distance based on screen width, max 280
    final screenWidth = MediaQuery.of(context).size.width;
    final maxSlide = screenWidth < 400 ? screenWidth * 0.7 : 280.0;

    return Scaffold(
      backgroundColor: const Color(0xFF1B2838), // Drawer background
      body: Stack(
        children: [
          // ── MENU (BACKGROUND) ──
          _buildMenu(maxSlide),

          // ── MAIN CONTENT (FOREGROUND) ──
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              double slide = maxSlide * _animationController.value;
              double scale = 1 - (_animationController.value * 0.12); // Scale down to 88%
              double radius = _animationController.value * 28;

              return Transform.translate(
                offset: Offset(slide, 0),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.centerLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        if (_isMenuOpen)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 24,
                            offset: const Offset(-8, 0),
                          ),
                      ],
                    ),
                    child: _buildMainContent(),
                  ),
                ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(double width) {
    return SafeArea(
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User / App Logo info
            const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFF00E5FF),
                  radius: 22,
                  child: Icon(Icons.map_outlined, color: Color(0xFF0F1923), size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'VietMap Hub',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            
            // Menu Items
            Expanded(
              child: ListView.builder(
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final isSelected = _selectedIndex == index;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF00E5FF).withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF00E5FF).withValues(alpha: 0.3) : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Icon(
                        item['icon'],
                        color: isSelected ? const Color(0xFF00E5FF) : Colors.white54,
                        size: 26,
                      ),
                      title: Text(
                        item['title'],
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onTap: () => _selectMenu(index),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    // Current selected view
    final currentView = _menuItems[_selectedIndex]['content'] as Widget;
    final currentTitle = _menuItems[_selectedIndex]['title'] as String;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B2838),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _isMenuOpen ? Icons.arrow_back_ios_new_rounded : Icons.menu_rounded,
          ),
          color: Colors.white,
          splashRadius: 24,
          onPressed: _toggleMenu,
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            currentTitle,
            key: ValueKey<String>(currentTitle),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.white.withValues(alpha: 0.05),
            height: 1.0,
          ),
        ),
      ),
      body: GestureDetector(
        // Allow tapping on the main content to close the menu if it's open
        onTap: _isMenuOpen ? _toggleMenu : null,
        child: AbsorbPointer(
          absorbing: _isMenuOpen,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.05),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_selectedIndex),
              child: currentView,
            ),
          ),
        ),
      ),
    );
  }
}
 
