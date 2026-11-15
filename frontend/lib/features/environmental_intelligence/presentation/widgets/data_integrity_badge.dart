import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/aqi_result_model.dart';
import '../../domain/models/station_model.dart';

class DataIntegrityBadge extends StatelessWidget {
  final AQICalculationResult aqiResult;
  final MonitoringStationSummary? station;
  final double? distanceFromUserKm;
  final double? freshnessMinutes;

  const DataIntegrityBadge({
    super.key,
    required this.aqiResult,
    this.station,
    this.distanceFromUserKm,
    this.freshnessMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final type = aqiResult.dataSourceType.toUpperCase();
    final badgeColor = AppColors.getProvenanceColor(type);
    final formattedTime = DateFormat('dd MMM yyyy, hh:mm a')
        .format(aqiResult.observationTimestamp.toLocal());

    IconData badgeIcon;
    String provenanceLabel;
    switch (type) {
      case 'LIVE':
        badgeIcon = Icons.sensors;
        provenanceLabel = 'LIVE MONITORING STATION';
        break;
      case 'ESTIMATED':
        badgeIcon = Icons.cloud_outlined;
        provenanceLabel = 'ATMOSPHERIC MODEL ESTIMATE';
        break;
      case 'FORECAST':
        badgeIcon = Icons.auto_graph;
        provenanceLabel = 'REGIONAL FORECAST';
        break;
      case 'HISTORICAL':
        badgeIcon = Icons.history;
        provenanceLabel = 'HISTORICAL ARCHIVE';
        break;
      case 'DEMO_FIXTURE':
      default:
        badgeIcon = Icons.science_outlined;
        provenanceLabel = 'DEMO FIXTURE (SYNTHETIC)';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: badgeColor,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 13, color: badgeColor),
                    const SizedBox(width: 5),
                    Text(
                      provenanceLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (aqiResult.isStale)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.staleBadge.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.staleBadge, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.staleBadge),
                      const SizedBox(width: 4),
                      Text(
                        freshnessMinutes != null
                            ? 'STALE (${freshnessMinutes!.toStringAsFixed(0)}m)'
                            : 'STALE DATA',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.staleBadge,
                        ),
                      ),
                    ],
                  ),
                )
              else if (freshnessMinutes != null)
                Text(
                  '${freshnessMinutes!.toStringAsFixed(0)}m ago',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Source: ${aqiResult.provider}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Observed: $formattedTime',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (distanceFromUserKm != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me, size: 13, color: AppColors.cyanAccent),
                      const SizedBox(width: 4),
                      Text(
                        '${distanceFromUserKm!.toStringAsFixed(1)} km away',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Readings represent monitoring station ambient air, not direct personal exposure.',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
