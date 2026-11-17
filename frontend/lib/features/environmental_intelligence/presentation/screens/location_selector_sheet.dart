import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/station_model.dart';

class LocationSelectorSheet extends StatefulWidget {
  final List<MonitoringStationSummary> stations;
  final MonitoringStationSummary? currentStation;
  final UserLocationResult? currentLocation;
  final ValueChanged<MonitoringStationSummary> onStationSelected;
  final void Function(double lat, double lon, String cityName, String? stateName, String? countryName) onCitySelected;
  final VoidCallback onDetectLocation;

  const LocationSelectorSheet({
    super.key,
    required this.stations,
    required this.currentStation,
    required this.currentLocation,
    required this.onStationSelected,
    required this.onCitySelected,
    required this.onDetectLocation,
  });

  @override
  State<LocationSelectorSheet> createState() => _LocationSelectorSheetState();
}

class _LocationSelectorSheetState extends State<LocationSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  final LocationService _locationService = LocationService();
  List<CitySearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchResults = LocationService.popularCities;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = LocationService.popularCities;
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isSearching = true);
      try {
        final results = await _locationService.searchCities(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Switch city or choose a local monitoring station',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search input
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search city (e.g. Pune, Mumbai, London)...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Auto-detect current location banner
          InkWell(
            onTap: () {
              Navigator.pop(context);
              widget.onDetectLocation();
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.my_location, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detect My Location',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        Text(
                          'Automatically resolve via network & GPS telemetry',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.primaryBlue),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Content Tabs / Sections
          Expanded(
            child: ListView(
              children: [
                // Quick Select Cities
                const Text(
                  'POPULAR CITIES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _searchResults.map((city) {
                    final isCurrent = widget.currentLocation?.cityName?.toLowerCase() == city.name.toLowerCase();

                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onCitySelected(
                          city.latitude,
                          city.longitude,
                          city.name,
                          city.state,
                          city.country,
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isCurrent ? AppColors.primaryBlue : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCurrent ? AppColors.primaryBlue : AppColors.border,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_city,
                              size: 14,
                              color: isCurrent ? Colors.white : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              city.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                color: isCurrent ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Nearby Discovered Monitoring Stations
                if (widget.stations.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'NEARBY MONITORING STATIONS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${widget.stations.length} found',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...widget.stations.map((st) {
                    final isSelected = widget.currentStation?.stationId == st.stationId;
                    final provColor = AppColors.getProvenanceColor(st.dataSourceType);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryBlue.withValues(alpha: 0.05)
                            : AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryBlue : AppColors.border,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.pop(context);
                          widget.onStationSelected(st);
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: provColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.sensors, size: 18, color: provColor),
                        ),
                        title: Text(
                          st.stationName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${st.provider} • ${st.distanceKm != null ? "${st.distanceKm!.toStringAsFixed(1)} km away" : "Local Point"}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: provColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: provColor.withValues(alpha: 0.4), width: 0.8),
                          ),
                          child: Text(
                            st.dataSourceType,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: provColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
