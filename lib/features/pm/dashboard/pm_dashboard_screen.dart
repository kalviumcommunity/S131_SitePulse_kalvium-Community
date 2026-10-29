import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:site_pulse/core/constants/thresholds.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/core/widgets/app_page_background.dart';
import 'package:site_pulse/core/widgets/offline_banner.dart';
import 'package:site_pulse/core/widgets/status_views.dart';
import 'package:site_pulse/data/models/attendance_entry.dart';
import 'package:site_pulse/data/models/incident.dart';
import 'package:site_pulse/data/models/material.dart' as sp;
import 'package:site_pulse/data/models/site.dart';
import 'package:site_pulse/data/models/worker.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/features/auth/auth_controller.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _allSitesProvider = StreamProvider.autoDispose<List<Site>>((ref) {
  return ref.watch(siteRepositoryProvider).watchSites();
});

final _allMaterialsProvider =
    StreamProvider.autoDispose<List<sp.Material>>((ref) {
  return ref.watch(materialRepositoryProvider).watchMaterials();
});

final _siteWorkersProvider =
    StreamProvider.autoDispose.family<List<Worker>, String>((ref, siteId) {
  return ref.watch(workerRepositoryProvider).watchWorkers(siteId);
});

final _pmIncidentsProvider = StreamProvider.autoDispose
    .family<List<Incident>, DateTimeRange?>((ref, range) {
  return ref.watch(incidentRepositoryProvider).watchIncidents(
        startDate: range?.start,
        endDate: range?.end,
      );
});

