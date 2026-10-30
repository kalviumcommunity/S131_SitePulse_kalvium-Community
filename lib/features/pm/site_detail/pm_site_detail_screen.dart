import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/core/constants/thresholds.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/core/utils/date_ranges.dart';
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

final _siteDetailProvider = StreamProvider.autoDispose.family<Site?, String>((
  ref,
  siteId,
) {
  return ref.watch(siteRepositoryProvider).watchSite(siteId);
});

final _siteDetailWorkersProvider = StreamProvider.autoDispose
    .family<List<Worker>, String>((ref, siteId) {
      return ref.watch(workerRepositoryProvider).watchWorkers(siteId);
    });

final _siteDetailAttendanceProvider = StreamProvider.autoDispose
    .family<List<AttendanceEntry>, _SiteDetailQuery>((ref, query) {
      return ref
          .watch(attendanceRepositoryProvider)
          .watchAttendance(
            siteId: query.siteId,
            startDate: query.range.start,
            endDate: query.range.end,
          );
    });

final _siteDetailMaterialsProvider = StreamProvider.autoDispose
    .family<List<sp.Material>, String>((ref, siteId) {
      return ref
          .watch(materialRepositoryProvider)
          .watchMaterials(siteId: siteId);
    });

final _siteDetailMaterialLogsProvider = StreamProvider.autoDispose
    .family<List<MaterialLog>, _SiteDetailQuery>((ref, query) {
      return ref
          .watch(materialRepositoryProvider)
          .watchMaterialLogs(
            siteId: query.siteId,
            startDate: query.range.start,
            endDate: query.range.end,
          );
    });

