import 'dart:async';
import 'package:flutter/material.dart';
import '../models/map_detail_level.dart';
import '../models/search_result.dart';
import '../repositories/map_repository.dart';

class MapSearchOverlay extends StatefulWidget {
  final MapRepository repository;
  final ValueChanged<SearchResult> onResultSelected;
  final int resetToken;

  const MapSearchOverlay({
    super.key,
    required this.repository,
    required this.onResultSelected,
    this.resetToken = 0,
  });

  @override
  State<MapSearchOverlay> createState() => _MapSearchOverlayState();
}

class _MapSearchOverlayState extends State<MapSearchOverlay> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<SearchResult> _results = const [];
  bool _showDropdown = false;
  int _lastResetToken = 0;

  @override
  void initState() {
    super.initState();
    _lastResetToken = widget.resetToken;
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant MapSearchOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetToken != _lastResetToken) {
      _lastResetToken = widget.resetToken;
      _debounce?.cancel();
      _controller.clear();
      _focusNode.unfocus();
      setState(() {
        _results = const [];
        _showDropdown = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final query = value.trim();
      if (query.isEmpty) {
        setState(() {
          _results = const [];
          _showDropdown = false;
        });
        return;
      }

      final results = widget.repository.searchUnits(query);
      setState(() {
        _results = results;
        _showDropdown = true;
      });
    });
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _results = const [];
      _showDropdown = false;
    });
  }

  void _selectResult(SearchResult result) {
    _debounce?.cancel();
    _controller.value = TextEditingValue(
      text: result.unit.ten,
      selection: TextSelection.collapsed(offset: result.unit.ten.length),
    );
    setState(() {
      _results = const [];
      _showDropdown = false;
    });
    widget.onResultSelected(result);
    _focusNode.unfocus();
  }

  String _truncate(String value, [int maxLength = 60]) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 1)}…';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: const Color(0xDD1B2838),
            borderRadius: BorderRadius.circular(12),
            elevation: 8,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onQueryChanged,
              onTap: () {
                if (_results.isNotEmpty) {
                  setState(() => _showDropdown = true);
                }
              },
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tìm tỉnh, xã, tên cũ...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF00E5FF),
                  size: 20,
                ),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: Colors.white54,
                        onPressed: _clearSearch,
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2A3F54)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2A3F54)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          if (_showDropdown && _controller.text.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: const Color(0xEE1B2838),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A3F54)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Không tìm thấy đơn vị',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _results.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        final unit = result.unit;
                        final isProvince =
                            result.level == MapDetailLevel.provinces;
                        final badgeLabel = isProvince ? 'Tỉnh/TP' : 'Phường/Xã';
                        final badgeColor = isProvince
                            ? const Color(0xFF4ECDC4)
                            : const Color(0xFFA29BFE);
                        final subtitle = isProvince
                            ? unit.capHanhChinh
                            : (unit.parentTen ?? unit.capHanhChinh);

                        return InkWell(
                          onTap: () => _selectResult(result),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        unit.ten,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: badgeColor.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        badgeLabel,
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                if (result.matchKind ==
                                    SearchMatchKind.predecessor) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Khớp tiền thân: ${_truncate(result.matchLabel)}',
                                    style: const TextStyle(
                                      color: Color(0xFFFFB74D),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}