final _pmAttendanceProvider = StreamProvider.autoDispose
    .family<List<AttendanceEntry>, DateTimeRange?>((ref, range) {
  return ref.watch(attendanceRepositoryProvider).watchAttendance(
        startDate: range?.start,
        endDate: range?.end,
      );
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PmDashboardScreen extends ConsumerStatefulWidget {
  const PmDashboardScreen({super.key});

  @override
  ConsumerState<PmDashboardScreen> createState() => _PmDashboardScreenState();
}

class _PmDashboardScreenState extends ConsumerState<PmDashboardScreen> {
  String? _selectedSiteId; // null = All Sites
  late DateTimeRange _dateRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 6)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  String _formatRangeLabel(DateTimeRange r) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${r.start.day} ${months[r.start.month - 1]} – ${r.end.day} ${months[r.end.month - 1]}';
  }

  String _formatLastSynced(DateTime? dt) {
    if (dt == null) return 'Never synced';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return m <= 1 ? 'Just now' : '$m mins ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    final days = diff.inDays;
    return '$days days ago';
  }

  bool _isSyncStale(DateTime? dt) {
    if (dt == null) return true;
    return DateTime.now().difference(dt).inHours >= 24;
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month, picked.start.day),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.watch(authRepositoryProvider);
    final user = authRepo.currentUser;

    final sitesAsync = ref.watch(_allSitesProvider);
    final materialsAsync = ref.watch(_allMaterialsProvider);
    final incidentsAsync = ref.watch(_pmIncidentsProvider(_dateRange));
    final attendanceAsync = ref.watch(_pmAttendanceProvider(_dateRange));

    return Scaffold(
      appBar: AppBar(
        title: const Text('PM Dashboard'),
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
      body: AppPageBackground(
        child: sitesAsync.when(
        loading: () => const LoadingView(message: 'Loading sites…'),
        error: (e, _) => ErrorView(
          message: 'Failed to load sites: $e',
          onRetry: () => ref.invalidate(_allSitesProvider),
        ),
        data: (sites) {
          final materials = materialsAsync.value ?? [];
          final incidents = incidentsAsync.value ?? [];
          final attendance = attendanceAsync.value ?? [];

          // ── Metrics Calculations ─────────────────────────────────
          // 1. Crew Attendance %
          String attendancePercentText = '100%';
          if (attendance.isNotEmpty) {
            final present =
                attendance.where((a) => a.status == AttendanceStatus.present).length;
            final half =
                attendance.where((a) => a.status == AttendanceStatus.half).length;
            final rate = ((present + (half * 0.5)) / attendance.length) * 100;
            attendancePercentText = '${rate.toStringAsFixed(0)}%';
          }

          // 2. Low stock materials count
          final lowStockCount = materials.where((m) => isLowStock(m)).length;

          // 3. High severity incidents count
          final highIncidentsCount =
              incidents.where((i) => isHighSeverity(i.severity)).length;

          // Filter sites
          final displayedSites = _selectedSiteId == null
              ? sites
              : sites.where((s) => s.id == _selectedSiteId).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_allSitesProvider);
              ref.invalidate(_allMaterialsProvider);
              ref.invalidate(_pmIncidentsProvider(_dateRange));
              ref.invalidate(_pmAttendanceProvider(_dateRange));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Profile / User Info Card ──────────────────────────
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.12),
                            child: const Icon(
                              Icons.business_center,
                              color: AppColors.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name ?? 'Project Manager',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Name: ${user?.name ?? 'Unknown'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Role: ${user?.role.name ?? 'pm'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
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
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Top Filters (Site Selector & Date Range Picker) ───
                  Row(
                    children: [
                      // Site Dropdown Selector
                      Expanded(
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              key: const Key('pm_site_filter'),
                              value: _selectedSiteId,
                              isExpanded: true,
                              hint: const Text('All Sites'),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Sites (Overview)'),
                                ),
                                ...sites.map(
                                  (s) => DropdownMenuItem<String?>(
                                    value: s.id,
                                    child: Text(s.name),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                setState(() => _selectedSiteId = val);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Date Range Picker Button
                      InkWell(
                        key: const Key('pm_date_filter'),
                        onTap: _pickDateRange,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                _formatRangeLabel(_dateRange),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Summary Metric Cards ──────────────────────────────
                  Row(
                    children: [
                      // Metric 1: Crew Attendance %
                      Expanded(
                        child: _MetricCard(
                          key: const Key('metric_crew_attendance'),
                          title: 'Crew Attendance',
                          value: attendancePercentText,
                          subtitle: 'Attendance rate',
                          icon: Icons.people_alt_outlined,
                          color: const Color(0xFF1976D2),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Metric 2: Sites with Low Stock
                      Expanded(
                        child: _MetricCard(
                          key: const Key('metric_low_stock'),
                          title: 'Low Stock',
                          value: '$lowStockCount',
                          subtitle: 'Materials flagged',
                          icon: Icons.inventory_2_outlined,
                          color: lowStockCount > 0
                              ? const Color(0xFFE65100)
                              : AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Metric 3: High Severity Incidents
                      Expanded(
                        child: _MetricCard(
                          key: const Key('metric_high_incidents'),
                          title: 'High Incidents',
                          value: '$highIncidentsCount',
                          subtitle: 'Critical / High',
                          icon: Icons.warning_amber_rounded,
                          color: highIncidentsCount > 0
                              ? AppColors.critical
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Sites List Header ─────────────────────────────────
                  Row(
                    children: [
                      Text(
                        'Monitored Sites (${displayedSites.length})',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap site to inspect',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (displayedSites.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: EmptyView(
                        message: 'No sites match the selected filter.',
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedSites.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final site = displayedSites[index];
                        final isStale = _isSyncStale(site.lastEntryAt);

                        // Calculate site specific incident flags
                        final siteHighIncidents = incidents
                            .where((i) =>
                                i.siteId == site.id && isHighSeverity(i.severity))
                            .length;

                        return _SiteDashboardCard(
                          key: Key('site_card_${site.id}'),
                          site: site,
                          lastSyncedText: _formatLastSynced(site.lastEntryAt),
                          isStale: isStale,
                          hasLowStock: lowStockCount > 0,
                          highIncidentsCount: siteHighIncidents,
                          onTap: () => context.push('/pm/site/${site.id}'),
                        );
                      },
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metric Card Widget
// ---------------------------------------------------------------------------

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Site Card Widget for PM Dashboard
// ---------------------------------------------------------------------------

class _SiteDashboardCard extends ConsumerWidget {
  final Site site;
  final String lastSyncedText;
  final bool isStale;
  final bool hasLowStock;
  final int highIncidentsCount;
  final VoidCallback onTap;

  const _SiteDashboardCard({
    super.key,
    required this.site,
    required this.lastSyncedText,
    required this.isStale,
    required this.hasLowStock,
    required this.highIncidentsCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workersAsync = ref.watch(_siteWorkersProvider(site.id));
    final crewCount = workersAsync.value?.where((w) => w.active).length ?? 0;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isStale ? Colors.amber.shade400 : Colors.grey.shade200,
          width: isStale ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Site Name & Last Synced
              Row(
                children: [
                  const Icon(Icons.location_city, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      site.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isStale ? Colors.amber.shade100 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sync,
                          size: 13,
                          color: isStale ? Colors.amber.shade900 : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          lastSyncedText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isStale
                                ? Colors.amber.shade900
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Middle Row: Crew count & Status Badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Crew Count Badge
                  _StatusChip(
                    icon: Icons.groups,
                    label: '$crewCount crew active',
                    color: const Color(0xFF1976D2),
                  ),

                  // Material Status Badge
                  if (hasLowStock)
                    _StatusChip(
                      icon: Icons.warning_amber,
                      label: 'Low Stock Alert',
                      color: const Color(0xFFE65100),
                    )
                  else
                    _StatusChip(
                      icon: Icons.check_circle_outline,
                      label: 'Stock Healthy',
                      color: AppColors.success,
                    ),

                  // Safety Incidents Badge
                  if (highIncidentsCount > 0)
                    _StatusChip(
                      icon: Icons.report_problem,
                      label: '$highIncidentsCount Critical/High',
                      color: AppColors.critical,
                    )
                  else
                    _StatusChip(
                      icon: Icons.security,
                      label: 'Zero Incidents',
                      color: AppColors.success,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
