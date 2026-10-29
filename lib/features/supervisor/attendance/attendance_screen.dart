import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/core/widgets/app_page_background.dart';
import 'package:site_pulse/core/widgets/attendance_toggle.dart';
import 'package:site_pulse/core/widgets/offline_banner.dart';
import 'package:site_pulse/core/widgets/status_views.dart';
import 'package:site_pulse/core/widgets/sync_chip.dart';
import 'package:site_pulse/data/models/attendance_entry.dart';
import 'package:site_pulse/data/models/worker.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/data/repositories/attendance_repository.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Workers stream for the supervisor's site.
final _attendanceWorkersProvider = StreamProvider.autoDispose
    .family<List<Worker>, String>((ref, siteId) {
      final repo = ref.watch(workerRepositoryProvider);
      return repo.watchWorkers(siteId);
    });

/// Existing attendance stream for a given site + date.
final _existingAttendanceProvider = StreamProvider.autoDispose
    .family<List<AttendanceEntry>, _AttendanceKey>((ref, key) {
      final repo = ref.watch(attendanceRepositoryProvider);
      return repo.watchAttendance(siteId: key.siteId, date: key.date);
    });

class _AttendanceKey {
  final String siteId;
  final DateTime date;
  const _AttendanceKey(this.siteId, this.date);

  @override
  bool operator ==(Object other) =>
      other is _AttendanceKey &&
      siteId == other.siteId &&
      date.year == other.date.year &&
      date.month == other.date.month &&
      date.day == other.date.day;

  @override
  int get hashCode => Object.hash(siteId, date.year, date.month, date.day);
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime _selectedDate = _today();
  // workerId → status (local overrides before save)
  final Map<String, AttendanceStatus> _statusMap = {};

