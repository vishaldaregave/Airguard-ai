import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/exposure_models.dart';
import '../controllers/exposure_controller.dart';

class ExposureSimulatorScreen extends ConsumerWidget {
  const ExposureSimulatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exposureControllerProvider);
    final controller = ref.read(exposureControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'EXPOSURE SIMULATOR',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'PERSONAL ENVIRONMENTAL EXPOSURE INTELLIGENCE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.cyanAccent.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => controller.toggleComparisonMode(!state.isComparisonMode),
            icon: Icon(
              state.isComparisonMode ? Icons.compare_arrows : Icons.compare_arrows_outlined,
              color: state.isComparisonMode ? AppColors.cyanAccent : AppColors.textSecondary,
            ),
            tooltip: state.isComparisonMode ? 'Exit Comparison Mode' : 'Compare Two Scenarios',
          ),
          IconButton(
            onPressed: () => controller.runSimulation(),
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            tooltip: 'Recalculate Exposure',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: state.isLoading && state.currentSimulation == null
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyanAccent),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Calculating Physical Exposure Model...',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Location & Environmental Data Provenance Banner
                    _buildLocationProvenanceBanner(context, state),
                    const SizedBox(height: 14),

                    // 2. Scenario A Configuration Card (Activity & Duration)
                    _buildScenarioInputCard(
                      context,
                      title: state.isComparisonMode ? 'SCENARIO A (BASELINE)' : 'EXPOSURE PARAMETERS',
                      selectedActivity: state.selectedActivity,
                      durationMinutes: state.durationMinutes,
                      activityProfiles: state.activityProfiles,
                      onSelectActivity: (p) => controller.selectActivity(p),
                      onDurationChanged: (m) => controller.setDuration(m),
                      isForecast: state.isForecastMode,
                      onToggleForecast: (v) => controller.toggleForecastMode(v),
                    ),
                    const SizedBox(height: 14),

                    // 3. Scenario B Configuration Card (if comparison mode enabled)
                    if (state.isComparisonMode) ...[
                      _buildScenarioInputCard(
                        context,
                        title: 'SCENARIO B (ALTERNATIVE WHAT-IF)',
                        selectedActivity: state.scenarioBActivity ?? state.selectedActivity,
                        durationMinutes: state.scenarioBDurationMinutes,
                        activityProfiles: state.activityProfiles,
                        onSelectActivity: (p) => controller.selectScenarioBActivity(p),
                        onDurationChanged: (m) => controller.setScenarioBDuration(m),
                        isForecast: state.isForecastMode,
                        accentColor: AppColors.emeraldAccent,
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 4. Action Button
                    ElevatedButton.icon(
                      onPressed: state.isLoading
                          ? null
                          : () {
                              if (state.isComparisonMode) {
                                controller.runComparison();
                              } else {
                                controller.runSimulation();
                              }
                            },
                      icon: Icon(
                        state.isComparisonMode ? Icons.compare_arrows : Icons.play_arrow,
                        color: Colors.black,
                      ),
                      label: Text(
                        state.isComparisonMode
                            ? 'RUN SCENARIO COMPARISON'
                            : 'CALCULATE PHYSICAL EXPOSURE',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Colors.black,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyanAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 5. Results Section (Single Simulation or Comparison)
                    if (state.isComparisonMode && state.currentComparison != null)
                      _buildComparisonResults(context, state.currentComparison!)
                    else if (state.currentSimulation != null)
                      _buildSimulationResults(context, state.currentSimulation!),

                    const SizedBox(height: 16),

                    // 6. AI Explanation & Actionable Guidance
                    if (state.explanation != null)
                      _buildExplanationCard(context, state.explanation!),

                    const SizedBox(height: 16),

                    // 7. Transparent Methodology & Non-Medical Disclaimer
                    _buildMethodologyDisclaimerCard(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLocationProvenanceBanner(BuildContext context, ExposureState state) {
    final sim = state.currentSimulation;
    final prov = sim?.dataSourceType ?? 'LIVE';
    final isForecast = sim?.isForecast ?? state.isForecastMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 18, color: AppColors.emeraldAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.locationName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isForecast ? 'Mode: Forecast Window' : 'Mode: Ambient Observation',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isForecast
                  ? AppColors.cyanAccent.withValues(alpha: 0.15)
                  : AppColors.emeraldAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isForecast ? AppColors.cyanAccent : AppColors.emeraldAccent,
                width: 0.8,
              ),
            ),
            child: Text(
              isForecast ? 'FORECAST' : prov,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: isForecast ? AppColors.cyanAccent : AppColors.emeraldAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioInputCard(
    BuildContext context, {
    required String title,
    required ActivityProfileModel? selectedActivity,
    required int durationMinutes,
    required List<ActivityProfileModel> activityProfiles,
    required ValueChanged<ActivityProfileModel> onSelectActivity,
    required ValueChanged<int> onDurationChanged,
    bool isForecast = false,
    ValueChanged<bool>? onToggleForecast,
    Color accentColor = AppColors.cyanAccent,
  }) {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${mins > 0 ? '${mins}m' : ''}' : '${mins}m';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: accentColor,
                ),
              ),
              if (selectedActivity != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'V_E: ${selectedActivity.inhalationRateM3H} m³/h • ${selectedActivity.metEquivalent} METs',
                    style: const TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Activity Profile Chips
          const Text(
            'SELECT PHYSICAL ACTIVITY',
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: activityProfiles.map((act) {
                final isSelected = selectedActivity?.activityType == act.activityType;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: Icon(
                      act.activityType.icon,
                      size: 14,
                      color: isSelected ? Colors.black : AppColors.textSecondary,
                    ),
                    label: Text(act.displayName.split(' ').first),
                    selected: isSelected,
                    onSelected: (_) => onSelectActivity(act),
                    selectedColor: accentColor,
                    backgroundColor: AppColors.surfaceElevated,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.black : AppColors.textPrimary,
                    ),
                    side: BorderSide(
                      color: isSelected ? accentColor : AppColors.border,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Duration Slider & Quick Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'EXPOSURE DURATION',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accentColor,
              inactiveTrackColor: AppColors.border,
              thumbColor: accentColor,
              overlayColor: accentColor.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: durationMinutes.toDouble(),
              min: 15,
              max: 480,
              divisions: 31,
              onChanged: (val) => onDurationChanged(val.toInt()),
            ),
          ),
          // Preset Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [15, 30, 45, 60, 120, 240, 480].map((m) {
              final isCur = durationMinutes == m;
              final label = m >= 60 ? '${m ~/ 60}h' : '${m}m';
              return InkWell(
                onTap: () => onDurationChanged(m),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCur ? accentColor.withValues(alpha: 0.2) : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isCur ? accentColor : AppColors.border),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: isCur ? FontWeight.w800 : FontWeight.w500,
                      color: isCur ? accentColor : AppColors.textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Forecast Window Switch
          if (onToggleForecast != null) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simulate Future Forecast Window',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Project exposure using upcoming time-series forecast model',
                      style: TextStyle(fontSize: 9, color: AppColors.textMuted),
                    ),
                  ],
                ),
                Switch(
                  value: isForecast,
                  onChanged: onToggleForecast,
                  activeThumbColor: AppColors.cyanAccent,
                  activeTrackColor: AppColors.cyanAccent.withValues(alpha: 0.3),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimulationResults(BuildContext context, ExposureSimulationModel sim) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ESTIMATED CUMULATIVE EXPOSURE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.cyanAccent,
                    ),
                  ),
                  if (sim.cpcbAqi != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sim.aqiColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sim.aqiColor, width: 0.8),
                      ),
                      child: Text(
                        'AQI ${sim.cpcbAqi} • ${sim.cpcbCategory ?? ''}',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: sim.aqiColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'TOTAL AIR INHALED',
                      value: '${sim.totalInhaledVolumeM3} m³',
                      subtext: '${sim.durationMinutes}m of ${sim.activity.displayName}',
                      icon: Icons.air,
                      accentColor: AppColors.cyanAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'VENTILATION FACTOR',
                      value: '${(sim.activity.inhalationRateM3H / 0.50).toStringAsFixed(1)}x',
                      subtext: 'vs basal sedentary rest',
                      icon: Icons.speed,
                      accentColor: AppColors.emeraldAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Pollutant Breakdown Cards
        const Text(
          'CRITERIA POLLUTANT BREAKDOWN',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...sim.pollutants.values.map((pol) => _buildPollutantMetricCard(pol)),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: accentColor),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPollutantMetricCard(PollutantExposureMetricModel pol) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                pol.pollutant,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.cyanAccent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ambient: ${pol.ambientConcentration?.toStringAsFixed(1) ?? '--'} ${pol.concentrationUnit}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    Text(
                      'Inhaled Mass: ${pol.estimatedInhaledMass?.toStringAsFixed(1) ?? '--'} ${pol.massUnit}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Concentration-Time: ${pol.concentrationTimeExposure?.toStringAsFixed(1) ?? '--'} ${pol.exposureUnit}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonResults(BuildContext context, ExposureComparisonModel comp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Physical Delta Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.emeraldAccent.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.compare_arrows, size: 16, color: AppColors.emeraldAccent),
                  SizedBox(width: 8),
                  Text(
                    'SCENARIO COMPARISON (PHYSICAL DELTA)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.emeraldAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                comp.physicalComparisonSummary,
                style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Pollutant-specific Comparison Deltas
        const Text(
          'INHALED MASS DELTA BY POLLUTANT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...comp.deltas.values.map((delta) => _buildComparisonDeltaTile(delta)),
      ],
    );
  }

  Widget _buildComparisonDeltaTile(PollutantComparisonDeltaModel delta) {
    final hasReduction = (delta.deltaInhaledMass ?? 0) < 0;
    final color = hasReduction ? AppColors.aqiGood : AppColors.aqiPoor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                delta.pollutant,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color, width: 0.8),
                ),
                child: Text(
                  '${(delta.deltaInhaledMass ?? 0) >= 0 ? '+' : ''}${delta.deltaInhaledMass?.toStringAsFixed(1) ?? '0.0'} ${delta.massUnit} (${(delta.percentChangeInhaledMass ?? 0) >= 0 ? '+' : ''}${delta.percentChangeInhaledMass?.toStringAsFixed(1) ?? '0.0'}%)',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            delta.summary,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationCard(BuildContext context, ExposureExplanationModel expl) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology_outlined, size: 16, color: AppColors.cyanAccent),
              SizedBox(width: 8),
              Text(
                'AI ENVIRONMENTAL EXPOSURE INSIGHTS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.cyanAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            expl.narrative,
            style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 10),
          const Text(
            'KEY TAKEAWAYS:',
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          ...expl.keyTakeaways.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: AppColors.cyanAccent)),
                    Expanded(child: Text(t, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
                  ],
                ),
              )),
          if (expl.protectiveSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'PROTECTIVE PRECAUTIONS:',
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.emeraldAccent),
            ),
            const SizedBox(height: 4),
            ...expl.protectiveSuggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✓ ', style: TextStyle(color: AppColors.emeraldAccent)),
                      Expanded(child: Text(s, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildMethodologyDisclaimerCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
              SizedBox(width: 6),
              Text(
                'METHODOLOGY & SCIENTIFIC LIMITATIONS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '• Concentration-Time Exposure (µg·h/m³) represents cumulative ambient field exposure.\n'
            '• Estimated Inhaled Mass (µg) = Ambient Concentration × Adult Minute Ventilation (m³/h) × Duration.\n'
            '• Adult ventilation rates follow the US EPA Exposure Factors Handbook (2011, Chapter 6).\n'
            '• Gross inhaled mass is NOT absorbed internal dose or deposited pulmonary fraction. Individual lung geometry and respiration depth are not modeled.\n'
            '• Scientific Advisory: This simulator is an environmental intelligence tool. It does not provide medical diagnosis, personal clinical prediction, or guaranteed protection.',
            style: TextStyle(fontSize: 9, color: AppColors.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
