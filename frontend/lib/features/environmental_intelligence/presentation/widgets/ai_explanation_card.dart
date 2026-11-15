import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/ai_explanation_model.dart';

class AIExplanationCard extends StatefulWidget {
  final AIExplanationResponse? explanation;
  final bool isLoading;
  final VoidCallback? onRefresh;

  const AIExplanationCard({
    super.key,
    required this.explanation,
    required this.isLoading,
    this.onRefresh,
  });

  @override
  State<AIExplanationCard> createState() => _AIExplanationCardState();
}

class _AIExplanationCardState extends State<AIExplanationCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.explanation == null) {
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
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyanAccent),
              ),
              SizedBox(height: 12),
              Text(
                'Synthesizing grounded environmental explanation...',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.explanation == null) {
      return const SizedBox.shrink();
    }

    final exp = widget.explanation!;
    final isGemini = exp.providerUsed.toLowerCase().contains('gemini');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.cyanAccent, AppColors.purpleAccent],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.background,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI ATMOSPHERIC EXPLAINER',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          isGemini ? 'POWERED BY GEMINI 1.5' : 'DETERMINISTIC EXPERT SYSTEM',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: isGemini ? AppColors.cyanAccent : AppColors.emeraldAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (widget.onRefresh != null)
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18, color: AppColors.textMuted),
                        onPressed: widget.onRefresh,
                        tooltip: 'Regenerate Explanation',
                        visualDensity: VisualDensity.compact,
                      ),
                    IconButton(
                      icon: Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_isExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSection(
                    icon: Icons.public,
                    title: 'Atmospheric Dynamics',
                    body: exp.atmosphericDynamics,
                    iconColor: AppColors.cyanAccent,
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    icon: Icons.bubble_chart,
                    title: 'Primary Driver & Sub-Index Impact',
                    body: exp.primaryDriverAnalysis,
                    iconColor: AppColors.emeraldAccent,
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    icon: Icons.factory_outlined,
                    title: 'Dispersion & Meteorological Influences',
                    body: exp.elevationCauses,
                    iconColor: AppColors.purpleAccent,
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    icon: Icons.directions_run,
                    title: 'Outdoor Activity Guidance',
                    body: exp.activityImplications,
                    iconColor: AppColors.aqiPoor,
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Practical Precautions',
                    body: exp.practicalPrecautions,
                    iconColor: AppColors.aqiSatisfactory,
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    icon: Icons.history_toggle_off,
                    title: 'Historical Baseline Comparison',
                    body: exp.historicalComparison,
                    iconColor: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 14),

                  // Strict Non-Medical Disclaimer
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            exp.disclaimer,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String body,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
