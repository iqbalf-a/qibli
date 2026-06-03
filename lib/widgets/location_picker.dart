import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/theme.dart';
import '../providers/settings_provider.dart';

class LocationPicker extends StatefulWidget {
  final AppTheme appTheme;
  final void Function(ManualLocation location) onSelect;
  final VoidCallback onDismiss;

  const LocationPicker({
    super.key,
    required this.appTheme,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allCities = [];
  List<Map<String, dynamic>> _filteredCities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final rawJson = await rootBundle.loadString('assets/cities.json');
      final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
      _allCities = decoded.cast<Map<String, dynamic>>();
      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.length < 2) {
      setState(() => _filteredCities = []);
      return;
    }
    final results = _allCities
        .where((city) {
          final cityName    = (city['city']    as String? ?? '').toLowerCase();
          final countryName = (city['country'] as String? ?? '').toLowerCase();
          return cityName.contains(trimmed) || countryName.contains(trimmed);
        })
        .take(60)
        .toList();
    setState(() => _filteredCities = results);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = widget.appTheme;

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: const Color(0x8C000000),
        child: GestureDetector(
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (sheetContext, scrollController) => Container(
              decoration: BoxDecoration(
                color: appTheme.bg2,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(top: BorderSide(color: appTheme.line)),
              ),
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: appTheme.lineStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select City',
                        style: GoogleFonts.inter(
                          fontSize: 17, fontWeight: FontWeight.w700,
                          color: appTheme.text,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onDismiss,
                        child: Icon(Icons.close, size: 20, color: appTheme.textMute),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: appTheme.bg3,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: appTheme.line),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          child: Icon(Icons.search, size: 18, color: appTheme.textMute),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: _onSearchChanged,
                            style: GoogleFonts.inter(
                              fontSize: 14, color: appTheme.text,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search city or country...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14, color: appTheme.textMute,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            cursorColor: appTheme.accent,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Icon(Icons.close, size: 16, color: appTheme.textMute),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Results list
                  Expanded(
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: appTheme.accent))
                        : _filteredCities.isEmpty
                            ? Center(
                                child: Text(
                                  _searchController.text.length < 2
                                      ? 'Type at least 2 characters'
                                      : 'No cities found',
                                  style: GoogleFonts.inter(
                                    fontSize: 13, color: appTheme.textMute,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _filteredCities.length,
                                itemBuilder: (listContext, index) {
                                  final city = _filteredCities[index];
                                  final cityName    = city['city']    as String? ?? '';
                                  final countryName = city['country'] as String? ?? '';
                                  final latitude    = (city['lat']    as num?)?.toDouble() ?? 0.0;
                                  final longitude   = (city['lng']    as num?)?.toDouble() ?? 0.0;

                                  return GestureDetector(
                                    onTap: () => widget.onSelect(ManualLocation(
                                      city: cityName,
                                      country: countryName,
                                      lat: latitude,
                                      lng: longitude,
                                    )),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.md, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border(
                                            bottom: BorderSide(color: appTheme.line)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_outlined,
                                            size: 16, color: appTheme.textMute,
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  cityName,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14, fontWeight: FontWeight.w500,
                                                    color: appTheme.text,
                                                  ),
                                                ),
                                                Text(
                                                  countryName,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12, color: appTheme.textMute,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(Icons.chevron_right, size: 16, color: appTheme.textMute),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
