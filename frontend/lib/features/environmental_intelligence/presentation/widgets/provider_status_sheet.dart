import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/station_model.dart';

class ProviderStatusSheet extends StatelessWidget {
  final List<ProviderStatusItem> providers;

  const ProviderStatusSheet({super.key, required this.providers});

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ONLINE':
      case 'CONFIGURED':
        return AppColors.liveBadge;
      case 'DEGRADED':
        return AppColors.aqiModerate;
      case 'UNAUTHENTICATED':
        return AppColors.fixtureBadge;
      case 'OFFLINE':
      default:
        return AppColors.staleBadge;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
              const Row(
                children: [
                  Icon(Icons.hub_outlined, size: 20, color: AppColors.cyanAccent),
                  SizedBox(width: 8),
                  Text(
                    'Environmental Data Sources',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Live telemetry and authentication state for external environmental providers.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          if (providers.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('Loading provider telemetry...', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            ...providers.map((p) {
              final statusColor = _getStatusColor(p.status);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          p.displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 0.8),
                          ),
                          child: Text(
                            p.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.details ?? 'Operational',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Type: ${p.primaryDataType}',
                          style: const TextStyle(fontSize: 10, color: AppColors.cyanAccent),
                        ),
                        if (p.latencyMs != null && p.latencyMs! > 0)
                          Text(
                            '${p.latencyMs!.toStringAsFixed(0)} ms',
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
