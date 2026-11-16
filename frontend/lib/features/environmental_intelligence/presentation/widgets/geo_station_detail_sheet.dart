import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/geo_models.dart';

class GeoStationDetailSheet extends StatelessWidget {
  final GeoObservationModel observation;
  final VoidCallback onClose;

  const GeoStationDetailSheet({
    super.key,
    required this.observation,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header: Station Name, Type, and Close Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      observation.stationName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          observation.stationType.icon,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${observation.stationType.displayName} • ${observation.provider}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (observation.distanceKm != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '• ${observation.distanceKm!.toStringAsFixed(1)} km away',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.cyanAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Provenance & Staleness Badges
          Row(
            children: [
              _buildProvenanceBadge(observation.dataSourceType),
              const SizedBox(width: 8),
              if (observation.isStale)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.aqiPoor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.aqiPoor.withValues(alpha: 0.6)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 11, color: AppColors.aqiPoor),
                      SizedBox(width: 4),
                      Text(
                        'STALE TELEMETRY',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.aqiPoor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.emeraldAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 11, color: AppColors.emeraldAccent),
                      const SizedBox(width: 4),
                      Text(
                        observation.dataFreshnessMinutes != null
                            ? '${observation.dataFreshnessMinutes!.toStringAsFixed(0)}m ago'
                            : 'FRESH',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.emeraldAccent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Primary AQI Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: observation.aqiColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: observation.aqiColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: observation.aqiColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    observation.aqi != null ? '${observation.aqi}' : '--',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: observation.aqiColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        observation.cpcbCategory ?? 'Insufficient Pollutants',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: observation.aqiColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        observation.dominantPollutant != null
                            ? 'Primary Pollutant: ${observation.dominantPollutant}'
                            : 'Requires >= 3 criteria pollutants for CPCB AQI',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Criteria Pollutant Grid
          const Text(
            'MONITORED POLLUTANTS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPollutantItem('PM2.5', observation.pm25, 'µg/m³', 24),
              _buildPollutantItem('PM10', observation.pm10, 'µg/m³', 24),
              _buildPollutantItem('NO2', observation.no2, 'µg/m³', 24),
              _buildPollutantItem('SO2', observation.so2, 'µg/m³', 24),
              _buildPollutantItem('CO', observation.co, 'mg/m³', 8),
              _buildPollutantItem('O3', observation.o3, 'µg/m³', 8),
              _buildPollutantItem('NH3', observation.nh3, 'µg/m³', 24),
              _buildPollutantItem('Pb', observation.pb, 'µg/m³', 24),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildProvenanceBadge(String type) {
    final color = AppColors.getProvenanceColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == 'LIVE' ? Icons.sensors : Icons.cloud_outlined,
            color: color,
            size: 11,
          ),
          const SizedBox(width: 4),
          Text(
            type.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollutantItem(String name, double? val, String unit, int avgHours) {
    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '${avgHours}h',
                style: const TextStyle(
                  fontSize: 8,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            val != null ? val.toStringAsFixed(1) : '--',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 7.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
