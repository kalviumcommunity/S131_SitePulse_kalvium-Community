import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/core/constants/thresholds.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/core/widgets/offline_banner.dart';
import 'package:site_pulse/core/widgets/severity_selector.dart';
import 'package:site_pulse/core/widgets/status_views.dart';
import 'package:site_pulse/core/widgets/sync_chip.dart';
import 'package:site_pulse/data/models/incident.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _supervisorIncidentsProvider = StreamProvider.autoDispose
    .family<List<Incident>, String>((ref, siteId) {
      final repo = ref.watch(incidentRepositoryProvider);
      return repo.watchIncidents(siteId: siteId);
    });

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class IncidentScreen extends ConsumerStatefulWidget {
  const IncidentScreen({super.key});

  @override
  ConsumerState<IncidentScreen> createState() => _IncidentScreenState();
}

class _IncidentScreenState extends ConsumerState<IncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  Severity _selectedSeverity = Severity.minor;
  StreamSubscription<dynamic>? _errorSub;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() {
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _errorSub = ref.read(incidentRepositoryProvider).errorStream.listen((
        err,
      ) {
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
    _descriptionController.dispose();
    _errorSub?.cancel();
    super.dispose();
  }

  bool get _isValid => _descriptionController.text.trim().length >= 10;

  void _confirmAndSubmit(String siteId) {
    if (!_isValid) return;

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('incident_confirm_dialog'),
        title: const Text('Submit Incident Report?'),
        content: const Text('This record cannot be edited after submitting.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_submit_button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Submit Report'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        _submitReport(siteId);
      }
    });
  }

  void _submitReport(String siteId) {
    final repo = ref.read(incidentRepositoryProvider);
    final incident = Incident(
      id: const Uuid().v4(),
      severity: _selectedSeverity,
      description: _descriptionController.text.trim(),
      occurredAt: DateTime.now(),
      siteId: siteId,
    );

    repo.reportIncident(incident); // fire-and-forget ✅

    _descriptionController.clear();
    setState(() => _selectedSeverity = Severity.minor);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved on this device'),
        duration: Duration(seconds: 2),
      ),
    );
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
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final siteId = user?.siteId;

    if (siteId == null || siteId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Safety Incidents'),
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

    final incidentsAsync = ref.watch(_supervisorIncidentsProvider(siteId));
    final isEscalated = isHighSeverity(_selectedSeverity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Incidents'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: OfflineBanner(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── High / Critical Escalation Warning Banner ──────────
            if (isEscalated)
              Container(
                key: const Key('escalation_banner'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: Colors.red.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppColors.critical),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'High and critical incidents are flagged on the project manager\'s dashboard after sync.',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Incident Input Form ────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report New Safety Incident',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Severity Level',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SeveritySelector(
                      value: _selectedSeverity,
                      onChanged: (s) => setState(() => _selectedSeverity = s),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('incident_description_field'),
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Describe what occurred, hazards, and actions taken (min 10 characters)...',
                        border: const OutlineInputBorder(),
                        helperText:
                            '${_descriptionController.text.trim().length} / 10 min characters',
                        helperStyle: TextStyle(
                          color: _isValid
                              ? AppColors.success
                              : Colors.grey.shade600,
                          fontWeight: _isValid
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        key: const Key('submit_incident_button'),
                        icon: const Icon(Icons.send),
                        label: const Text('Submit Incident Report'),
                        onPressed: _isValid
                            ? () => _confirmAndSubmit(siteId)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(thickness: 8, height: 24),

            // ── Recent Incidents Feed (Read-Only) ──────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Recent Incident Reports',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),

            incidentsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32.0),
                child: LoadingView(message: 'Loading incidents…'),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: ErrorView(
                  message: 'Failed to load incidents: $e',
                  onRetry: () =>
                      ref.invalidate(_supervisorIncidentsProvider(siteId)),
                ),
              ),
              data: (incidents) {
                if (incidents.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: EmptyView(
                      message: 'No safety incidents reported for this site.',
                    ),
                  );
                }

                final sorted = incidents.toList()
                  ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final inc = sorted[index];
                    final color = _severityColor(inc.severity);
                    final icon = _severityIcon(inc.severity);

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
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
                                const Spacer(),
                                Text(
                                  _formatDate(inc.occurredAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SyncChip(pending: inc.hasPendingWrites),
                              ],
                            ),
                            const SizedBox(height: 8),
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
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
