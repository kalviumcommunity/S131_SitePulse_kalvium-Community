import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/core/constants/thresholds.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/core/widgets/app_page_background.dart';
import 'package:site_pulse/core/widgets/offline_banner.dart';
import 'package:site_pulse/core/widgets/status_views.dart';
import 'package:site_pulse/core/widgets/sync_chip.dart';
import 'package:site_pulse/data/models/attendance_entry.dart';
import 'package:site_pulse/data/models/incident.dart';
import 'package:site_pulse/data/models/material.dart' as sp;
import 'package:site_pulse/data/models/material_log.dart';
import 'package:site_pulse/data/models/site.dart';
import 'package:site_pulse/data/models/worker.dart';
import 'package:site_pulse/data/providers.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _siteDetailProvider =
    StreamProvider.autoDispose.family<Site?, String>((ref, siteId) {
  return ref.watch(siteRepositoryProvider).watchSite(siteId);
});

final _siteDetailWorkersProvider =
    StreamProvider.autoDispose.family<List<Worker>, String>((ref, siteId) {
  return ref.watch(workerRepositoryProvider).watchWorkers(siteId);
});

final _siteDetailAttendanceProvider = StreamProvider.autoDispose
    .family<List<AttendanceEntry>, _SiteDetailQuery>((ref, query) {
  return ref.watch(attendanceRepositoryProvider).watchAttendance(
        siteId: query.siteId,
        startDate: query.range.start,
        endDate: query.range.end,
      );
});

final _siteDetailMaterialsProvider =
    StreamProvider.autoDispose<List<sp.Material>>((ref) {
  return ref.watch(materialRepositoryProvider).watchMaterials();
});

final _siteDetailMaterialLogsProvider = StreamProvider.autoDispose
    .family<List<MaterialLog>, _SiteDetailQuery>((ref, query) {
  return ref.watch(materialRepositoryProvider).watchMaterialLogs(
        startDate: query.range.start,
        endDate: query.range.end,
      );
});

final _siteDetailIncidentsProvider = StreamProvider.autoDispose
    .family<List<Incident>, _SiteDetailQuery>((ref, query) {
  return ref.watch(incidentRepositoryProvider).watchIncidents(
        siteId: query.siteId,
        startDate: query.range.start,
        endDate: query.range.end,
      );
});

class _SiteDetailQuery {
  final String siteId;
  final DateTimeRange range;

  const _SiteDetailQuery(this.siteId, this.range);

  @override
  bool operator ==(Object other) =>
      other is _SiteDetailQuery &&
      siteId == other.siteId &&
      range.start == other.range.start &&
      range.end == other.range.end;

  @override
  int get hashCode => Object.hash(siteId, range.start, range.end);
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PmSiteDetailScreen extends ConsumerStatefulWidget {
  final String siteId;
  const PmSiteDetailScreen({super.key, required this.siteId});

  @override
  ConsumerState<PmSiteDetailScreen> createState() => _PmSiteDetailScreenState();
}

class _PmSiteDetailScreenState extends ConsumerState<PmSiteDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTimeRange _dateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 29)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatRangeLabel(DateTimeRange r) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${r.start.day} ${months[r.start.month - 1]} – ${r.end.day} ${months[r.end.month - 1]}';
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
    final siteAsync = ref.watch(_siteDetailProvider(widget.siteId));
    final query = _SiteDetailQuery(widget.siteId, _dateRange);

    return Scaffold(
      appBar: AppBar(
        title: siteAsync.when(
          loading: () => const Text('Site Detail…'),
          error: (_, _) => Text('Site: ${widget.siteId}'),
          data: (site) => Text(site?.name ?? 'Site: ${widget.siteId}'),
        ),
        actions: [
          TextButton.icon(
            key: const Key('pm_site_date_filter'),
            icon: const Icon(Icons.calendar_month, size: 16),
            label: Text(_formatRangeLabel(_dateRange)),
            onPressed: _pickDateRange,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    key: Key('tab_attendance'),
                    icon: Icon(Icons.how_to_reg),
                    text: 'Attendance',
                  ),
                  Tab(
                    key: Key('tab_materials'),
                    icon: Icon(Icons.inventory_2),
                    text: 'Materials',
                  ),
                  Tab(
                    key: Key('tab_incidents'),
                    icon: Icon(Icons.warning_amber),
                    text: 'Incidents',
                  ),
                ],
              ),
              const OfflineBanner(),
            ],
          ),
        ),
      ),
      body: AppPageBackground(
        child: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Attendance History ─────────────────────────────
          _AttendanceTab(
            key: const Key('tab_attendance_view'),
            siteId: widget.siteId,
            query: query,
          ),

          // ── Tab 2: Materials Stock & Logs ────────────────────────
          _MaterialsTab(
            key: const Key('tab_materials_view'),
            query: query,
          ),

          // ── Tab 3: Incidents History ─────────────────────────────
          _IncidentsTab(
            key: const Key('tab_incidents_view'),
            query: query,
          ),
        ],
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Attendance History Component
// ---------------------------------------------------------------------------

class _AttendanceTab extends ConsumerWidget {
  final String siteId;
  final _SiteDetailQuery query;

  const _AttendanceTab({
    super.key,
    required this.siteId,
    required this.query,
  });

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(_siteDetailAttendanceProvider(query));
    final workersAsync = ref.watch(_siteDetailWorkersProvider(siteId));

