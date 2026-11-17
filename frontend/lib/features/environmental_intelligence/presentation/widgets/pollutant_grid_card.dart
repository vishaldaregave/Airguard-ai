import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/aqi_result_model.dart';

class PollutantGridCard extends StatelessWidget {
  final Map<String, SubIndexResult> subIndices;

  const PollutantGridCard({
    super.key,
    required this.subIndices,
  });

  static const Map<String, String> _pollutantNames = {
    'PM2.5': 'Fine Particulate Matter',
    'PM10': 'Coarse Particulate Matter',
    'NO2': 'Nitrogen Dioxide',
    'SO2': 'Sulfur Dioxide',
    'CO': 'Carbon Monoxide',
    'O3': 'Ozone',
    'NH3': 'Ammonia',
    'PB': 'Lead',
  };

  @override
  Widget build(BuildContext context) {
    if (subIndices.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = subIndices.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pollutant Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'CPCB 24h Standards',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            final color = AppColors.getAqiColor(item.subIndex);
            final fullName = _pollutantNames[item.pollutant.toUpperCase()] ?? 'Atmospheric Pollutant';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border, width: 1),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.grain, size: 18, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.pollutant,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.concentration.toStringAsFixed(1)} ${item.unit}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Sub-Index: ${item.subIndex}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (item.subIndex / 500.0).clamp(0.0, 1.0),
                      backgroundColor: AppColors.borderLight,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
