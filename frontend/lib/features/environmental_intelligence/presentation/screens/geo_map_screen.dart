import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/geo_controller.dart';
import '../widgets/geo_canvas_map.dart';
import '../widgets/geo_station_detail_sheet.dart';
import '../widgets/geo_interpolation_sheet.dart';

class GeoMapScreen extends ConsumerStatefulWidget {
  const GeoMapScreen({super.key});

  @override
  ConsumerState<GeoMapScreen> createState() => _GeoMapScreenState();
}

class _GeoMapScreenState extends ConsumerState<GeoMapScreen> {
  bool _showLegend = false;

  final List<String> _pollutants = [
    'AQI',
    'PM2.5',
    'PM10',
    'NO2',
    'SO2',
    'CO',
    'O3',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(geoControllerProvider);
    final controller = ref.read(geoControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.cyanAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.radar,
                color: AppColors.cyanAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GEOGRAPHIC INTELLIGENCE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'SPATIAL INTERPOLATION & HOTSPOTS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.cyanAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Toggle Hotspots Filter
          IconButton(
            onPressed: () => controller.toggleHotspots(),
            icon: Icon(
              state.showHotspots ? Icons.local_fire_department : Icons.local_fire_department_outlined,
              color: state.showHotspots ? AppColors.aqiPoor : AppColors.textMuted,
            ),
            tooltip: 'Toggle Hotspots',
          ),
          // Toggle Model Grid Filter
          IconButton(
            onPressed: () => controller.toggleModelGrid(),
            icon: Icon(
              state.showModelGrid ? Icons.grid_view : Icons.grid_view_outlined,
              color: state.showModelGrid ? AppColors.cyanAccent : AppColors.textMuted,
            ),
            tooltip: 'Toggle Model Grid',
          ),
          // Refresh Button
          IconButton(
            onPressed: () => controller.loadGeographicData(),
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            tooltip: 'Refresh Telemetry',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Geographic Interactive Canvas Map
          Positioned.fill(
            child: GeoCanvasMap(
              centerLat: state.centerLat,
              centerLon: state.centerLon,
              radiusKm: state.radiusKm,
              selectedPollutant: state.selectedPollutant,
              observations: state.observations,
              hotspots: state.hotspots,
              selectedObservation: state.selectedObservation,
              activeInterpolation: state.activeInterpolation,
              showHotspots: state.showHotspots,
              showModelGrid: state.showModelGrid,
              onSelectObservation: (obs) => controller.selectObservation(obs),
              onMapTap: (lat, lon) => controller.requestInterpolation(lat, lon),
            ),
          ),

          // 2. Top Bar: Pollutant Selector Chips & Network Coverage Banner
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                // Coverage Status Pill Banner
                if (state.coverage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: state.coverage!.qualityColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${state.coverage!.coverageQuality} COVERAGE • ${state.observations.length} STATIONS • TAP MAP TO INTERPOLATE',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Horizontal Pollutant Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _pollutants.map((pol) {
                      final isSelected = state.selectedPollutant == pol;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(pol),
                          selected: isSelected,
                          onSelected: (_) => controller.selectPollutant(pol),
                          selectedColor: AppColors.cyanAccent.withValues(alpha: 0.25),
                          backgroundColor: AppColors.surface.withValues(alpha: 0.85),
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.cyanAccent : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 11,
                          ),
                          side: BorderSide(
                            color: isSelected ? AppColors.cyanAccent : AppColors.border,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // 3. Floating Map Legend Toggle & Drawer
          Positioned(
            bottom: state.selectedObservation != null || state.activeInterpolation != null ? 360 : 20,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showLegend)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MAP LEGEND',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildLegendItem('● Good (0-50)', AppColors.aqiGood),
                        _buildLegendItem('● Satisfactory (51-100)', AppColors.aqiSatisfactory),
                        _buildLegendItem('● Moderate (101-200)', AppColors.aqiModerate),
                        _buildLegendItem('● Poor (201-300)', AppColors.aqiPoor),
                        _buildLegendItem('● Very Poor (301-400)', AppColors.aqiVeryPoor),
                        _buildLegendItem('● Severe (401-500)', AppColors.aqiSevere),
                        const Divider(color: AppColors.border, height: 12),
                        const Row(
                          children: [
                            Icon(Icons.circle, size: 10, color: AppColors.cyanAccent),
                            SizedBox(width: 6),
                            Text('Physical Ground Monitor', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Row(
                          children: [
                            Icon(Icons.diamond, size: 10, color: AppColors.textMuted),
                            SizedBox(width: 6),
                            Text('Atmospheric Model Grid', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Row(
                          children: [
                            Icon(Icons.warning, size: 10, color: AppColors.aqiPoor),
                            SizedBox(width: 6),
                            Text('Pollution Hotspot Cluster', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),

                FloatingActionButton.small(
                  heroTag: 'map_legend_fab',
                  backgroundColor: AppColors.surface,
                  onPressed: () {
                    setState(() {
                      _showLegend = !_showLegend;
                    });
                  },
                  child: Icon(
                    _showLegend ? Icons.layers_clear : Icons.layers_outlined,
                    color: AppColors.cyanAccent,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),

          // 4. Loading Shimmer Overlay
          if (state.isLoading)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.cyanAccent,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Scanning spatial telemetry...',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Interpolation Progress Pill
          if (state.isInterpolating)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cyanAccent),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.cyanAccent,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Computing IDW spatial weights...',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. Error Banner with Retry
          if (state.errorMessage != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.aqiPoor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.aqiPoor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                      ),
                    ),
                    TextButton(
                      onPressed: () => controller.loadGeographicData(),
                      child: const Text('RETRY', style: TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),

          // 7. Bottom Sheets: Station Detail or Interpolation Result
          if (state.selectedObservation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GeoStationDetailSheet(
                observation: state.selectedObservation!,
                onClose: () => controller.clearSelection(),
              ),
            )
          else if (state.activeInterpolation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GeoInterpolationSheet(
                interpolation: state.activeInterpolation!,
                onClose: () => controller.clearInterpolation(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