    return attendanceAsync.when(
      loading: () => const LoadingView(message: 'Loading attendance history…'),
      error: (e, _) => ErrorView(
        message: 'Failed to load attendance: $e',
        onRetry: () => ref.invalidate(_siteDetailAttendanceProvider(query)),
      ),
      data: (records) {
        if (records.isEmpty) {
          return const EmptyView(
            message: 'No attendance records found for this period.',
          );
        }

        final workers = workersAsync.value ?? [];
        final workerMap = {for (final w in workers) w.id: w};

        // Group by day
        final byDay = <String, List<AttendanceEntry>>{};
        for (final r in records) {
          final key = '${r.date.year}-${r.date.month}-${r.date.day}';
          byDay.putIfAbsent(key, () => []).add(r);
        }

        final sortedDays = byDay.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDays.length,
          itemBuilder: (context, index) {
            final dayKey = sortedDays[index];
            final dayRecords = byDay[dayKey]!;
            final date = dayRecords.first.date;

            final present =
                dayRecords.where((r) => r.status == AttendanceStatus.present).length;
            final half =
                dayRecords.where((r) => r.status == AttendanceStatus.half).length;
            final absent =
                dayRecords.where((r) => r.status == AttendanceStatus.absent).length;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                key: Key('attendance_day_$dayKey'),
                title: Text(
                  _formatDate(date),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Present: $present  •  Half: $half  •  Absent: $absent',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                children: dayRecords.map((r) {
                  final worker = workerMap[r.workerId];
                  final name = worker?.name ?? r.workerId;
                  final trade = worker?.trade ?? 'Worker';

                  Color statusColor = AppColors.success;
                  if (r.status == AttendanceStatus.half) {
                    statusColor = AppColors.warning;
                  } else if (r.status == AttendanceStatus.absent) {
                    statusColor = AppColors.critical;
                  }

                  return ListTile(
                    dense: true,
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(trade),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r.status.name.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SyncChip(pending: r.hasPendingWrites),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Materials Component
// ---------------------------------------------------------------------------

class _MaterialsTab extends ConsumerWidget {
  final _SiteDetailQuery query;

  const _MaterialsTab({
    super.key,
    required this.query,
  });

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(_siteDetailMaterialsProvider);
    final logsAsync = ref.watch(_siteDetailMaterialLogsProvider(query));

    return materialsAsync.when(
      loading: () => const LoadingView(message: 'Loading materials…'),
      error: (e, _) => ErrorView(
        message: 'Failed to load materials: $e',
        onRetry: () => ref.invalidate(_siteDetailMaterialsProvider),
      ),
      data: (materials) {
        if (materials.isEmpty) {
          return const EmptyView(message: 'No materials found.');
        }

        final materialMap = {for (final m in materials) m.id: m};
        final logs = logsAsync.value ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Stock Status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              // Materials Grid/List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: materials.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final m = materials[index];
                  final isLow = isLowStock(m);

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isLow ? Colors.orange.shade300 : Colors.grey.shade200,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory_2,
                            color: isLow ? Colors.orange.shade800 : AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Current: ${m.currentStock.toStringAsFixed(1)} ${m.unit}  •  Threshold: ${m.lowStockThreshold.toStringAsFixed(0)} ${m.unit}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isLow ? Colors.orange.shade900 : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isLow)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'LOW STOCK',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'NORMAL',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              const Divider(thickness: 4),
              const SizedBox(height: 16),

              Text(
                'Recent Material Usage Logs',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              if (logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text('No material usage logged in this date range.'),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length > 20 ? 20 : logs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final mat = materialMap[log.materialId];
                    final unit = mat?.unit ?? 'units';
                    final name = mat?.name ?? log.materialId;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.orange.shade50,
                        child: Icon(Icons.remove, color: Colors.orange.shade900, size: 18),
                      ),
                      title: Text(
                        '−${log.qtyUsed.toStringAsFixed(1)} $unit  ($name)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Remaining: ${log.remainingAfter.toStringAsFixed(1)} $unit  •  ${_formatDate(log.date)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: SyncChip(pending: log.hasPendingWrites),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Incidents Component
// ---------------------------------------------------------------------------

class _IncidentsTab extends ConsumerWidget {
  final _SiteDetailQuery query;

  const _IncidentsTab({
    super.key,
    required this.query,
  });

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color _severityColor(Severity s) {
    switch (s) {
      case Severity.minor:
        return AppColors.success;
      case Severity.moderate:
        return AppColors.warning;
      case Severity.high:
        return const Color(0xFFD32F2F);
      case Severity.critical:
        return AppColors.critical;
    }
  }

  IconData _severityIcon(Severity s) {
    switch (s) {
      case Severity.minor:
        return Icons.info_outline;
      case Severity.moderate:
        return Icons.warning_amber_rounded;
      case Severity.high:
        return Icons.report_problem_outlined;
      case Severity.critical:
        return Icons.dangerous_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentsAsync = ref.watch(_siteDetailIncidentsProvider(query));

    return incidentsAsync.when(
      loading: () => const LoadingView(message: 'Loading incidents…'),
      error: (e, _) => ErrorView(
        message: 'Failed to load incidents: $e',
        onRetry: () => ref.invalidate(_siteDetailIncidentsProvider(query)),
      ),
      data: (incidents) {
        if (incidents.isEmpty) {
          return const EmptyView(
            message: 'No safety incidents reported for this site.',
          );
        }

        final sorted = incidents.toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sorted.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final inc = sorted[index];
            final color = _severityColor(inc.severity);
            final icon = _severityIcon(inc.severity);
            final isEscalated = isHighSeverity(inc.severity);

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: color.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            inc.severity.name.toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (isEscalated) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ESCALATED',
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          _formatDate(inc.occurredAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SyncChip(pending: inc.hasPendingWrites),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      inc.description,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
