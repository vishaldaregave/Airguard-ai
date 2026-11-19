import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/geo_models.dart';

enum GeoBasemapStyle { street, satellite }

/// Chooses a readable zoom level for a circular search radius.
double geoZoomForRadius(double radiusKm) {
  final radius = radiusKm.clamp(1.0, 200.0);
  final zoom = 11.2 - (math.log(radius / 10) / math.ln2);
  return zoom.clamp(7.0, 14.0);
}

class GeoTileMap extends StatefulWidget {
  final double centerLat;
  final double centerLon;
  final double radiusKm;
  final List<GeoObservationModel> observations;
  final List<HotspotClusterModel> hotspots;
  final SpatialInterpolationModel? activeInterpolation;
  final GeoObservationModel? selectedObservation;
  final GeoHeatmapModel? heatmap;
  final String selectedPollutant;
  final bool showHotspots;
  final bool showHeatmap;
  final bool showModelGrid;
  final ValueChanged<GeoObservationModel> onSelectObservation;
  final void Function(double lat, double lon) onMapTap;

  const GeoTileMap({
    super.key,
    required this.centerLat,
    required this.centerLon,
    required this.radiusKm,
    required this.observations,
    required this.hotspots,
    required this.activeInterpolation,
    required this.selectedObservation,
    this.heatmap,
    required this.selectedPollutant,
    required this.showHotspots,
    this.showHeatmap = true,
    required this.showModelGrid,
    required this.onSelectObservation,
    required this.onMapTap,
  });

  @override
  State<GeoTileMap> createState() => _GeoTileMapState();
}

class _GeoTileMapState extends State<GeoTileMap> {
  final MapController _mapController = MapController();
  GeoBasemapStyle _style = GeoBasemapStyle.street;

