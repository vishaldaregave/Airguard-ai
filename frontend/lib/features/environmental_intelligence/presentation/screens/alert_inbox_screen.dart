import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/alert_model.dart';
import '../controllers/alert_controller.dart';
import 'alert_detail_sheet.dart';
import 'alert_preferences_screen.dart';

class AlertInboxScreen extends ConsumerStatefulWidget {
  const AlertInboxScreen({super.key});

  @override
  ConsumerState<AlertInboxScreen> createState() => _AlertInboxScreenState();
}

class _AlertInboxScreenState extends ConsumerState<AlertInboxScreen> {
  String _activeFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(alertControllerProvider.notifier).fetchAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final alertState = ref.watch(alertControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Environmental Alerts',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            if (alertState.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.aqiPoor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${alertState.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (alertState.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded, size: 20, color: AppColors.cyanAccent),
              tooltip: 'Mark all as read',
              onPressed: () {
                ref.read(alertControllerProvider.notifier).markAllAsRead();
              },
            ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20, color: AppColors.textSecondary),
            tooltip: 'Notification Preferences',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AlertPreferencesScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(alertControllerProvider.notifier).fetchAlerts(),
        color: AppColors.cyanAccent,
        backgroundColor: AppColors.surface,
        child: Column(
          children: [
            // Filter Selector Chips
            _buildFilterBar(),

            // Alert List or Empty State
            Expanded(
              child: alertState.isLoading && alertState.alerts.isEmpty
                  ? _buildLoadingState()
                  : alertState.alerts.isEmpty
                      ? _buildEmptyState()
                      : _buildAlertList(alertState.alerts),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['ALL', 'UNREAD', 'CRITICAL', 'DANGER', 'WARNING'];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface.withValues(alpha: 0.5),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _activeFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() => _activeFilter = filter);
              final notifier = ref.read(alertControllerProvider.notifier);
              if (filter == 'ALL') {
                notifier.setFilter(unreadOnly: false, severity: null);
              } else if (filter == 'UNREAD') {
                notifier.setFilter(unreadOnly: true, severity: null);
              } else {
                notifier.setFilter(unreadOnly: false, severity: filter);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.cyanAccent.withValues(alpha: 0.2) : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.cyanAccent : AppColors.border,
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? AppColors.cyanAccent : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlertList(List<AlertItem> alerts) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return _buildAlertCard(alert);
      },
    );
  }

  Widget _buildAlertCard(AlertItem alert) {
    final severityColor = alert.severity.color;

    return GestureDetector(
      onTap: () {
        if (!alert.isRead) {
          ref.read(alertControllerProvider.notifier).markAlertAsRead(alert.alertId);
        }
        AlertDetailSheet.show(
          context,
          alert,
          onMarkRead: () {
            ref.read(alertControllerProvider.notifier).markAlertAsRead(alert.alertId);
          },
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: alert.isRead ? AppColors.surface : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: alert.isRead ? AppColors.border : severityColor.withValues(alpha: 0.6),
            width: alert.isRead ? 1.0 : 1.5,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Severity badge, Forecast vs Observed tag, Unread dot, and Time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: severityColor, width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(alert.severity.icon, size: 12, color: severityColor),
                      const SizedBox(width: 4),
                      Text(
                        alert.severity.displayName,
                        style: TextStyle(
                          color: severityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Forecast vs Observed Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: alert.isForecast
                        ? AppColors.forecastBadge.withValues(alpha: 0.15)
                        : AppColors.liveBadge.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    alert.isForecast
                        ? 'FORECAST (+${alert.forecastHorizonHours ?? 1}h)'
                        : 'OBSERVED',
                    style: TextStyle(
                      color: alert.isForecast ? AppColors.forecastBadge : AppColors.liveBadge,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                const Spacer(),

                if (!alert.isRead)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.cyanAccent,
                      shape: BoxShape.circle,
                    ),
                  ),

                Text(
                  _formatTimeAgo(alert.observationTimestamp),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Station Name & Alert Type Title
            Text(
              alert.alertType.displayName,
              style: TextStyle(
                color: alert.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              alert.stationName,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Trigger summary
            Text(
              alert.triggerReason,
              style: TextStyle(
                color: alert.isRead ? AppColors.textMuted : AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 42,
                color: AppColors.emeraldAccent,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Active Environmental Alerts',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Air quality readings in your monitored locations are currently within your configured safety thresholds.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.cyanAccent,
        strokeWidth: 2.5,
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
