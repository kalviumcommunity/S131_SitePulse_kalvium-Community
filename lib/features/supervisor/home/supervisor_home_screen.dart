import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/core/widgets/offline_banner.dart';
import 'package:site_pulse/core/widgets/status_views.dart';
import 'package:site_pulse/core/widgets/sync_chip.dart';
import 'package:site_pulse/data/models/attendance_entry.dart';
import 'package:site_pulse/data/models/incident.dart';
import 'package:site_pulse/data/models/material.dart' as sp;
import 'package:site_pulse/data/models/material_log.dart';
import 'package:site_pulse/data/models/site.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/features/auth/auth_controller.dart';

// ---------------------------------------------------------------------------
// Activity Feed Data Types & Providers
// ---------------------------------------------------------------------------

enum ActivityType { attendance, material, incident }

class ActivityItem {
  final String id;
  final ActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final bool hasPendingWrites;

  const ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.hasPendingWrites = false,
  });
}

final _supervisorSiteProvider = StreamProvider.autoDispose
    .family<Site?, String>((ref, siteId) {
      if (siteId.isEmpty) return Stream.value(null);
      return ref.watch(siteRepositoryProvider).watchSite(siteId);
    });

final _siteAttendanceProvider = StreamProvider.autoDispose
    .family<List<AttendanceEntry>, String>((ref, siteId) {
      if (siteId.isEmpty) return Stream.value([]);
      return ref
          .watch(attendanceRepositoryProvider)
          .watchAttendance(siteId: siteId);
    });

final _materialLogsProvider = StreamProvider.autoDispose
    .family<List<MaterialLog>, String>((ref, siteId) {
      return ref
          .watch(materialRepositoryProvider)
          .watchMaterialLogs(siteId: siteId);
    });

final _materialsProvider = StreamProvider.autoDispose
    .family<List<sp.Material>, String>((ref, siteId) {
      return ref
          .watch(materialRepositoryProvider)
          .watchMaterials(siteId: siteId);
    });

final _siteIncidentsProvider = StreamProvider.autoDispose
    .family<List<Incident>, String>((ref, siteId) {
      return ref
          .watch(incidentRepositoryProvider)
          .watchIncidents(siteId: siteId);
    });

