import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/forecast_model.dart';
import '../controllers/environmental_controller.dart';
import '../widgets/pollutant_grid_card.dart';

class ForecastTabScreen extends ConsumerWidget {
  const ForecastTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(environmentalControllerProvider);
    final controller = ref.read(environmentalControllerProvider.notifier);
    final forecast = state.forecast;
    final aqiResult = state.currentAssessment?.aqiResult;

    if (state.isForecastLoading && forecast == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }

    final steps = forecast?.forecasts ?? const <HorizonForecastStep>[];
    final horizons = steps.map((s) => s.horizonHours).toList()..sort();
    final selected = _selectedStep(steps, state.selectedHorizonHours) ??
        (steps.isNotEmpty ? steps.first : null);
    final predictedValues =
        steps.map((s) => s.predictedAqi).whereType<int>().toList();
    final peakAqi =
        predictedValues.isEmpty ? null : predictedValues.reduce(_max);
    final bestAqi =
        predictedValues.isEmpty ? null : predictedValues.reduce(_min);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (forecast == null) _buildUnavailableCard(state, controller),

          if (forecast != null) ...[
            _buildHeaderCard(forecast, aqiResult?.overallAqi),
            const SizedBox(height: 14),
            if (horizons.isNotEmpty)
              _buildHorizonSelector(
                horizons,
                state.selectedHorizonHours,
                controller.selectForecastHorizon,
              ),
            const SizedBox(height: 14),
            if (selected != null) _buildSelectedStepCard(selected),
            const SizedBox(height: 14),
            if (steps.isNotEmpty)
              _buildForecastChartCard(steps, selected?.horizonHours),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildSummaryCard(
                  label: 'Best window',
                  value: bestAqi?.toString() ?? '--',
                  color: AppColors.getAqiColor(bestAqi),
                  icon: Icons.thumb_up_alt_outlined,
                  caption: bestAqi == null
                      ? 'Not enough forecast data'
                      : 'Lowest projected AQI',
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  label: 'Peak window',
                  value: peakAqi?.toString() ?? '--',
                  color: AppColors.getAqiColor(peakAqi),
                  icon: Icons.trending_up,
                  caption: peakAqi == null
                      ? 'Not enough forecast data'
                      : 'Highest projected AQI',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.forecastBadge.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.forecastBadge.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 15, color: AppColors.forecastBadge),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      forecast.disclaimer.isEmpty
                          ? 'Forecasts are model projections showing statistical uncertainty — not verified measurements.'
                          : forecast.disclaimer,
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (aqiResult != null && aqiResult.subIndices.isNotEmpty) ...[
            const SizedBox(height: 16),
            PollutantGridCard(subIndices: aqiResult.subIndices),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  HorizonForecastStep? _selectedStep(
    List<HorizonForecastStep> steps,
    int horizon,
  ) {
    for (final step in steps) {
      if (step.horizonHours == horizon) return step;
    }
    return null;
  }

  int _max(int a, int b) => a > b ? a : b;
  int _min(int a, int b) => a < b ? a : b;

  Widget _buildUnavailableCard(
    EnvironmentalState state,
    EnvironmentalController controller,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'Forecast unavailable',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.forecastError ??
                'No forecast model output is available for this location yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => controller.refreshCurrent(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry forecast'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(ForecastCurrentResponse forecast, int? currentAqi) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AIR QUALITY FORECAST',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: Color(0xFFDBEAFE),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  forecast.stationName.isEmpty
                      ? 'Current location'
                      : forecast.stationName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Generated ${_timeLabel(forecast.baseTimestamp)} • '
                  '${forecast.dataSourceType.replaceAll('_', ' ')}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFFDBEAFE),
                  ),
                ),
              ],
            ),
          ),
          if (currentAqi != null) ...[
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '$currentAqi',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'NOW',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Color(0xFFDBEAFE),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHorizonSelector(
    List<int> horizons,
    int selectedHorizon,
    ValueChanged<int> onSelected,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: horizons.map((hours) {
          final isSelected = hours == selectedHorizon;
          return Expanded(
            child: InkWell(
              onTap: () => onSelected(hours),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isSelected ? AppColors.cardShadow : null,
                ),
                child: Text(
                  '+${hours}h',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? AppColors.primaryBlue
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectedStepCard(HorizonForecastStep step) {
    final aqi = step.predictedAqi;
    final category = step.predictedAqiCategory ?? 'Forecast';
    final color = AppColors.getAqiColor(aqi);
    final pm25 = step.pollutantPredictions['PM2.5'] ??
        step.pollutantPredictions['pm2_5'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expected in ${step.horizonHours} hour${step.horizonHours == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeLabel(step.targetTimestamp),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                aqi?.toString() ?? '--',
                style: TextStyle(
                  fontSize: 52,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2,
                  color: color,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'AQI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const Spacer(),
              if (pm25 != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'PM2.5 ${pm25.predictedValue.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '90% CI ${pm25.ci90Lower.toStringAsFixed(0)}–'
                        '${pm25.ci90Upper.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (step.temperatureCelsius != null ||
              step.windSpeedKmh != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (step.temperatureCelsius != null)
                  _weatherChip(
                    Icons.thermostat,
                    '${step.temperatureCelsius!.toStringAsFixed(0)}°C',
                  ),
                if (step.relativeHumidityPct != null)
                  _weatherChip(
                    Icons.water_drop_outlined,
                    '${step.relativeHumidityPct!.toStringAsFixed(0)}%',
                  ),
                if (step.windSpeedKmh != null)
                  _weatherChip(
                    Icons.air,
                    '${step.windSpeedKmh!.toStringAsFixed(0)} km/h',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _weatherChip(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastChartCard(
    List<HorizonForecastStep> steps,
    int? selectedHorizon,
  ) {
    final ordered = [...steps]..sort((a, b) => a.horizonHours - b.horizonHours);
    final values =
        ordered.map((s) => s.predictedAqi).whereType<int>().toList();
    final maxValue = values.isEmpty ? 1 : values.reduce(_max);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Projected AQI by horizon',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.forecastBadge.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'MODEL OUTPUT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppColors.forecastBadge,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: ordered.map((step) {
                final aqi = step.predictedAqi;
                final color = AppColors.getAqiColor(aqi);
                final heightRatio = aqi == null
                    ? 0.08
                    : (aqi / (maxValue * 1.15)).clamp(0.08, 1.0);
                final isSelected = step.horizonHours == selectedHorizon;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          aqi?.toString() ?? '--',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: double.infinity,
                          height: 92 * heightRatio,
                          decoration: BoxDecoration(
                            color: color.withValues(
                                alpha: isSelected ? 1.0 : 0.55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '+${step.horizonHours}h',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primaryBlue
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required String caption,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'AQI',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime timestamp) {
    final local = timestamp.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month} $hour:${local.minute.toString().padLeft(2, '0')} $period';
  }
}
