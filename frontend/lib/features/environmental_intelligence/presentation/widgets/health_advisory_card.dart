import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/aqi_result_model.dart';

class HealthAdvisoryCard extends StatelessWidget {
  final HealthAdvisory advisory;

  const HealthAdvisoryCard({
    super.key,
    required this.advisory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.health_and_safety_outlined, size: 20, color: AppColors.cyanAccent),
              SizedBox(width: 8),
              Text(
                'CPCB HEALTH ADVISORY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            advisory.generalStatement,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            icon: Icons.personal_injury_outlined,
            title: 'Sensitive Populations',
            content: advisory.sensitiveGroupAdvice,
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            icon: Icons.directions_run_outlined,
            title: 'Outdoor Physical Exertion',
            content: advisory.outdoorActivityAdvice,
          ),
          if (advisory.recommendedMask != null) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              icon: Icons.masks_outlined,
              title: 'Respiratory Protection',
              content: advisory.recommendedMask!,
            ),
          ],
          if (advisory.airPurifierAdvice != null) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              icon: Icons.air,
              title: 'Indoor Air Strategy',
              content: advisory.airPurifierAdvice!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
