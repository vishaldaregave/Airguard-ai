import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/aqi_result_model.dart';

class FuturisticAqiGauge extends StatelessWidget {
  final AQICalculationResult aqiResult;

  const FuturisticAqiGauge({
    super.key,
    required this.aqiResult,
  });

  @override
  Widget build(BuildContext context) {
    final aqi = aqiResult.overallAqi ?? 0;
    final categoryColor = AppColors.getAqiColor(aqiResult.overallAqi);
    final categoryText = aqiResult.category ?? 'Unknown';
    final prominentPollutant = aqiResult.prominentPollutant ?? 'None';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // Radial Speedometer Arc
          SizedBox(
            height: 195,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SpeedometerArcPainter(
                      aqi: aqi,
                      categoryColor: categoryColor,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'CPCB AQI',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            aqiResult.overallAqi != null ? '$aqi' : '--',
                            style: const TextStyle(
                              fontSize: 58,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              letterSpacing: -1.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'AQI',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: categoryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: categoryColor.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          categoryText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: categoryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Endpoints 0 and 500
                Positioned(
                  left: 20,
                  bottom: 4,
                  child: const Text(
                    '0',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 4,
                  child: const Text(
                    '500',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Prominent Pollutant info pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfacePill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, size: 16, color: categoryColor),
                const SizedBox(width: 6),
                const Text(
                  'Prominent Pollutant: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  prominentPollutant,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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

class _SpeedometerArcPainter extends CustomPainter {
  final int aqi;
  final Color categoryColor;

  _SpeedometerArcPainter({
    required this.aqi,
    required this.categoryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 18);
    final radius = math.min(size.width / 2 - 28, size.height - 28);

    // Arch goes from 180° to 360° (0°)
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    // 1. Draw outer radial tick dashes (Dribbble style)
    final tickCount = 31;
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final progressFraction = (aqi / 500.0).clamp(0.0, 1.0);
    final activeTicks = (progressFraction * (tickCount - 1)).round();

    for (int i = 0; i < tickCount; i++) {
      final tickAngle = startAngle + (sweepAngle * (i / (tickCount - 1)));
      final cosA = math.cos(tickAngle);
      final sinA = math.sin(tickAngle);

      final rOuter = radius + 12;
      final rInner = radius + (i % 5 == 0 ? 3 : 6);

      final p1 = Offset(center.dx + rInner * cosA, center.dy + rInner * sinA);
      final p2 = Offset(center.dx + rOuter * cosA, center.dy + rOuter * sinA);

      if (i <= activeTicks) {
        tickPaint.color = categoryColor.withValues(alpha: 0.85);
      } else {
        tickPaint.color = AppColors.border;
      }

      canvas.drawLine(p1, p2, tickPaint);
    }

    // 2. Background Track Arc
    final trackPaint = Paint()
      ..color = AppColors.borderLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    // 3. Active Progress Arc
    final activeSweep = sweepAngle * progressFraction;
    if (activeSweep > 0.01) {
      final progressPaint = Paint()
        ..color = categoryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, activeSweep, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedometerArcPainter oldDelegate) {
    return oldDelegate.aqi != aqi || oldDelegate.categoryColor != categoryColor;
  }
}
