import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/station_model.dart';

class StationSelectorSheet extends StatelessWidget {
  final List<MonitoringStationSummary> stations;
  final MonitoringStationSummary? current;
  final ValueChanged<MonitoringStationSummary> onSelected;
  final VoidCallback onLocateMe;

  const StationSelectorSheet({
    super.key,
    required this.stations,
    required this.current,
    required this.onSelected,
    required this.onLocateMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Monitoring Station',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Live ground stations, model grids, and demo fixtures are explicitly identified.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),

          // GPS Button
          InkWell(
            onTap: () {
              Navigator.pop(context);
              onLocateMe();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.emeraldAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.emeraldAccent.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.my_location, size: 18, color: AppColors.emeraldAccent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detect Current GPS Location',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emeraldAccent,
                          ),
                        ),
                        Text(
                          'Discover stations nearest to your actual coordinates',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: AppColors.emeraldAccent),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Station List
          Flexible(
            child: stations.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No monitoring stations discovered in this area.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: stations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final station = stations[index];
                      final isSelected = current?.stationId == station.stationId;
                      final provColor = AppColors.getProvenanceColor(station.dataSourceType);

                      return InkWell(
                        onTap: () {
                          onSelected(station);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.surfaceElevated : AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppColors.emeraldAccent : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: isSelected ? AppColors.emeraldAccent : AppColors.textMuted,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            station.stationName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: provColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: provColor.withValues(alpha: 0.4), width: 0.8),
                                          ),
                                          child: Text(
                                            station.dataSourceType,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: provColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${station.location.city ?? 'Station'} • ${station.provider}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (station.distanceKm != null) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '(${station.distanceKm!.toStringAsFixed(1)} km)',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.cyanAccent,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (station.availablePollutants.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: station.availablePollutants.map((pollutant) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceElevated,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              pollutant,
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
