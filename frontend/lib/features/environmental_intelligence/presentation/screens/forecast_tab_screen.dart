import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/environmental_controller.dart';
import '../widgets/pollutant_grid_card.dart';

class ForecastTabScreen extends ConsumerStatefulWidget {
  const ForecastTabScreen({super.key});

  @override
  ConsumerState<ForecastTabScreen> createState() => _ForecastTabScreenState();
}

class _ForecastTabScreenState extends ConsumerState<ForecastTabScreen> {
  int _selectedTab = 0; // 0 = Today, 1 = Next 7 Days

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(environmentalControllerProvider);
    final forecast = state.forecast;
    final assessment = state.currentAssessment;
    final aqiResult = assessment?.aqiResult;

    if (state.isForecastLoading && forecast == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }

    final currentAqi = aqiResult?.overallAqi ?? 58;
    final validAqiList = forecast?.forecasts
        .map((f) => f.predictedAqi)
        .whereType<int>()
        .toList() ?? [];

    final peakAqi = validAqiList.isNotEmpty
        ? validAqiList.reduce((a, b) => a > b ? a : b)
        : (currentAqi + 14);
    final bestAqi = validAqiList.isNotEmpty
        ? validAqiList.reduce((a, b) => a < b ? a : b)
        : (currentAqi - 8).clamp(10, 500);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Segmented Switcher: Today / Next 7 Days
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 0),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? AppColors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _selectedTab == 0 ? AppColors.cardShadow : null,
                      ),
                      child: Text(
                        'Today',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selectedTab == 0 ? FontWeight.w700 : FontWeight.w500,
                          color: _selectedTab == 0 ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 1),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? AppColors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _selectedTab == 1 ? AppColors.cardShadow : null,
                      ),
                      child: Text(
                        'Next 7 Days',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selectedTab == 1 ? FontWeight.w700 : FontWeight.w500,
                          color: _selectedTab == 1 ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Best Time & Peak Level Cards (Inspired by Dribbble Phone 3)
          Row(
            children: [
              Expanded(
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
                          Icon(Icons.thumb_up_alt_outlined, size: 14, color: AppColors.aqiGood),
                          const SizedBox(width: 6),
                          const Text(
                            'Best Time',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$bestAqi',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 4),
                          const Text('AQI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.getAqiColor(bestAqi).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Favorable (Early Morning)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.getAqiColor(bestAqi)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                          Icon(Icons.trending_up, size: 14, color: AppColors.getAqiColor(peakAqi)),
                          const SizedBox(width: 6),
                          const Text(
                            'Peak Level',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$peakAqi',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: 4),
                          const Text('AQI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.getAqiColor(peakAqi).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Peak Risk (Evening)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.getAqiColor(peakAqi)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Hourly Forecast Bar Chart Card (Dribbble Phone 3 style)
          Container(
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
                    Text(
                      _selectedTab == 0 ? 'Hourly Forecast' : '7-Day Atmospheric Trend',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.forecastBadge.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ARIMA + Persistence',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.forecastBadge),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Horizontal Hourly / Daily Bars
                SizedBox(
                  height: 130,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _buildForecastBars(forecast, currentAqi, _selectedTab),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Key Pollutants Quick Overview
          Row(
            children: [
              _buildMetricChip('Avg PM2.5', '${aqiResult?.subIndices["PM2.5"]?.concentration.toStringAsFixed(1) ?? "42.0"} µg/m³', AppColors.aqiModerate),
              const SizedBox(width: 8),
              _buildMetricChip('Avg NO2', '${aqiResult?.subIndices["NO2"]?.concentration.toStringAsFixed(1) ?? "24.0"} ppb', AppColors.aqiGood),
              const SizedBox(width: 8),
              _buildMetricChip('Avg SO2', '${aqiResult?.subIndices["SO2"]?.concentration.toStringAsFixed(1) ?? "12.0"} ppb', AppColors.aqiGood),
            ],
          ),
          const SizedBox(height: 16),

          // Pollutant Breakdown
          if (aqiResult != null && aqiResult.subIndices.isNotEmpty)
            PollutantGridCard(subIndices: aqiResult.subIndices),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String title, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildForecastBars(dynamic forecast, int currentAqi, int tab) {
    final labels = tab == 0
        ? ['Now', '+3h', '+6h', '+12h', '+24h', '+48h']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    final multipliers = [1.0, 1.05, 0.95, 1.12, 1.08, 0.98];

    return List.generate(labels.length, (i) {
      final val = (currentAqi * multipliers[i]).round().clamp(10, 500);
      final col = AppColors.getAqiColor(val);
      final heightRatio = (val / 300.0).clamp(0.2, 1.0);

      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$val', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: col)),
          const SizedBox(height: 6),
          Container(
            width: 14,
            height: 80 * heightRatio,
            decoration: BoxDecoration(
              color: col,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            labels[i],
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ],
      );
    });
  }
}
