import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/core/constants/thresholds.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/core/widgets/app_page_background.dart';
import 'package:site_pulse/core/widgets/offline_banner.dart';
import 'package:site_pulse/core/widgets/quantity_stepper.dart';
import 'package:site_pulse/core/widgets/status_views.dart';
import 'package:site_pulse/core/widgets/sync_chip.dart';
import 'package:site_pulse/data/models/material.dart' as sp;
import 'package:site_pulse/data/models/material_log.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _materialsProvider =
    StreamProvider.autoDispose<List<sp.Material>>((ref) {
  return ref.watch(materialRepositoryProvider).watchMaterials();
});

final _materialLogsProvider =
    StreamProvider.autoDispose<List<MaterialLog>>((ref) {
  return ref.watch(materialRepositoryProvider).watchMaterialLogs();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MaterialUsageScreen extends ConsumerStatefulWidget {
  const MaterialUsageScreen({super.key});

  @override
  ConsumerState<MaterialUsageScreen> createState() =>
      _MaterialUsageScreenState();
}

class _MaterialUsageScreenState extends ConsumerState<MaterialUsageScreen> {
  String? _selectedMaterialId;
  double _qty = 1.0;
  StreamSubscription<dynamic>? _errorSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _errorSub =
          ref.read(materialRepositoryProvider).errorStream.listen((err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: ${(err as dynamic).message}'),
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

  void _logUsage(sp.Material material) {
    final repo = ref.read(materialRepositoryProvider);
    final logId = const Uuid().v4();
    repo.logUsage(
      materialId: material.id,
      qtyUsed: _qty,
      date: DateTime.now(),
      logId: logId,
    ); // fire-and-forget ✅
    setState(() => _qty = 1.0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved on this device'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(_materialsProvider);
    final logsAsync = ref.watch(_materialLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material Usage'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: OfflineBanner(),
        ),
      ),
      body: AppPageBackground(
        child: materialsAsync.when(
        loading: () => const LoadingView(message: 'Loading materials…'),
        error: (e, _) => ErrorView(
          message: 'Failed to load materials: $e',
          onRetry: () => ref.invalidate(_materialsProvider),
        ),
        data: (materials) {
          if (materials.isEmpty) {
            return const EmptyView(
              message: 'No materials found for this site.',
            );
          }

          // Default selection
          if (_selectedMaterialId == null ||
              !materials.any((m) => m.id == _selectedMaterialId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _selectedMaterialId = materials.first.id);
              }
            });
          }

          final selected = materials.firstWhere(
            (m) => m.id == _selectedMaterialId,
            orElse: () => materials.first,
          );

          final projectedRemaining = (selected.currentStock - _qty)
              .clamp(0.0, selected.currentStock);
          final lowStock = isLowStock(selected);
          final willBeLowest =
              projectedRemaining <= selected.lowStockThreshold;

          return logsAsync.when(
            loading: () => const LoadingView(message: 'Loading logs…'),
            error: (e, _) => ErrorView(
              message: 'Failed to load logs: $e',
              onRetry: () => ref.invalidate(_materialLogsProvider),
            ),
            data: (allLogs) {
              final recentLogs = allLogs
                  .where((l) => l.materialId == selected.id)
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              return Column(
                children: [
                  // ── Low-stock alert ─────────────────────────────────
                  if (lowStock)
                    _LowStockBanner(
                      materialName: selected.name,
                      current: selected.currentStock,
                      threshold: selected.lowStockThreshold,
                      unit: selected.unit,
                    ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Material dropdown ────────────────────────
                          _SectionLabel(label: 'Select Material'),
                          const SizedBox(height: 8),
                          InputDecorator(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                key: const Key('material_dropdown'),
                                isExpanded: true,
                                value: selected.id,
                                items: materials
                                    .map(
                                      (m) => DropdownMenuItem(
                                        value: m.id,
                                        child: Row(
                                          children: [
                                            Text(m.name),
                                            const Spacer(),
                                            if (isLowStock(m))
                                              const Icon(Icons.warning_amber,
                                                  size: 16,
                                                  color: Colors.orange),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (id) {
                                  if (id != null) {
                                    setState(() {
                                      _selectedMaterialId = id;
                                      _qty = 1.0;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Stock preview card ───────────────────────
                          _StockPreviewCard(
                            current: selected.currentStock,
                            projected: projectedRemaining,
                            unit: selected.unit,
                            willBeLowest: willBeLowest,
                            pending: selected.hasPendingWrites,
                          ),

                          const SizedBox(height: 20),

                          // ── Quantity stepper ─────────────────────────
                          _SectionLabel(label: 'Quantity Used'),
                          const SizedBox(height: 8),
                          Center(
                            child: QuantityStepper(
                              key: const Key('quantity_stepper'),
                              value: _qty,
                              min: 1.0,
                              max: selected.currentStock.clamp(1.0, 9999.0),
                              unit: selected.unit,
                              onChanged: (v) => setState(() => _qty = v),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Log Usage button ─────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              key: const Key('log_usage_button'),
                              icon: const Icon(Icons.add_task),
                              label: const Text('Log Usage'),
                              onPressed: selected.currentStock > 0
                                  ? () => _logUsage(selected)
                                  : null,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Recent logs ──────────────────────────────
                          _SectionLabel(
                            label: 'Recent Logs — ${selected.name}',
                          ),
                          const SizedBox(height: 8),

                          if (recentLogs.isEmpty)
                            const EmptyView(
                              message: 'No usage logged yet for this material.',
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  recentLogs.length > 10 ? 10 : recentLogs.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final log = recentLogs[index];
                                return _LogTile(
                                  log: log,
                                  unit: selected.unit,
                                  formatDate: _formatDate,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Low stock banner
// ---------------------------------------------------------------------------

class _LowStockBanner extends StatelessWidget {
  final String materialName;
  final double current;
  final double threshold;
  final String unit;

  const _LowStockBanner({
    required this.materialName,
    required this.current,
    required this.threshold,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('low_stock_banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.orange.shade100,
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.deepOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Low Stock: $materialName — ${current.toStringAsFixed(0)} $unit remaining '
              '(threshold: ${threshold.toStringAsFixed(0)} $unit)',
              style: const TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stock preview card
// ---------------------------------------------------------------------------

class _StockPreviewCard extends StatelessWidget {
  final double current;
  final double projected;
  final String unit;
  final bool willBeLowest;
  final bool pending;

  const _StockPreviewCard({
    required this.current,
    required this.projected,
    required this.unit,
    required this.willBeLowest,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Stock Preview',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                SyncChip(pending: pending),
              ],
            ),
            const SizedBox(height: 12),
            _StockRow(
              key: const Key('current_stock_label'),
              label: 'Current',
              value: '${current.toStringAsFixed(1)} $unit',
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 6),
            _StockRow(
              key: const Key('projected_stock_label'),
              label: 'After this log',
              value: '${projected.toStringAsFixed(1)} $unit',
              color: willBeLowest ? Colors.deepOrange : Colors.green.shade600,
            ),
            if (willBeLowest) ...[
              const SizedBox(height: 8),
              Text(
                '⚠ Stock will be at or below threshold after logging.',
                style: TextStyle(
                    color: Colors.deepOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StockRow({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            )),
        const Spacer(),
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Log tile
// ---------------------------------------------------------------------------

class _LogTile extends StatelessWidget {
  final MaterialLog log;
  final String unit;
  final String Function(DateTime) formatDate;

  const _LogTile({
    required this.log,
    required this.unit,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child:
            Icon(Icons.inventory_2, color: theme.colorScheme.onSecondaryContainer),
      ),
      title: Text(
        '−${log.qtyUsed.toStringAsFixed(1)} $unit',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Remaining after: ${log.remainingAfter.toStringAsFixed(1)} $unit  •  ${formatDate(log.date)}',
      ),
      trailing: SyncChip(pending: log.hasPendingWrites),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}
