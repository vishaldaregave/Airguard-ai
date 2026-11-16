import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/geo_models.dart';

class GeoCanvasMap extends StatelessWidget {
  final double centerLat;
  final double centerLon;
  final double radiusKm;
  final List<GeoObservationModel> observations;
  final List<HotspotClusterModel> hotspots;
  final SpatialInterpolationModel? activeInterpolation;
  final String? selectedStationId;
  final GeoObservationModel? selectedObservation;
  final String selectedPollutant;
  final bool showHotspots;
  final bool showModelGrid;
  final ValueChanged<String>? onStationSelected;
  final ValueChanged<GeoObservationModel>? onSelectObservation;
  final void Function(double lat, double lon)? onMapTapped;
  final void Function(double lat, double lon)? onMapTap;

  const GeoCanvasMap({
    super.key,
    required this.centerLat,
    required this.centerLon,
    this.radiusKm = 50.0,
    required this.observations,
    required this.hotspots,
    this.activeInterpolation,
    this.selectedStationId,
    this.selectedObservation,
    required this.selectedPollutant,
    this.showHotspots = true,
    this.showModelGrid = true,
    this.onStationSelected,
    this.onSelectObservation,
    this.onMapTapped,
    this.onMapTap,
  });

  String? get _effectiveSelectedStationId =>
      selectedStationId ?? selectedObservation?.stationId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onTapUp: (details) {
            final hitStationId = _findStationAtOffset(details.localPosition, size);
            if (hitStationId != null) {
              onStationSelected?.call(hitStationId);
              final matchObs = observations.where((o) => o.stationId == hitStationId).firstOrNull;
              if (matchObs != null) {
                onSelectObservation?.call(matchObs);
              }
            } else {
              // Convert tap position to geographic coordinates
              final geoCoord = _screenToGeo(details.localPosition, size);
              (onMapTap ?? onMapTapped)?.call(geoCoord.dx, geoCoord.dy);
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CustomPaint(
              size: size,
              painter: _GeoMapPainter(
                centerLat: centerLat,
                centerLon: centerLon,
                radiusKm: radiusKm,
                observations: observations,
                hotspots: hotspots,
                activeInterpolation: activeInterpolation,
                selectedStationId: _effectiveSelectedStationId,
                selectedPollutant: selectedPollutant,
                showHotspots: showHotspots,
                showModelGrid: showModelGrid,
              ),
            ),
          ),
        );
      },
    );
  }

  String? _findStationAtOffset(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = (math.min(size.width, size.height) * 0.42) / radiusKm;

    for (final obs in observations) {
      if (!showModelGrid && obs.stationType == StationType.atmosphericModelGrid) {
        continue;
      }
      final sPos = _geoToScreen(obs.latitude, obs.longitude, center, scale);
      if ((localPos - sPos).distance <= 20) {
        return obs.stationId;
      }
    }
    return null;
  }

  Offset _geoToScreen(double lat, double lon, Offset center, double scale) {
    final kmPerLat = 110.574;
    final kmPerLon = 111.320 * math.cos(centerLat * math.pi / 180.0);

    final dLatKm = (lat - centerLat) * kmPerLat;
    final dLonKm = (lon - centerLon) * kmPerLon;

    final x = center.dx + (dLonKm * scale);
    final y = center.dy - (dLatKm * scale); // screen Y is inverted

    return Offset(x, y);
  }

  Offset _screenToGeo(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = (math.min(size.width, size.height) * 0.42) / radiusKm;

    final dLonKm = (localPos.dx - center.dx) / scale;
    final dLatKm = -(localPos.dy - center.dy) / scale;

    final kmPerLat = 110.574;
    final kmPerLon = 111.320 * math.cos(centerLat * math.pi / 180.0);

    final lat = centerLat + (dLatKm / kmPerLat);
    final lon = centerLon + (dLonKm / kmPerLon);

    return Offset(lat, lon);
  }
}

class _GeoMapPainter extends CustomPainter {
  final double centerLat;
  final double centerLon;
  final double radiusKm;
  final List<GeoObservationModel> observations;
  final List<HotspotClusterModel> hotspots;
  final SpatialInterpolationModel? activeInterpolation;
  final String? selectedStationId;
  final String selectedPollutant;
  final bool showHotspots;
  final bool showModelGrid;