  StreamSubscription<dynamic>? _errorSub;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    // Listen to write errors from attendance repository
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repo = ref.read(attendanceRepositoryProvider);
      _errorSub = repo.errorStream.listen((err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: ${err.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Date helpers
  // -------------------------------------------------------------------------

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: _today(),
      helpText: 'Select Attendance Date',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _statusMap.clear(); // reset local overrides when date changes
      });
    }
  }

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
    final today = _today();
    final isToday =
        d.year == today.year && d.month == today.month && d.day == today.day;
    final label = '${d.day} ${months[d.month - 1]} ${d.year}';
    return isToday ? 'Today — $label' : label;
  }

  // -------------------------------------------------------------------------
  // Merge existing records with local overrides
  // -------------------------------------------------------------------------

  AttendanceStatus _effectiveStatus(
    String workerId,
    List<AttendanceEntry> existing,
  ) {
    if (_statusMap.containsKey(workerId)) return _statusMap[workerId]!;
    final entry = existing.where((e) => e.workerId == workerId).firstOrNull;
    return entry?.status ?? AttendanceStatus.present;
  }

  bool _hasPending(String workerId, List<AttendanceEntry> existing) {
    if (_statusMap.containsKey(workerId)) return true; // unsaved local change
    final entry = existing.where((e) => e.workerId == workerId).firstOrNull;
    return entry?.hasPendingWrites ?? false;
  }

  // -------------------------------------------------------------------------
  // Save (fire-and-forget bulk write)
  // -------------------------------------------------------------------------

  void _saveAttendance({
    required String siteId,
    required List<Worker> workers,
    required List<AttendanceEntry> existing,
    required AttendanceRepository repo,
  }) {
    final entries = workers.map((w) {
      final status = _effectiveStatus(w.id, existing);
      final id = AttendanceEntry.buildId(
        siteId: siteId,
        workerId: w.id,
        date: _selectedDate,
      );
      return AttendanceEntry(
        id: id,
        workerId: w.id,
        date: _selectedDate,
        status: status,
        siteId: siteId,
      );
    }).toList();

    repo.recordBulkAttendance(entries); // fire-and-forget ✅

    // Clear local overrides — stream will reflect saved state
    setState(() => _statusMap.clear());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved on this device'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.watch(authRepositoryProvider);
    final user = authRepo.currentUser;
    final siteId = user?.siteId;

    if (siteId == null || siteId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Attendance'),
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

    final workersAsync = ref.watch(_attendanceWorkersProvider(siteId));
    final existingAsync = ref.watch(
      _existingAttendanceProvider(_AttendanceKey(siteId, _selectedDate)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: OfflineBanner(),
        ),
      ),
      body: AppPageBackground(
        child: workersAsync.when(
        loading: () => const LoadingView(message: 'Loading workers…'),
        error: (e, _) => ErrorView(
          message: 'Failed to load workers: $e',
          onRetry: () => ref.invalidate(_attendanceWorkersProvider(siteId)),
        ),
        data: (workers) {
          if (workers.isEmpty) {
            return const EmptyView(
              message: 'No active workers on this site.\nAdd workers in the Roster screen.',
            );
          }
          return existingAsync.when(
            loading: () => const LoadingView(message: 'Loading attendance…'),
            error: (e, _) => ErrorView(
              message: 'Failed to load attendance: $e',
              onRetry: () => ref.invalidate(
                _existingAttendanceProvider(
                  _AttendanceKey(siteId, _selectedDate),
                ),
              ),
            ),
            data: (existing) => _buildBody(context, siteId, workers, existing),
          );
        },
      ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    String siteId,
    List<Worker> workers,
    List<AttendanceEntry> existing,
  ) {
    final repo = ref.read(attendanceRepositoryProvider);

    // Live counters
    int present = 0, half = 0, absent = 0;
    for (final w in workers) {
      final s = _effectiveStatus(w.id, existing);
      if (s == AttendanceStatus.present) {
        present++;
      } else if (s == AttendanceStatus.half) {
        half++;
      } else {
        absent++;
      }
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // ── Date selector ──────────────────────────────────────────────
        InkWell(
          key: const Key('date_picker_button'),
          onTap: () => _pickDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(_selectedDate),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_drop_down, color: colorScheme.primary),
              ],
            ),
          ),
        ),

        // ── Summary counters ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _CounterChip(
                key: const Key('counter_present'),
                label: 'Present',
                count: present,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 8),
              _CounterChip(
                key: const Key('counter_half'),
                label: 'Half',
                count: half,
                color: Colors.orange.shade600,
              ),
              const SizedBox(width: 8),
              _CounterChip(
                key: const Key('counter_absent'),
                label: 'Absent',
                count: absent,
                color: Colors.red.shade600,
              ),
              const Spacer(),
              Text(
                '${workers.length} workers',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Worker list ────────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: workers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final worker = workers[index];
              final status = _effectiveStatus(worker.id, existing);
              final pending = _hasPending(worker.id, existing);
              return _WorkerAttendanceTile(
                worker: worker,
                status: status,
                hasPendingWrites: pending,
                onChanged: (newStatus) {
                  setState(() => _statusMap[worker.id] = newStatus);
                },
              );
            },
          ),
        ),

        // ── Save button ────────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                key: const Key('save_attendance_button'),
                icon: const Icon(Icons.save_alt),
                label: const Text('Save Attendance'),
                onPressed: () => _saveAttendance(
                  siteId: siteId,
                  workers: workers,
                  existing: existing,
                  repo: repo,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Worker attendance tile
// ---------------------------------------------------------------------------

class _WorkerAttendanceTile extends StatelessWidget {
  final Worker worker;
  final AttendanceStatus status;
  final bool hasPendingWrites;
  final ValueChanged<AttendanceStatus> onChanged;

  const _WorkerAttendanceTile({
    required this.worker,
    required this.status,
    required this.hasPendingWrites,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${worker.workerCode}  •  ${worker.trade}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SyncChip(
                key: Key('sync_chip_${worker.id}'),
                pending: hasPendingWrites,
              ),
            ],
          ),
          const SizedBox(height: 8),
          AttendanceToggle(
            key: Key('attendance_toggle_${worker.id}'),
            value: status,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Counter chip
// ---------------------------------------------------------------------------

class _CounterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CounterChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
