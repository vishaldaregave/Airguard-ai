import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/geo_models.dart';
import '../controllers/environmental_controller.dart';
import '../controllers/geo_controller.dart';
import '../widgets/geo_interpolation_sheet.dart';
import '../widgets/geo_station_detail_sheet.dart';
import '../widgets/geo_tile_map.dart';

class GeoMapScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const GeoMapScreen({super.key, this.embedded = false});

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

    final mapStack = _buildMapStack(state, controller);

    if (widget.embedded) {
      return SafeArea(
        child: Column(
          children: [
            _buildEmbeddedHeader(state, controller),
            Expanded(child: mapStack),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Air Map',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              state.locationLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
        actions: _headerActions(state, controller),
      ),
      body: SafeArea(child: mapStack),
    );
  }

  Widget _buildEmbeddedHeader(
    GeoState state,
    GeoController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on,
                    size: 14, color: AppColors.primaryBlue),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(
                    state.locationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          ..._headerActions(state, controller),
        ],
      ),
    );
  }

  List<Widget> _headerActions(GeoState state, GeoController controller) {
    return [
      _circleAction(
        icon: state.showHeatmap
            ? Icons.blur_on
            : Icons.blur_off_outlined,
        color: state.showHeatmap
            ? AppColors.primaryBlue
            : AppColors.textSecondary,
        tooltip: 'Toggle pollution heatmap',
        onTap: () => controller.toggleHeatmap(),
      ),
      _circleAction(
        icon: state.showHotspots
            ? Icons.local_fire_department
            : Icons.local_fire_department_outlined,
        color: state.showHotspots
            ? AppColors.aqiPoor
            : AppColors.textSecondary,
        tooltip: 'Toggle pollution hotspots',
        onTap: () => controller.toggleHotspots(),
      ),
      _circleAction(
        icon: state.showModelGrid
            ? Icons.grid_view
            : Icons.grid_view_outlined,
        color: state.showModelGrid
            ? AppColors.primaryBlue
            : AppColors.textSecondary,
        tooltip: 'Toggle model grid points',
        onTap: () => controller.toggleModelGrid(),
      ),
      _circleAction(
        icon: Icons.refresh,
        color: AppColors.textSecondary,
        tooltip: 'Refresh map telemetry',
        onTap: () => controller.loadGeographicData(),
      ),
      const SizedBox(width: 4),
    ];
  }

  Widget _buildMapStack(GeoState state, GeoController controller) {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: GeoTileMap(
                centerLat: state.centerLat,
                centerLon: state.centerLon,
                radiusKm: state.radiusKm,
                observations: state.observations,
                hotspots: state.hotspots,
                activeInterpolation: state.activeInterpolation,
                selectedObservation: state.selectedObservation,
                heatmap: state.heatmap,
                selectedPollutant: state.selectedPollutant,
                showHotspots: state.showHotspots,
                showHeatmap: state.showHeatmap,
                showModelGrid: state.showModelGrid,
                onSelectObservation: (obs) =>
                    controller.selectObservation(obs),
                onMapTap: (lat, lon) =>
                    controller.requestInterpolation(lat, lon),
              ),
            ),
          ),
        ),

        // Pollutant selector chips
        Positioned(
          top: 16,
          left: 24,
          right: 24,
          child: SingleChildScrollView(
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
                    selectedColor: AppColors.primaryBlue,
                    backgroundColor:
                        AppColors.surface.withValues(alpha: 0.94),
                    labelStyle: TextStyle(
                      color:
                          isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 11,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.border,
                    ),
                    elevation: 0,
                    pressElevation: 0,
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Coverage summary pill
        Positioned(
          top: 60,
          left: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: state.coverage?.qualityColor ?? AppColors.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  state.coverage == null
                      ? 'Scanning monitoring network'
                      : '${state.coverage!.coverageQuality} coverage • '
                          '${state.observations.length} stations • '
                          'tap map to interpolate',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Heat map scale legend
        if (state.showHeatmap && state.heatmap != null) ...[
          Positioned(
            top: 92,
            right: 24,
            child: _HeatScaleLegend(heatmap: state.heatmap!),
          ),
        ],

        // Recenter on current location
        Positioned(
          right: 24,
          bottom: 76,
          child: FloatingActionButton.small(
            heroTag: 'map_recenter_fab',
            backgroundColor: AppColors.surface,
            elevation: 2,
            onPressed: () => ref
                .read(environmentalControllerProvider.notifier)
                .locateMe(),
            child: const Icon(
              Icons.my_location,
              color: AppColors.primaryBlue,
              size: 19,
            ),
          ),
        ),

        // Legend
        Positioned(
          left: 24,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showLegend) _buildLegend(),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'map_legend_fab',
                backgroundColor: AppColors.surface,
                elevation: 2,
                onPressed: () =>
                    setState(() => _showLegend = !_showLegend),
                child: Icon(
                  _showLegend ? Icons.layers_clear : Icons.layers_outlined,
                  color: AppColors.primaryBlue,
                  size: 19,
                ),
              ),
            ],
          ),
        ),

        if (state.isLoading && state.observations.isEmpty)
          const Positioned(
            top: 104,
            left: 0,
            right: 0,
            child: Center(
              child: _MapStatusPill(
                label: 'Scanning spatial telemetry…',
                color: AppColors.primaryBlue,
              ),
            ),
          ),

        if (state.isInterpolating)
          const Positioned(
            top: 104,
            left: 0,
            right: 0,
            child: Center(
              child: _MapStatusPill(
                label: 'Estimating air quality at this point…',
                color: AppColors.cyanAccent,
              ),
            ),
          ),

        if (state.errorMessage != null)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.aqiPoor),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.aqiPoor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => controller.loadGeographicData(),
                    child: const Text(
                      'RETRY',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

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
    );
  }

  Widget _circleAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AIR QUALITY LEGEND',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          _legendItem('Good (0–50)', AppColors.aqiGood),
          _legendItem('Satisfactory (51–100)', AppColors.aqiSatisfactory),
          _legendItem('Moderate (101–200)', AppColors.aqiModerate),
          _legendItem('Poor (201–300)', AppColors.aqiPoor),
          _legendItem('Very Poor (301–400)', AppColors.aqiVeryPoor),
          _legendItem('Severe (401–500)', AppColors.aqiSevere),
          const Divider(color: AppColors.border, height: 14),
          const Row(
            children: [
              Icon(Icons.circle, size: 9, color: AppColors.primaryBlue),
              SizedBox(width: 6),
              Text('Your location',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.sensors, size: 11, color: AppColors.cyanAccent),
              SizedBox(width: 5),
              Text('Ground monitor',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.grid_view, size: 10, color: AppColors.textMuted),
              SizedBox(width: 6),
              Text('Atmospheric model grid',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.local_fire_department,
                  size: 11, color: AppColors.aqiPoor),
              SizedBox(width: 5),
              Text('Pollution hotspot',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact green→red scale showing what the heat map colours mean.
class _HeatScaleLegend extends StatelessWidget {
  final GeoHeatmapModel heatmap;

  const _HeatScaleLegend({required this.heatmap});

  @override
  Widget build(BuildContext context) {
    final min = heatmap.minValue;
    final max = heatmap.maxValue;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heatmap.pollutant,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: 92,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                colors: [
                  AppColors.aqiGood,
                  AppColors.aqiSatisfactory,
                  AppColors.aqiModerate,
                  AppColors.aqiPoor,
                  AppColors.aqiVeryPoor,
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 92,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  min == null ? '--' : min.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  max == null ? '--' : max.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
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

class _MapStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _MapStatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
