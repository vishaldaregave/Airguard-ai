import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/forecast_model.dart';
import '../../domain/models/aqi_result_model.dart';

class ForecastChartCard extends StatelessWidget {
  final ForecastCurrentResponse? forecast;
  final AQICalculationResult? currentAqi;
  final int selectedHorizon;
  final bool isLoading;
  final ValueChanged<int> onHorizonSelected;

  const ForecastChartCard({
    super.key,
    required this.forecast,
    required this.currentAqi,
    required this.selectedHorizon,
    required this.isLoading,
    required this.onHorizonSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && forecast == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.purpleAccent),
              ),
              SizedBox(height: 12),
              Text(
                'Computing multi-horizon predictions...',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (forecast == null || forecast!.forecasts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.textMuted, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Forecast intelligence accumulating for this location.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final isInsufficient = forecast!.status == 'INSUFFICIENT_TRAINING_DATA';
    final selectedStep = forecast!.forecasts.firstWhere(
      (s) => s.horizonHours == selectedHorizon,
      orElse: () => forecast!.forecasts.first,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInsufficient ? AppColors.aqiPoor.withValues(alpha: 0.4) : AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.purpleAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.insights,
                      color: AppColors.purpleAccent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AIR QUALITY FORECAST',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'STATISTICAL TIME-SERIES ENGINE',
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.forecastBadge.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.forecastBadge.withValues(alpha: 0.6)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timeline, size: 12, color: AppColors.forecastBadge),
                    SizedBox(width: 4),
                    Text(
                      'FORECAST',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.forecastBadge,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isInsufficient) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.aqiPoor.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.aqiPoor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'INSUFFICIENT TRAINING DATA: Historical records are actively accumulating. Persistence baseline is displayed.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Horizon Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [1, 3, 6, 12, 24].map((h) {
                final isSelected = h == selectedHorizon;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      '+${h}h',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.purpleAccent.withValues(alpha: 0.25),
                    backgroundColor: AppColors.surfaceElevated,
                    side: BorderSide(
                      color: isSelected ? AppColors.purpleAccent : AppColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    onSelected: (_) => onHorizonSelected(h),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Forecast Line Chart
          SizedBox(
            height: 160,
            child: _buildForecastChart(forecast!, currentAqi),
          ),

          const SizedBox(height: 16),

          // Selected Horizon Card Breakdown
          _buildSelectedHorizonDetails(selectedStep),

          const SizedBox(height: 12),

          // Model Metadata & Attribution Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Model: ${forecast!.modelMetadata.modelType} (N=${forecast!.modelMetadata.trainingSampleCount})',
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (forecast!.modelMetadata.maePm25 != null)
                  Text(
                    'PM2.5 MAE: ${forecast!.modelMetadata.maePm25!.toStringAsFixed(1)} µg/m³',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.cyanAccent),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastChart(ForecastCurrentResponse forecastData, AQICalculationResult? current) {
    // Generate data points: index 0 is Current observed (if available), followed by horizons
    final spots = <FlSpot>[];
    final upperSpots = <FlSpot>[];
    final lowerSpots = <FlSpot>[];

    // Current observation as origin (x = 0)
    final currentAqiVal = current?.overallAqi?.toDouble() ?? 
        (forecastData.forecasts.isNotEmpty ? (forecastData.forecasts.first.predictedAqi?.toDouble() ?? 100.0) : 100.0);

    spots.add(FlSpot(0, currentAqiVal));
    upperSpots.add(FlSpot(0, currentAqiVal));
    lowerSpots.add(FlSpot(0, currentAqiVal));

    final sorted = List<HorizonForecastStep>.from(forecastData.forecasts)
      ..sort((a, b) => a.horizonHours.compareTo(b.horizonHours));

    for (final step in sorted) {
      final aqi = step.predictedAqi?.toDouble() ?? currentAqiVal;
      final x = step.horizonHours.toDouble();
      spots.add(FlSpot(x, aqi));

      // PM2.5 prediction intervals converted to approximate AQI bounds for visual uncertainty ribbon
      final pm25Pred = step.pollutantPredictions['PM2.5'];
      final diff = pm25Pred != null ? (pm25Pred.ci95Upper - pm25Pred.predictedValue) * 1.2 : (step.horizonHours * 1.5);
      upperSpots.add(FlSpot(x, (aqi + diff).clamp(0, 500)));
      lowerSpots.add(FlSpot(x, (aqi - diff).clamp(0, 500)));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 50,
          getDrawingHorizontalLine: (value) => const FlLine(
            color: AppColors.border,
            strokeWidth: 0.8,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 6,
              getTitlesWidget: (value, meta) {
                if (value == 0) {
                  return const Text('Now', style: TextStyle(color: AppColors.textMuted, fontSize: 10));
                }
                return Text('+${value.toInt()}h', style: const TextStyle(color: AppColors.textMuted, fontSize: 10));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 100,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 24,
        minY: 0,
        maxY: 450,
        lineBarsData: [
          // 95% Upper prediction interval
          LineChartBarData(
            spots: upperSpots,
            isCurved: true,
            color: AppColors.purpleAccent.withValues(alpha: 0.3),
            barWidth: 1.0,
            dashArray: [3, 3],
            dotData: const FlDotData(show: false),
          ),
          // 95% Lower prediction interval
          LineChartBarData(
            spots: lowerSpots,
            isCurved: true,
            color: AppColors.purpleAccent.withValues(alpha: 0.3),
            barWidth: 1.0,
            dashArray: [3, 3],
            dotData: const FlDotData(show: false),
          ),
          // Main Predicted AQI curve
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.purpleAccent,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isNow = spot.x == 0;
                return FlDotCirclePainter(
                  radius: isNow ? 4.0 : 3.0,
                  color: isNow ? AppColors.emeraldAccent : AppColors.cyanAccent,
                  strokeWidth: 2,
                  strokeColor: AppColors.surfaceCard,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.purpleAccent.withValues(alpha: 0.25),
                  AppColors.purpleAccent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedHorizonDetails(HorizonForecastStep step) {
    final aqi = step.predictedAqi;
    final aqiCategory = step.predictedAqiCategory ?? 'Forecast AQI';
    final aqiColor = AppColors.getAqiColor(aqi);

    final pm25 = step.pollutantPredictions['PM2.5'];
    final pm10 = step.pollutantPredictions['PM10'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '+${step.horizonHours}H CPCB AQI PROJECTION',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        aqi != null ? aqi.toString() : '--',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: aqiColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: aqiColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          aqiCategory,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: aqiColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (step.predictedAqiProminentPollutant != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Dominant', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    Text(
                      step.predictedAqiProminentPollutant!,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.cyanAccent),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          // PM2.5 and PM10 breakdown with 95% Confidence Intervals
          Row(
            children: [
              Expanded(
                child: _buildPollutantCard(
                  name: 'PM2.5',
                  pred: pm25,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPollutantCard(
                  name: 'PM10',
                  pred: pm10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPollutantCard({
    required String name,
    required PollutantPrediction? pred,
  }) {
    if (pred == null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text('$name: Unavailable', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
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
              Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(
                '${pred.predictedValue.toStringAsFixed(1)} ${pred.unit}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.emeraldAccent),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '95% CI: [${pred.ci95Lower.toStringAsFixed(0)} - ${pred.ci95Upper.toStringAsFixed(0)}]',
            style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