  @override
  void didUpdateWidget(covariant GeoTileMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moved = oldWidget.centerLat != widget.centerLat ||
        oldWidget.centerLon != widget.centerLon ||
        oldWidget.radiusKm != widget.radiusKm;

    if (moved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(
          LatLng(widget.centerLat, widget.centerLon),
          geoZoomForRadius(widget.radiusKm),
        );
      });
    }
  }

  String get _tileUrl => _style == GeoBasemapStyle.street
      ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
      : 'https://server.arcgisonline.com/ArcGIS/rest/services/'
          'World_Imagery/MapServer/tile/{z}/{y}/{x}';

  String get _attribution => _style == GeoBasemapStyle.street
      ? '© OpenStreetMap contributors'
      : 'Imagery © Esri, Maxar, Earthstar Geographics';

  @override
  Widget build(BuildContext context) {
    final center = LatLng(widget.centerLat, widget.centerLon);
    final selectedId = widget.selectedObservation?.stationId;

    final visibleObservations = widget.observations.where((obs) {
      if (!widget.showModelGrid &&
          obs.stationType == StationType.atmosphericModelGrid) {
        return false;
      }
      return obs.latitude != 0 && obs.longitude != 0;
    }).toList();

    final stationMarkers = visibleObservations.map((obs) {
      return Marker(
        point: LatLng(obs.latitude, obs.longitude),
        width: 84,
        height: 56,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () => widget.onSelectObservation(obs),
          child: _StationMarker(
            observation: obs,
            selected: obs.stationId == selectedId,
            pollutant: widget.selectedPollutant,
          ),
        ),
      );
    }).toList();

    final target = widget.activeInterpolation;
    final rayPolylines = <Polyline>[];
    if (target != null) {
      final rays = target.contributingStations
          .map((s) => LatLng(s.latitude, s.longitude))
          .toList();
      if (rays.isNotEmpty) {
        final origin = LatLng(target.targetLat, target.targetLon);
        for (final stationPoint in rays) {
          rayPolylines.add(
            Polyline(
              points: [origin, stationPoint],
              strokeWidth: 1.6,
              color: AppColors.cyanAccent.withValues(alpha: 0.65),
            ),
          );
        }
      }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: geoZoomForRadius(widget.radiusKm),
            minZoom: 3,
            maxZoom: 18,
            backgroundColor: AppColors.background,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, latLng) =>
                widget.onMapTap(latLng.latitude, latLng.longitude),
          ),
          children: [
            TileLayer(
              urlTemplate: _tileUrl,
              userAgentPackageName: 'com.airguard.ai',
              maxNativeZoom: 19,
            ),
            if (widget.showHeatmap &&
                widget.heatmap != null &&
                widget.heatmap!.cells.isNotEmpty)
              HeatmapLayer(
                heatmap: widget.heatmap!,
                opacity: 0.8,
              ),
            if (widget.showHotspots && widget.hotspots.isNotEmpty)
              CircleLayer(
                circles: widget.hotspots
                    .map(
                      (hotspot) => CircleMarker(
                        point:
                            LatLng(hotspot.centerLat, hotspot.centerLon),
                        radius: hotspot.radiusKm * 1000,
                        useRadiusInMeter: true,
                        color: hotspot.severity.color.withValues(alpha: 0.16),
                        borderColor:
                            hotspot.severity.color.withValues(alpha: 0.85),
                        borderStrokeWidth: 1.6,
                      ),
                    )
                    .toList(),
              ),
            if (rayPolylines.isNotEmpty)
              PolylineLayer(polylines: rayPolylines),
            MarkerLayer(markers: stationMarkers),
            MarkerLayer(
              markers: [
                Marker(
                  point: center,
                  width: 44,
                  height: 44,
                  child: const _UserLocationMarker(),
                ),
                if (target != null &&
                    target.targetLat != 0 &&
                    target.targetLon != 0)
                  Marker(
                    point: LatLng(target.targetLat, target.targetLon),
                    width: 44,
                    height: 44,
                    child: const _InterpolationMarker(),
                  ),
              ],
            ),
          ],
        ),

        // Basemap style switcher
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StyleChip(
                  label: 'Street',
                  icon: Icons.map_outlined,
                  selected: _style == GeoBasemapStyle.street,
                  onTap: () =>
                      setState(() => _style = GeoBasemapStyle.street),
                ),
                _StyleChip(
                  label: 'Satellite',
                  icon: Icons.satellite_alt_outlined,
                  selected: _style == GeoBasemapStyle.satellite,
                  onTap: () =>
                      setState(() => _style = GeoBasemapStyle.satellite),
                ),
              ],
            ),
          ),
        ),

        // Attribution (required by tile providers)
        Positioned(
          left: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _attribution,
              style: const TextStyle(
                fontSize: 8,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Renders the interpolated pollution surface as soft AQI-coloured blobs.
///
/// Cells are projected with the live [MapCamera] each frame so the surface stays
/// aligned while the user pans and zooms. Cell opacity follows the backend's
/// per-cell confidence, so areas far from any station fade out instead of
/// implying measurement accuracy that does not exist.
class HeatmapLayer extends StatelessWidget {
  final GeoHeatmapModel heatmap;
  final double opacity;

  const HeatmapLayer({
    super.key,
    required this.heatmap,
    this.opacity = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MobileLayerTransformer(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size(camera.nonRotatedSize.width, camera.nonRotatedSize.height),
          painter: _HeatmapPainter(
            heatmap: heatmap,
            camera: camera,
            opacity: opacity,
          ),
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final GeoHeatmapModel heatmap;
  final MapCamera camera;
  final double opacity;

  _HeatmapPainter({
    required this.heatmap,
    required this.camera,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cells = heatmap.cells;
    if (cells.isEmpty) return;

    // Scale the blend radius with zoom so neighbouring cells overlap smoothly.
    // The multiplier keeps adjacent blobs overlapping even when cells are sparse.
    final cellRadius = (camera.zoom * 4.2).clamp(34.0, 150.0);

    final minValue = heatmap.minValue ?? 0.0;
    final maxValue = heatmap.maxValue ?? 0.0;
    final span = maxValue - minValue;
    // When the surface is genuinely flat there is no relative scale to show.
    final hasVariation = span.abs() > 0.5;
    final showLabels = cells.length <= 90;

    for (final cell in cells) {
      final offset = camera.latLngToScreenOffset(
        LatLng(cell.latitude, cell.longitude),
      );

      // Skip cells comfortably outside the viewport.
      if (offset.dx < -cellRadius ||
          offset.dy < -cellRadius ||
          offset.dx > size.width + cellRadius ||
          offset.dy > size.height + cellRadius) {
        continue;
      }

      final color = hasVariation
          ? _relativeColor((cell.value - minValue) / span)
          : _colorForValue(cell.value);
      final alpha = (opacity * (0.35 + 0.65 * cell.confidence.clamp(0.0, 1.0)))
          .clamp(0.0, 1.0);

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.62),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(
          Rect.fromCircle(center: offset, radius: cellRadius),
        );

      canvas.drawCircle(offset, cellRadius, paint);

      if (showLabels) {
        _paintCellLabel(canvas, offset, cell.value);
      }
    }
  }

  /// Draws the AQI/reading for a cell so individual locations are readable.
  void _paintCellLabel(Canvas canvas, Offset center, double value) {
    final label = value >= 100
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(0);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(color: Colors.white, blurRadius: 3),
            Shadow(color: Colors.white, blurRadius: 3),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2),
    );
  }

  bool get _isAqi => heatmap.unit == 'index';

  Color _colorForValue(double value) {
    if (!_isAqi) {
      // For concentrations, map relative position within the observed range.
      final minValue = heatmap.minValue ?? 0.0;
      final maxValue = heatmap.maxValue ?? value;
      final span = (maxValue - minValue).abs();
      final ratio = span < 0.0001 ? 0.0 : (value - minValue) / span;
      return _relativeColor(ratio.clamp(0.0, 1.0));
    }
    return AppColors.getAqiColor(value.round());
  }

  /// Maps 0..1 within the observed range onto a green → red ramp.
  ///
  /// Relative colouring is what makes the map readable: within a small area the
  /// absolute CPCB bands often all land in one category, so a relative scale
  /// still shows where pollution is higher or lower.
  Color _relativeColor(double ratio) {
    final t = ratio.clamp(0.0, 1.0);
    if (t < 0.25) {
      return Color.lerp(AppColors.aqiGood, AppColors.aqiSatisfactory, t / 0.25)!;
    }
    if (t < 0.5) {
      return Color.lerp(
        AppColors.aqiSatisfactory,
        AppColors.aqiModerate,
        (t - 0.25) / 0.25,
      )!;
    }
    if (t < 0.75) {
      return Color.lerp(
        AppColors.aqiModerate,
        AppColors.aqiPoor,
        (t - 0.5) / 0.25,
      )!;
    }
    return Color.lerp(
      AppColors.aqiPoor,
      AppColors.aqiVeryPoor,
      (t - 0.75) / 0.25,
    )!;
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.heatmap != heatmap ||
        oldDelegate.camera.center != camera.center ||
        oldDelegate.camera.zoom != camera.zoom ||
        oldDelegate.opacity != opacity;
  }
}

class _StyleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _StyleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationMarker extends StatelessWidget {
  final GeoObservationModel observation;
  final bool selected;
  final String pollutant;

  const _StationMarker({
    required this.observation,
    required this.selected,
    required this.pollutant,
  });

  String get _value {
    switch (pollutant.toUpperCase()) {
      case 'PM2.5':
        return _format(observation.pm25);
      case 'PM10':
        return _format(observation.pm10);
      case 'NO2':
        return _format(observation.no2);
      case 'SO2':
        return _format(observation.so2);
      case 'CO':
        return _format(observation.co);
      case 'O3':
        return _format(observation.o3);
      case 'AQI':
      default:
        return observation.aqi?.toString() ?? '--';
    }
  }

  String _format(double? value) {
    if (value == null) return '--';
    return value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final color = observation.aqiColor;
    final isPhysical =
        observation.stationType == StationType.physicalMonitor;
    final textColor =
        color.computeLuminance() > 0.55 ? AppColors.textPrimary : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected)
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: isPhysical ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isPhysical ? null : BorderRadius.circular(10),
              color: AppColors.primaryBlue.withValues(alpha: 0.16),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.75),
                width: 1.6,
              ),
            ),
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: isPhysical ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isPhysical ? null : BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.6),
              ),
              child: Text(
                _value,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ),
          )
        else
          Container(
            width: isPhysical ? 28 : 26,
            height: isPhysical ? 28 : 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: isPhysical ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isPhysical ? null : BorderRadius.circular(7),
              border: Border.all(color: Colors.white, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _value,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ),
        if (selected) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              observation.stationName.split(',').first.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryBlue.withValues(alpha: 0.18),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryBlue,
            border: Border.all(color: Colors.white, width: 2.6),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.45),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterpolationMarker extends StatelessWidget {
  const _InterpolationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cyanAccent.withValues(alpha: 0.2),
        border: Border.all(color: AppColors.cyanAccent, width: 2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.cyanAccent,
        ),
      ),
    );
  }
}
