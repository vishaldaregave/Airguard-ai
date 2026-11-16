import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/alert_model.dart';

class AlertDetailSheet extends StatelessWidget {
  final AlertItem alert;
  final VoidCallback? onMarkRead;

  const AlertDetailSheet({
    super.key,
    required this.alert,
    this.onMarkRead,
  });

  static Future<void> show(BuildContext context, AlertItem alert, {VoidCallback? onMarkRead}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AlertDetailSheet(alert: alert, onMarkRead: onMarkRead),
    );
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = alert.severity.color;

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.borderHighlight, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderHighlight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header with Severity & Provenance Badges
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: severityColor, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(alert.severity.icon, size: 14, color: severityColor),
                    const SizedBox(width: 5),
                    Text(
                      alert.severity.displayName,
                      style: TextStyle(
                        color: severityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Forecast vs Observed Provenance Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: alert.isForecast
                      ? AppColors.forecastBadge.withValues(alpha: 0.15)
                      : AppColors.liveBadge.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: alert.isForecast ? AppColors.forecastBadge : AppColors.liveBadge,
                    width: 1.0,
                  ),
                ),
                child: Text(
                  alert.isForecast
                      ? 'FORECAST (+${alert.forecastHorizonHours ?? 1}h)'
                      : 'OBSERVED (${alert.sourceProvenance})',
                  style: TextStyle(
                    color: alert.isForecast ? AppColors.forecastBadge : AppColors.liveBadge,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),

              Text(
                _formatTimestamp(alert.observationTimestamp),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Station Name & Alert Type
          Text(
            alert.alertType.displayName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.cyanAccent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  alert.stationName,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Metric Comparison Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCol(
                  label: 'OBSERVED',
                  value: alert.observedValue != null
                      ? '${alert.observedValue!.toStringAsFixed(alert.unit == 'AQI' ? 0 : 1)} ${alert.unit}'
                      : 'N/A',
                  color: severityColor,
                ),
                Container(width: 1, height: 36, color: AppColors.border),
                _buildMetricCol(
                  label: 'TRIGGER THRESHOLD',
                  value: alert.thresholdValue != null
                      ? '${alert.thresholdValue!.toStringAsFixed(alert.unit == 'AQI' ? 0 : 1)} ${alert.unit}'
                      : 'N/A',
                  color: AppColors.textSecondary,
                ),
                Container(width: 1, height: 36, color: AppColors.border),
                _buildMetricCol(
                  label: 'STATUS',
                  value: alert.isResolved ? 'RESOLVED' : (alert.isRead ? 'READ' : 'ACTIVE'),
                  color: alert.isResolved
                      ? AppColors.emeraldAccent
                      : (alert.isRead ? AppColors.textMuted : AppColors.cyanAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Trigger Reason
          const Text(
            'TRIGGER REASON',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            alert.triggerReason,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),

          // Precautionary Guidance Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderHighlight.withValues(alpha: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.health_and_safety_outlined, size: 20, color: AppColors.emeraldAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EVIDENCE-BASED PRECAUTION',
                        style: TextStyle(
                          color: AppColors.emeraldAccent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.recommendedPrecaution,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                onMarkRead?.call();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceElevated,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
              child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol({required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}
