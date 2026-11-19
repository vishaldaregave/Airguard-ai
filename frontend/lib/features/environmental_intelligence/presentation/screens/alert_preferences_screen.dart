import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/alert_model.dart';
import '../controllers/alert_controller.dart';
import '../controllers/environmental_controller.dart';

class AlertPreferencesScreen extends ConsumerStatefulWidget {
  const AlertPreferencesScreen({super.key});

  @override
  ConsumerState<AlertPreferencesScreen> createState() => _AlertPreferencesScreenState();
}

class _AlertPreferencesScreenState extends ConsumerState<AlertPreferencesScreen> {
  bool _notificationsEnabled = true;
  double _aqiThreshold = 200.0;
  double _pm25Threshold = 60.0;
  double _pm10Threshold = 100.0;
  bool _suddenDeteriorationEnabled = true;
  bool _forecastAlertsEnabled = true;
  bool _recoveryAlertsEnabled = true;
  bool _quietHoursEnabled = false;
  int _quietHoursStart = 22;
  int _quietHoursEnd = 7;
  String? _preferredStationCode;
  String? _preferredStationName;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final prefs = ref.read(alertControllerProvider).preferences;
      if (prefs != null) {
        _populateFields(prefs);
      } else {
        ref.read(alertControllerProvider.notifier).fetchPreferences().then((_) {
          final p = ref.read(alertControllerProvider).preferences;
          if (p != null && mounted) {
            _populateFields(p);
          }
        });
      }
    });
  }

  void _populateFields(UserAlertPreference p) {
    setState(() {
      _notificationsEnabled = p.notificationsEnabled;
      _aqiThreshold = p.aqiThreshold.toDouble();
      _pm25Threshold = p.pm25Threshold;
      _pm10Threshold = p.pm10Threshold;
      _suddenDeteriorationEnabled = p.suddenDeteriorationEnabled;
      _forecastAlertsEnabled = p.forecastAlertsEnabled;
      _recoveryAlertsEnabled = p.recoveryAlertsEnabled;
      _quietHoursEnabled = p.quietHoursEnabled;
      _quietHoursStart = p.quietHoursStart;
      _quietHoursEnd = p.quietHoursEnd;
      _preferredStationCode = p.preferredStationCode;
      _preferredStationName = p.preferredStationName;
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final alertState = ref.watch(alertControllerProvider);
    final envState = ref.watch(environmentalControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Notification Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator(color: AppColors.cyanAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Master Switch Card
                  _buildCard(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Enable Environmental Alerts',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Receive real-time warnings when atmospheric hazards exceed your limits',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      value: _notificationsEnabled,
                      activeTrackColor: AppColors.emeraldAccent,
                      activeThumbColor: AppColors.surface,
                      onChanged: (val) => setState(() => _notificationsEnabled = val),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Threshold Controls Section
                  _buildSectionHeader('NOTIFICATION THRESHOLDS'),
                  const SizedBox(height: 10),

                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // AQI Slider
                        _buildSliderRow(
                          label: 'CPCB AQI Alert Threshold',
                          valueLabel: '${_aqiThreshold.toInt()} AQI',
                          subtext: _getAqiCategoryDescription(_aqiThreshold.toInt()),
                          value: _aqiThreshold,
                          min: 50.0,
                          max: 400.0,
                          divisions: 35,
                          activeColor: AppColors.getAqiColor(_aqiThreshold.toInt()),
                          onChanged: _notificationsEnabled
                              ? (v) => setState(() => _aqiThreshold = v)
                              : null,
                        ),
                        const Divider(color: AppColors.border, height: 28),

                        // PM2.5 Slider
                        _buildSliderRow(
                          label: 'PM2.5 Notification Limit',
                          valueLabel: '${_pm25Threshold.toStringAsFixed(0)} µg/m³',
                          subtext: 'CPCB 24-hr safety standard is 60.0 µg/m³',
                          value: _pm25Threshold,
                          min: 20.0,
                          max: 250.0,
                          divisions: 23,
                          activeColor: AppColors.cyanAccent,
                          onChanged: _notificationsEnabled
                              ? (v) => setState(() => _pm25Threshold = v)
                              : null,
                        ),
                        const Divider(color: AppColors.border, height: 28),

                        // PM10 Slider
                        _buildSliderRow(
                          label: 'PM10 Notification Limit',
                          valueLabel: '${_pm10Threshold.toStringAsFixed(0)} µg/m³',
                          subtext: 'CPCB 24-hr safety standard is 100.0 µg/m³',
                          value: _pm10Threshold,
                          min: 40.0,
                          max: 350.0,
                          divisions: 31,
                          activeColor: AppColors.cobaltAccent,
                          onChanged: _notificationsEnabled
                              ? (v) => setState(() => _pm10Threshold = v)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Smart Alert Behaviors
                  _buildSectionHeader('SMART ALERT BEHAVIOURS'),
                  const SizedBox(height: 10),

                  _buildCard(
                    child: Column(
                      children: [
                        _buildToggleRow(
                          title: 'Sudden Deterioration Warnings',
                          subtitle: 'Alert immediately if AQI spikes by ≥40 points within 3 hours',
                          value: _suddenDeteriorationEnabled,
                          onChanged: _notificationsEnabled
                              ? (v) => setState(() => _suddenDeteriorationEnabled = v)
                              : null,
                        ),
                        const Divider(color: AppColors.border, height: 20),
                        _buildToggleRow(
                          title: 'Forecast-Based Warnings',
                          subtitle: 'Receive pre-emptive notices for validated +1h to +6h horizons',
                          value: _forecastAlertsEnabled,
                          onChanged: _notificationsEnabled
                              ? (v) => setState(() => _forecastAlertsEnabled = v)
                              : null,
                        ),
                        const Divider(color: AppColors.border, height: 20),
                        _buildToggleRow(
                          title: 'Recovery Notifications',
                          subtitle: 'Notify when conditions improve and drop safely below threshold',
                          value: _recoveryAlertsEnabled,
                          onChanged: _notificationsEnabled
                              ? (v) => setState(() => _recoveryAlertsEnabled = v)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quiet Hours Section
                  _buildSectionHeader('QUIET HOURS (NOTIFICATION SUPPRESSION)'),
                  const SizedBox(height: 10),

                  _buildCard(
                    child: Column(
                      children: [
                        _buildToggleRow(
                          title: 'Enable Quiet Hours',
                          subtitle: 'Suppress push alerts while logging environmental records silently',
                          value: _quietHoursEnabled,
                          onChanged: _notificationsEnabled
                              ? (v) => setState(() => _quietHoursEnabled = v)
                              : null,
                        ),
                        if (_quietHoursEnabled) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildHourPicker(
                                  label: 'STARTS AT',
                                  hour: _quietHoursStart,
                                  onChanged: (h) => setState(() => _quietHoursStart = h),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildHourPicker(
                                  label: 'ENDS AT',
                                  hour: _quietHoursEnd,
                                  onChanged: (h) => setState(() => _quietHoursEnd = h),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Location Selection Section
                  _buildSectionHeader('MONITORING LOCATION'),
                  const SizedBox(height: 10),

                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Preferred Station',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Restrict push notifications to a specific station or monitor all local sensors',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final items = <DropdownMenuItem<String?>>[
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Nearby Regional Stations', style: TextStyle(color: AppColors.textPrimary)),
                              ),
                            ];

                            for (final stn in envState.nearbyStations) {
                              items.add(
                                DropdownMenuItem<String?>(
                                  value: stn.stationId,
                                  child: Text(stn.stationName, style: const TextStyle(color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                                ),
                              );
                            }

                            if (_preferredStationCode != null && !envState.nearbyStations.any((s) => s.stationId == _preferredStationCode)) {
                              items.add(
                                DropdownMenuItem<String?>(
                                  value: _preferredStationCode,
                                  child: Text(_preferredStationName ?? _preferredStationCode!, style: const TextStyle(color: AppColors.textPrimary)),
                                ),
                              );
                            }

                            return DropdownButtonFormField<String?>(
                              initialValue: _preferredStationCode,
                              dropdownColor: AppColors.surfaceElevated,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.surfaceElevated,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                              ),
                              items: items,
                              onChanged: _notificationsEnabled
                                  ? (val) {
                                      setState(() {
                                        _preferredStationCode = val;
                                        if (val == null) {
                                          _preferredStationName = null;
                                        } else {
                                          final found = envState.nearbyStations.where((s) => s.stationId == val).firstOrNull;
                                          _preferredStationName = found?.stationName;
                                        }
                                      });
                                    }
                                  : null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: alertState.isUpdatingPrefs
                          ? null
                          : () async {
                              final updated = UserAlertPreference(
                                userId: alertState.preferences?.userId ?? 'default_user',
                                notificationsEnabled: _notificationsEnabled,
                                aqiThreshold: _aqiThreshold.toInt(),
                                pm25Threshold: _pm25Threshold,
                                pm10Threshold: _pm10Threshold,
                                suddenDeteriorationEnabled: _suddenDeteriorationEnabled,
                                forecastAlertsEnabled: _forecastAlertsEnabled,
                                recoveryAlertsEnabled: _recoveryAlertsEnabled,
                                quietHoursEnabled: _quietHoursEnabled,
                                quietHoursStart: _quietHoursStart,
                                quietHoursEnd: _quietHoursEnd,
                                preferredStationCode: _preferredStationCode,
                                preferredStationName: _preferredStationName,
                                updatedAt: DateTime.now(),
                              );

                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(context);

                              final success = await ref
                                  .read(alertControllerProvider.notifier)
                                  .updatePreferences(updated);

                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Notification preferences saved.'
                                        : 'Failed to save preferences.',
                                  ),
                                  backgroundColor: success ? AppColors.liveBadge : AppColors.aqiSevere,
                                ),
                              );
                              if (success) navigator.pop();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyanAccent,
                        foregroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: alertState.isUpdatingPrefs
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            )
                          : const Text(
                              'Save Preferences',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required String valueLabel,
    required String subtext,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Color activeColor,
    required ValueChanged<double>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              valueLabel,
              style: TextStyle(
                color: activeColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtext,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: activeColor,
            thumbColor: activeColor,
            overlayColor: activeColor.withValues(alpha: 0.2),
            inactiveTrackColor: AppColors.borderHighlight,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeTrackColor: AppColors.cyanAccent,
          activeThumbColor: AppColors.surface,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildHourPicker({
    required String label,
    required int hour,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          DropdownButton<int>(
            value: hour,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: AppColors.surfaceElevated,
            items: List.generate(24, (i) {
              final formatted = '${i.toString().padLeft(2, '0')}:00';
              return DropdownMenuItem(
                value: i,
                child: Text(
                  formatted,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                ),
              );
            }),
            onChanged: (val) {
              if (val != null) onChanged(val);
            },
          ),
        ],
      ),
    );
  }

  String _getAqiCategoryDescription(int aqi) {
    if (aqi <= 100) return 'Satisfactory (Mild respiratory impact on sensitive groups)';
    if (aqi <= 200) return 'Moderate (Breathing discomfort to sensitive individuals)';
    if (aqi <= 300) return 'Poor (Breathing discomfort to most people on prolonged exposure)';
    if (aqi <= 400) return 'Very Poor (Respiratory illness on prolonged exposure)';
    return 'Severe (Affects healthy people and seriously impacts sensitive groups)';
  }
}