final supervisorActivityProvider = Provider.autoDispose
    .family<AsyncValue<List<ActivityItem>>, String>((ref, siteId) {
      final attendanceAsync = ref.watch(_siteAttendanceProvider(siteId));
      final materialLogsAsync = ref.watch(_materialLogsProvider(siteId));
      final materialsAsync = ref.watch(_materialsProvider(siteId));
      final incidentsAsync = ref.watch(_siteIncidentsProvider(siteId));

      if (attendanceAsync.isLoading && !attendanceAsync.hasValue) {
        return const AsyncValue.loading();
      }
      if (materialLogsAsync.isLoading && !materialLogsAsync.hasValue) {
        return const AsyncValue.loading();
      }
      if (incidentsAsync.isLoading && !incidentsAsync.hasValue) {
        return const AsyncValue.loading();
      }

      if (attendanceAsync.hasError && !attendanceAsync.hasValue) {
        return AsyncValue.error(
          attendanceAsync.error!,
          attendanceAsync.stackTrace!,
        );
      }
      if (materialLogsAsync.hasError && !materialLogsAsync.hasValue) {
        return AsyncValue.error(
          materialLogsAsync.error!,
          materialLogsAsync.stackTrace!,
        );
      }
      if (incidentsAsync.hasError && !incidentsAsync.hasValue) {
        return AsyncValue.error(
          incidentsAsync.error!,
          incidentsAsync.stackTrace!,
        );
      }

      final attendance = attendanceAsync.value ?? [];
      final logs = materialLogsAsync.value ?? [];
      final materials = materialsAsync.value ?? [];
      final incidents = incidentsAsync.value ?? [];

      final materialMap = {
        for (final m in materials) '${m.siteId ?? siteId}::${m.id}': m,
      };
      final List<ActivityItem> items = [];

      // Group attendance records by day
      final attendanceByDate = <String, List<AttendanceEntry>>{};
      for (final a in attendance) {
        final dStr = '${a.date.year}-${a.date.month}-${a.date.day}';
        attendanceByDate.putIfAbsent(dStr, () => []).add(a);
      }
      for (final entry in attendanceByDate.entries) {
        final list = entry.value;
        final date = list.first.date;
        final presentCount = list
            .where((a) => a.status == AttendanceStatus.present)
            .length;
        final halfCount = list
            .where((a) => a.status == AttendanceStatus.half)
            .length;
        final hasPending = list.any((a) => a.hasPendingWrites);

        items.add(
          ActivityItem(
            id: 'att_${entry.key}',
            type: ActivityType.attendance,
            title: 'Attendance Recorded',
            description:
                '$presentCount present, $halfCount half-day (${list.length} total)',
            timestamp: date,
            hasPendingWrites: hasPending,
          ),
        );
      }

      // Material logs
      for (final log in logs) {
        final materialKey = '${log.siteId ?? siteId}::${log.materialId}';
        final matName = materialMap[materialKey]?.name ?? 'Material';
        final unit = materialMap[materialKey]?.unit ?? 'units';
        items.add(
          ActivityItem(
            id: 'mat_${log.id}',
            type: ActivityType.material,
            title: 'Material Logged: $matName',
            description:
                'Used ${log.qtyUsed.toStringAsFixed(1)} $unit (${log.remainingAfter.toStringAsFixed(1)} $unit remaining)',
            timestamp: log.date,
            hasPendingWrites: log.hasPendingWrites,
          ),
        );
      }

      // Incidents
      for (final inc in incidents) {
        items.add(
          ActivityItem(
            id: 'inc_${inc.id}',
            type: ActivityType.incident,
            title: 'Incident: ${inc.severity.name.toUpperCase()}',
            description: inc.description,
            timestamp: inc.occurredAt,
            hasPendingWrites: inc.hasPendingWrites,
          ),
        );
      }

      // Sort descending by timestamp and limit to 10
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return AsyncValue.data(items.take(10).toList());
    });

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SupervisorHomeScreen extends ConsumerWidget {
  const SupervisorHomeScreen({super.key});

  String _formatTime(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);

    if (diff.inMinutes < 60 && diff.inMinutes >= 0) {
      final mins = diff.inMinutes;
      return mins <= 1 ? 'Just now' : '$mins mins ago';
    }
    if (diff.inHours < 24 && diff.inHours > 0) {
      return '${diff.inHours}h ago';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepo = ref.watch(authRepositoryProvider);
    final user = authRepo.currentUser;
    final siteId = user?.siteId;

    if (siteId == null || siteId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Supervisor Home'),
          actions: [
            IconButton(
              key: const Key('logout_button'),
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () => ref.read(authControllerProvider).signOut(),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: OfflineBanner(),
          ),
        ),
        body: const EmptyView(
          message: 'No project site is assigned to this account.',
        ),
      );
    }

    final siteAsync = ref.watch(_supervisorSiteProvider(siteId));
    final activityAsync = ref.watch(supervisorActivityProvider(siteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Home'),
        actions: [
          IconButton(
            key: const Key('logout_button'),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => ref.read(authControllerProvider).signOut(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: OfflineBanner(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_supervisorSiteProvider(siteId));
          ref.invalidate(_siteAttendanceProvider(siteId));
          ref.invalidate(_materialLogsProvider(siteId));
          ref.invalidate(_materialsProvider(siteId));
          ref.invalidate(_siteIncidentsProvider(siteId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Supervisor Header & Site Info Card ───────────────────
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.name ?? 'Supervisor',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Name: ${user?.name ?? 'Unknown'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Role: ${user?.role.name ?? 'Unknown'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              key: const Key('logout_button_large'),
                              icon: const Icon(Icons.logout, size: 16),
                              label: const Text('Logout'),
                              onPressed: () =>
                                  ref.read(authControllerProvider).signOut(),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: siteAsync.when(
                                loading: () => const Text(
                                  'Loading site…',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                error: (_, _) => Text(
                                  'Site: $siteId',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                data: (site) => Text(
                                  site != null
                                      ? site.name
                                      : (siteId.isNotEmpty
                                            ? 'Site: $siteId'
                                            : 'No Site Assigned'),
                                  key: const Key('site_name_header'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Quick Actions ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Daily Actions',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    _ActionCard(
                      key: const Key('action_attendance'),
                      icon: Icons.how_to_reg,
                      iconColor: const Color(0xFF1976D2),
                      title: 'Mark Attendance',
                      subtitle: 'Record daily presence for site crew',
                      onTap: () => context.push('/supervisor/attendance'),
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      key: const Key('action_material'),
                      icon: Icons.inventory_2,
                      iconColor: const Color(0xFFE65100),
                      title: 'Log Material Usage',
                      subtitle: 'Record material consumption and track stock',
                      onTap: () => context.push('/supervisor/material'),
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      key: const Key('action_incident'),
                      icon: Icons.warning_amber_rounded,
                      iconColor: AppColors.critical,
                      title: 'Report Incident',
                      subtitle: 'Log hazards, safety events, and escalations',
                      onTap: () => context.push('/supervisor/incident'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        key: const Key('action_roster'),
                        icon: const Icon(Icons.people_outline),
                        label: const Text('Manage Site Worker Roster'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => context.push('/supervisor/roster'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Divider(thickness: 8, height: 24),

              // ── Recent Activity Feed ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text(
                      'Recent Activity Feed',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      'Latest 10 items',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              activityAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: LoadingView(message: 'Loading activity feed…'),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ErrorView(
                    message: 'Failed to load activity: $e',
                    onRetry: () {
                      ref.invalidate(_siteAttendanceProvider(siteId));
                      ref.invalidate(_materialLogsProvider(siteId));
                      ref.invalidate(_siteIncidentsProvider(siteId));
                    },
                  ),
                ),
                data: (activities) {
                  if (activities.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: EmptyView(
                        message:
                            'No recent activity recorded for this site yet.',
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: activities.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = activities[index];
                      return _ActivityTile(item: item, formatTime: _formatTime);
                    },
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action Card Widget (Large 48dp+ tap targets)
// ---------------------------------------------------------------------------

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: iconColor.withValues(alpha: 0.12),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity Tile Widget
// ---------------------------------------------------------------------------

class _ActivityTile extends StatelessWidget {
  final ActivityItem item;
  final String Function(DateTime) formatTime;

  const _ActivityTile({required this.item, required this.formatTime});

  IconData _iconForType(ActivityType type) {
    switch (type) {
      case ActivityType.attendance:
        return Icons.how_to_reg;
      case ActivityType.material:
        return Icons.inventory_2;
      case ActivityType.incident:
        return Icons.warning_amber_rounded;
    }
  }

  Color _colorForType(ActivityType type) {
    switch (type) {
      case ActivityType.attendance:
        return const Color(0xFF1976D2);
      case ActivityType.material:
        return const Color(0xFFE65100);
      case ActivityType.incident:
        return AppColors.critical;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(item.type);
    final icon = _iconForType(item.type);

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        formatTime(item.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SyncChip(pending: item.hasPendingWrites),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