final _siteDetailIncidentsProvider = StreamProvider.autoDispose
    .family<List<Incident>, _SiteDetailQuery>((ref, query) {
      return ref
          .watch(incidentRepositoryProvider)
          .watchIncidents(
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

enum _AttendanceRange { week, month }

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
{
  int _selectedTabIndex = 0;
  _AttendanceRange? _attendanceRange = _AttendanceRange.week;
  late DateTimeRange _dateRange;

  @override
  void initState() {
    super.initState();
    _dateRange = lastSevenDays();
  }

  String _formatRangeLabel(DateTimeRange r) {
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
          start: DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          ),
          end: DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          ),
        );
        _attendanceRange = null;
      });
    }
  }

  void _selectAttendanceRange(_AttendanceRange range) {
    setState(() {
      _attendanceRange = range;
      _dateRange = switch (range) {
        _AttendanceRange.week => lastSevenDays(),
        _AttendanceRange.month => lastThirtyDays(),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final siteAsync = ref.watch(_siteDetailProvider(widget.siteId));
    final query = _SiteDetailQuery(widget.siteId, _dateRange);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('pm_site_back'),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
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
      ),
      body: AppPageBackground(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  _AttendanceTab(
                    key: const Key('tab_attendance_view'),
                    siteId: widget.siteId,
                    query: query,
                    selectedRange: _attendanceRange,
                    onRangeChanged: _selectAttendanceRange,
                  ),
                  _MaterialsTab(
                    key: const Key('tab_materials_view'),
                    query: query,
                  ),
                  _IncidentsTab(
                    key: const Key('tab_incidents_view'),
                    query: query,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedTabIndex = index);
        },
        destinations: const [
          NavigationDestination(
            key: Key('tab_attendance'),
            icon: Icon(Icons.how_to_reg),
            label: 'Attendance',
          ),
          NavigationDestination(
            key: Key('tab_materials'),
            icon: Icon(Icons.inventory_2),
            label: 'Materials',
          ),
          NavigationDestination(
            key: Key('tab_incidents'),
            icon: Icon(Icons.warning_amber),
            label: 'Incidents',
          ),
        ],
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
  final _AttendanceRange? selectedRange;
  final ValueChanged<_AttendanceRange> onRangeChanged;

  const _AttendanceTab({
    super.key,
    required this.siteId,
    required this.query,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  String _formatDate(DateTime d) {
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
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(_siteDetailAttendanceProvider(query));
    final workersAsync = ref.watch(_siteDetailWorkersProvider(siteId));

    Future<void> refresh() async {
      ref.invalidate(_siteDetailAttendanceProvider(query));
      ref.invalidate(_siteDetailWorkersProvider(siteId));
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    final range = selectedRange;
    final selected = range == null
        ? <_AttendanceRange>{}
        : <_AttendanceRange>{range};

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_AttendanceRange>(
            key: const Key('attendance_range_toggle'),
            segments: const [
              ButtonSegment(
                value: _AttendanceRange.week,
                label: Text('Week'),
              ),
              ButtonSegment(
                value: _AttendanceRange.month,
                label: Text('Month'),
              ),
            ],
            selected: selected,
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) onRangeChanged(selection.first);
            },
          ),
          const SizedBox(height: 16),
          attendanceAsync.when(
            loading: () => const SizedBox(
              height: 240,
              child: Center(
                child: LoadingView(message: 'Loading attendance history…'),
              ),
            ),
            error: (error, _) => ErrorView(
              message: 'Failed to load attendance: $error',
              onRetry: () =>
                  ref.invalidate(_siteDetailAttendanceProvider(query)),
            ),
            data: (records) {
              if (records.isEmpty) {
                return const SizedBox(
                  height: 240,
                  child: Center(
                    child: EmptyView(
                      message:
                          'No attendance records found for this period.',
                    ),
                  ),
                );
              }
              return _AttendanceHistory(
                records: records,
                workers: workersAsync.value ?? const [],
                range: query.range,
                formatDate: _formatDate,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AttendanceHistory extends StatelessWidget {
  const _AttendanceHistory({
    required this.records,
    required this.workers,
    required this.range,
    required this.formatDate,
  });

  final List<AttendanceEntry> records;
  final List<Worker> workers;
  final DateTimeRange range;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final recordsByDay = <String, List<AttendanceEntry>>{};
    for (final record in records) {
      final dayKey = AttendanceEntry.dateKeyFromDate(record.date);
      recordsByDay.putIfAbsent(dayKey, () => []).add(record);
    }

    final dates = <DateTime>[];
    for (
      var date = DateTime(range.start.year, range.start.month, range.start.day);
      !date.isAfter(range.end);
      date = date.add(const Duration(days: 1))
    ) {
      dates.add(date);
    }

    final workerMap = {for (final worker in workers) worker.id: worker};
    final recordedDays = recordsByDay.keys.toList()
      ..sort((first, second) => second.compareTo(first));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AttendanceChart(dates: dates, recordsByDay: recordsByDay),
        const SizedBox(height: 16),
        for (final dayKey in recordedDays)
          _AttendanceDayCard(
            dayKey: dayKey,
            records: recordsByDay[dayKey]!,
            workerMap: workerMap,
            formatDate: formatDate,
          ),
      ],
    );
  }
}

class _AttendanceDayCard extends StatelessWidget {
  const _AttendanceDayCard({
    required this.dayKey,
    required this.records,
    required this.workerMap,
    required this.formatDate,
  });

  final String dayKey;
  final List<AttendanceEntry> records;
  final Map<String, Worker> workerMap;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final present = records
        .where((record) => record.status == AttendanceStatus.present)
        .length;
    final half = records
        .where((record) => record.status == AttendanceStatus.half)
        .length;
    final absent = records
        .where((record) => record.status == AttendanceStatus.absent)
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        key: Key('attendance_day_$dayKey'),
        title: Text(
          formatDate(records.first.date),
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
        children: records.map((record) {
          final worker = workerMap[record.workerId];
          final color = switch (record.status) {
            AttendanceStatus.present => AppColors.success,
            AttendanceStatus.half => AppColors.warning,
            AttendanceStatus.absent => AppColors.critical,
          };

          return ListTile(
            dense: true,
            title: Text(
              worker?.name ?? record.workerId,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(worker?.trade ?? 'Worker'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    record.status.name.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SyncChip(pending: record.hasPendingWrites),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AttendanceChart extends StatelessWidget {
  const _AttendanceChart({
    required this.dates,
    required this.recordsByDay,
  });

  final List<DateTime> dates;
  final Map<String, List<AttendanceEntry>> recordsByDay;

  @override
  Widget build(BuildContext context) {
    final dailyCounts = [
      for (final date in dates)
        _AttendanceCounts.fromRecords(
          recordsByDay[AttendanceEntry.dateKeyFromDate(date)] ?? const [],
        ),
    ];
    final maxCount = dailyCounts.fold<int>(
      0,
      (maximum, counts) => counts.total > maximum ? counts.total : maximum,
    );

    return Card(
      key: const Key('attendance_chart'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 142,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < dates.length; index++)
                    Expanded(
                      child: _AttendanceBar(
                        date: dates[index],
                        counts: dailyCounts[index],
                        maxCount: maxCount,
                        showDateLabel:
                            dates.length <= 7 || index % 5 == 0,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                _AttendanceLegend(color: AppColors.success, label: 'Present'),
                _AttendanceLegend(color: AppColors.warning, label: 'Half-day'),
                _AttendanceLegend(color: AppColors.critical, label: 'Absent'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceCounts {
  const _AttendanceCounts({
    required this.present,
    required this.half,
    required this.absent,
  });

  factory _AttendanceCounts.fromRecords(List<AttendanceEntry> records) {
    return _AttendanceCounts(
      present: records
          .where((record) => record.status == AttendanceStatus.present)
          .length,
      half: records
          .where((record) => record.status == AttendanceStatus.half)
          .length,
      absent: records
          .where((record) => record.status == AttendanceStatus.absent)
          .length,
    );
  }

  final int present;
  final int half;
  final int absent;
  int get total => present + half + absent;
}

class _AttendanceBar extends StatelessWidget {
  const _AttendanceBar({
    required this.date,
    required this.counts,
    required this.maxCount,
    required this.showDateLabel,
  });

  final DateTime date;
  final _AttendanceCounts counts;
  final int maxCount;
  final bool showDateLabel;

  @override
  Widget build(BuildContext context) {
    final dayKey = AttendanceEntry.dateKeyFromDate(date);
    final barHeight = counts.total == 0 || maxCount == 0
        ? 3.0
        : 104 * counts.total / maxCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Tooltip(
                message: '${counts.total} attendance records',
                child: Container(
                  key: Key('attendance_chart_bar_$dayKey'),
                  width: double.infinity,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: counts.total == 0 ? AppColors.surfaceContainer : null,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: counts.total == 0
                      ? null
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Column(
                            children: [
                              if (counts.present > 0)
                                Expanded(
                                  flex: counts.present,
                                  child: ColoredBox(color: AppColors.success),
                                ),
                              if (counts.half > 0)
                                Expanded(
                                  flex: counts.half,
                                  child: ColoredBox(color: AppColors.warning),
                                ),
                              if (counts.absent > 0)
                                Expanded(
                                  flex: counts.absent,
                                  child: ColoredBox(color: AppColors.critical),
                                ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 22,
            child: showDateLabel
                ? Center(
                    child: Text(
                      '${date.day}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _AttendanceLegend extends StatelessWidget {
  const _AttendanceLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Materials Component
// ---------------------------------------------------------------------------

class _MaterialsTab extends ConsumerWidget {
  final _SiteDetailQuery query;

  const _MaterialsTab({super.key, required this.query});

  String _formatDate(DateTime d) {
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
    final materialsAsync = ref.watch(
      _siteDetailMaterialsProvider(query.siteId),
    );
    final logsAsync = ref.watch(_siteDetailMaterialLogsProvider(query));

    Future<void> refresh() async {
      ref.invalidate(_siteDetailMaterialsProvider(query.siteId));
      ref.invalidate(_siteDetailMaterialLogsProvider(query));
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    return materialsAsync.when(
      loading: () => _refreshableStatus(
        context,
        const LoadingView(message: 'Loading materials…'),
        refresh,
      ),
      error: (e, _) => _refreshableStatus(
        context,
        ErrorView(
          message: 'Failed to load materials: $e',
          onRetry: () =>
              ref.invalidate(_siteDetailMaterialsProvider(query.siteId)),
        ),
        refresh,
      ),
      data: (materials) {
        if (materials.isEmpty) {
          return _refreshableStatus(
            context,
            const EmptyView(message: 'No materials found.'),
            refresh,
          );
        }

        final materialMap = {for (final m in materials) m.id: m};
        return RefreshIndicator(
          onRefresh: refresh,
          child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Stock Status',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
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
                        color: isLow
                            ? Colors.orange.shade300
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory_2,
                            color: isLow
                                ? Colors.orange.shade800
                                : AppColors.primary,
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
                                    color: isLow
                                        ? Colors.orange.shade900
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isLow)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
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
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              logsAsync.when(
                loading: () =>
                    const LoadingView(message: 'Loading material logs…'),
                error: (error, _) => ErrorView(
                  message: 'Failed to load material logs: $error',
                  onRetry: () =>
                      ref.invalidate(_siteDetailMaterialLogsProvider(query)),
                ),
                data: (logs) => logs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          'No material usage logged in this date range.',
                        ),
                      )
                    : ListView.separated(
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
                              child: Icon(
                                Icons.remove,
                                color: Colors.orange.shade900,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              '−${log.qtyUsed.toStringAsFixed(1)} $unit  ($name)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Remaining: ${log.remainingAfter.toStringAsFixed(1)} $unit  •  ${_formatDate(log.date)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: SyncChip(pending: log.hasPendingWrites),
                          );
                        },
                      ),
              ),
            ],
          ),
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

  const _IncidentsTab({super.key, required this.query});

  String _formatDate(DateTime d) {
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

    Future<void> refresh() async {
      ref.invalidate(_siteDetailIncidentsProvider(query));
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    return incidentsAsync.when(
      loading: () => _refreshableStatus(
        context,
        const LoadingView(message: 'Loading incidents…'),
        refresh,
      ),
      error: (e, _) => _refreshableStatus(
        context,
        ErrorView(
          message: 'Failed to load incidents: $e',
          onRetry: () => ref.invalidate(_siteDetailIncidentsProvider(query)),
        ),
        refresh,
      ),
      data: (incidents) {
        if (incidents.isEmpty) {
          return _refreshableStatus(
            context,
            const EmptyView(
              message: 'No safety incidents reported for this site.',
            ),
            refresh,
          );
        }

        final sorted = incidents.toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
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
                    Text(inc.description, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            );
          },
          ),
        );
      },
    );
  }
}

Widget _refreshableStatus(
  BuildContext context,
  Widget status,
  Future<void> Function() onRefresh,
) {
  return RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Center(child: status),
        ),
      ],
    ),
  );
}