  _GeoMapPainter({
    required this.centerLat,
    required this.centerLon,
    required this.radiusKm,
    required this.observations,
    required this.hotspots,
    required this.activeInterpolation,
    required this.selectedStationId,
    required this.selectedPollutant,
    required this.showHotspots,
    required this.showModelGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = (math.min(size.width, size.height) * 0.42) / radiusKm;

    // 1. Futuristic Dark Background Grid & Range Rings
    _drawSpatialGrid(canvas, size, center, scale);

    // 2. Hotspot Cluster Halos (if enabled)
    if (showHotspots) {
      _drawHotspots(canvas, center, scale);
    }

    // 3. Active Spatial Interpolation Overlay & Connecting Rays
    if (activeInterpolation != null) {
      _drawInterpolationOverlay(canvas, center, scale);
    }

    // 4. Monitoring Station Markers (Physical & Model Grid)
    _drawStationMarkers(canvas, center, scale);

    // 5. Query Location Origin Marker (Center User Location)
    _drawCenterLocationBlip(canvas, center);
  }

  void _drawSpatialGrid(Canvas canvas, Size size, Offset center, double scale) {
    final ringPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final ringDashPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Concentric Range Rings (10 km, 25 km, 50 km)
    final ringDistances = [10.0, 25.0, 50.0];
    for (final dist in ringDistances) {
      if (dist <= radiusKm * 1.2) {
        final r = dist * scale;
        canvas.drawCircle(center, r, dist == 50.0 ? ringPaint : ringDashPaint);

        // Distance text label
        textPainter.text = TextSpan(
          text: '${dist.toInt()} km',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(center.dx + 4, center.dy - r - 12));
      }
    }

    // Crosshair Axis Lines
    final axisPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), axisPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), axisPaint);

    // Cardinal Orientation Labels
    _drawCardinal(canvas, center, 'N', Offset(center.dx, 16));
    _drawCardinal(canvas, center, 'S', Offset(center.dx, size.height - 24));
    _drawCardinal(canvas, center, 'W', Offset(16, center.dy - 6));
    _drawCardinal(canvas, center, 'E', Offset(size.width - 24, center.dy - 6));
  }

  void _drawCardinal(Canvas canvas, Offset center, String text, Offset pos) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    p.layout();
    p.paint(canvas, pos);
  }

  void _drawHotspots(Canvas canvas, Offset center, double scale) {
    for (final h in hotspots) {
      final pos = _geoToScreen(h.centerLat, h.centerLon, center, scale);
      final r = h.radiusKm * scale;

      // Halo fill
      final haloPaint = Paint()
        ..color = h.severity.color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, r, haloPaint);

      // Boundary outline
      final borderPaint = Paint()
        ..color = h.severity.color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(pos, r, borderPaint);

      // Hotspot center warning icon
      final badgePaint = Paint()..color = h.severity.color;
      canvas.drawCircle(pos, 8, badgePaint);

      final iconPainter = TextPainter(
        text: const TextSpan(
          text: '!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset(pos.dx - iconPainter.width / 2, pos.dy - iconPainter.height / 2),
      );
    }
  }

  void _drawInterpolationOverlay(Canvas canvas, Offset center, double scale) {
    final interp = activeInterpolation!;
    final targetPos = _geoToScreen(interp.targetLat, interp.targetLon, center, scale);

    // Draw connecting rays to contributing stations
    final rayPaint = Paint()
      ..color = AppColors.cyanAccent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw target crosshairs & circle
    final targetPaint = Paint()
      ..color = AppColors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(targetPos, 14, targetPaint);
    canvas.drawCircle(targetPos, 3, Paint()..color = AppColors.cyanAccent);
    canvas.drawLine(
      Offset(targetPos.dx - 20, targetPos.dy),
      Offset(targetPos.dx + 20, targetPos.dy),
      targetPaint,
    );
    canvas.drawLine(
      Offset(targetPos.dx, targetPos.dy - 20),
      Offset(targetPos.dx, targetPos.dy + 20),
      targetPaint,
    );

    // Rays to contributing stations
    for (final contrib in interp.contributingStations) {
      final matchObs = observations.where((o) => o.stationId == contrib.stationId).firstOrNull;
      if (matchObs != null) {
        final sPos = _geoToScreen(matchObs.latitude, matchObs.longitude, center, scale);
        canvas.drawLine(targetPos, sPos, rayPaint);
      }
    }
  }

  void _drawStationMarkers(Canvas canvas, Offset center, double scale) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final obs in observations) {
      if (!showModelGrid && obs.stationType == StationType.atmosphericModelGrid) {
        continue;
      }

      final pos = _geoToScreen(obs.latitude, obs.longitude, center, scale);
      final isSelected = obs.stationId == selectedStationId;
      final val = _getPollutantValue(obs, selectedPollutant);
      final markerColor = obs.aqiColor;

      // Outer Selection Halo
      if (isSelected) {
        final selPaint = Paint()
          ..color = AppColors.cyanAccent.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 22, selPaint);

        final selBorder = Paint()
          ..color = AppColors.cyanAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(pos, 22, selBorder);
      }

      // Marker shape depends on station type
      if (obs.stationType == StationType.physicalMonitor) {
        // Physical Station: Solid circle with border
        final fillPaint = Paint()..color = markerColor;
        canvas.drawCircle(pos, 13, fillPaint);

        final strokePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        canvas.drawCircle(pos, 13, strokePaint);
      } else {
        // Atmospheric Model Grid: Diamond / Rotated Square to distinguish
        final diamondPath = Path()
          ..moveTo(pos.dx, pos.dy - 12)
          ..lineTo(pos.dx + 12, pos.dy)
          ..lineTo(pos.dx, pos.dy + 12)
          ..lineTo(pos.dx - 12, pos.dy)
          ..close();

        final fillPaint = Paint()..color = markerColor;
        canvas.drawPath(diamondPath, fillPaint);

        final dashPaint = Paint()
          ..color = AppColors.cyanAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawPath(diamondPath, dashPaint);
      }

      // Numerical value in center of marker
      final labelText = selectedPollutant == 'AQI'
          ? (obs.aqi?.toString() ?? '--')
          : (val?.toStringAsFixed(0) ?? '--');

      textPainter.text = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(pos.dx - (textPainter.width / 2), pos.dy - (textPainter.height / 2)),
      );

      // Station Name / ID below marker
      final namePainter = TextPainter(
        text: TextSpan(
          text: obs.stationName.split(',').first,
          style: TextStyle(
            color: isSelected ? AppColors.cyanAccent : AppColors.textPrimary,
            fontSize: 9,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      namePainter.layout();
      namePainter.paint(canvas, Offset(pos.dx - (namePainter.width / 2), pos.dy + 15));
    }
  }

  void _drawCenterLocationBlip(Canvas canvas, Offset center) {
    // Current GPS query location
    final pulsePaint = Paint()
      ..color = AppColors.emeraldAccent.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 18, pulsePaint);

    final centerPaint = Paint()..color = AppColors.emeraldAccent;
    canvas.drawCircle(center, 6, centerPaint);

    final whiteBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 6, whiteBorder);
  }

  Offset _geoToScreen(double lat, double lon, Offset center, double scale) {
    final kmPerLat = 110.574;
    final kmPerLon = 111.320 * math.cos(centerLat * math.pi / 180.0);

    final dLatKm = (lat - centerLat) * kmPerLat;
    final dLonKm = (lon - centerLon) * kmPerLon;

    final x = center.dx + (dLonKm * scale);
    final y = center.dy - (dLatKm * scale);

    return Offset(x, y);
  }

  double? _getPollutantValue(GeoObservationModel obs, String pol) {
    switch (pol.toUpperCase()) {
      case 'AQI':
        return obs.aqi?.toDouble();
      case 'PM2.5':
        return obs.pm25;
      case 'PM10':
        return obs.pm10;
      case 'NO2':
        return obs.no2;
      case 'SO2':
        return obs.so2;
      case 'CO':
        return obs.co;
      case 'O3':
        return obs.o3;
      case 'NH3':
        return obs.nh3;
      case 'PB':
        return obs.pb;
      default:
        return obs.pm25;
    }
  }

  @override
  bool shouldRepaint(covariant _GeoMapPainter oldDelegate) {
    return oldDelegate.observations != observations ||
        oldDelegate.hotspots != hotspots ||
        oldDelegate.activeInterpolation != activeInterpolation ||
        oldDelegate.selectedStationId != selectedStationId ||
        oldDelegate.selectedPollutant != selectedPollutant ||
        oldDelegate.showHotspots != showHotspots ||
        oldDelegate.showModelGrid != showModelGrid ||
        oldDelegate.centerLat != centerLat ||
        oldDelegate.centerLon != centerLon;
  }
}
