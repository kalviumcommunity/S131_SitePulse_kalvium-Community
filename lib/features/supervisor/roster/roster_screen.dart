import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/core/widgets/widgets.dart';
import 'package:site_pulse/data/models/worker.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:uuid/uuid.dart';

const List<String> kAvailableTrades = [
  'Mason',
  'Carpenter',
  'Electrician',
  'Welder',
  'Helper',
];

class RosterScreen extends ConsumerStatefulWidget {
  const RosterScreen({super.key});

  @override
  ConsumerState<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends ConsumerState<RosterScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  StreamSubscription<List<Worker>>? _subscription;
  List<Worker>? _workers;
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupWorkerStream();
  }

  void _setupWorkerStream() {
    final authRepo = ref.read(authRepositoryProvider);
    _subscription?.cancel();
    final siteId = authRepo.currentUser?.siteId;
    if (siteId == null || siteId.isEmpty) {
      setState(() {
        _workers = [];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    final workerRepo = ref.read(workerRepositoryProvider);
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _subscription = workerRepo
        .watchWorkers(siteId, activeOnly: true)
        .listen(
          (workers) {
            if (mounted) {
              setState(() {
                _workers = workers;
                _isLoading = false;
                _error = null;
              });
            }
          },
          onError: (err) {
            if (mounted) {
              setState(() {
                _error = err;
                _isLoading = false;
              });
            }
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddWorkerDialog(
    BuildContext context,
    String siteId,
    List<Worker> activeWorkers,
  ) {
    final workerId = const Uuid().v4();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _AddWorkerDialog(
        workerId: workerId,
        siteId: siteId,
        existingActiveWorkers: activeWorkers,
        onSave: (worker) {
          // Never await write!
          final workerRepo = ref.read(workerRepositoryProvider);
          workerRepo.saveWorker(siteId, worker);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved on this device')));
        },
      ),
    );
  }

  void _confirmRemoveWorker(
    BuildContext context,
    String siteId,
    Worker worker,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove Worker'),
        content: Text(
          'Are you sure you want to remove ${worker.name}? Past attendance records will remain.',
        ),
        actions: [
          TextButton(
            key: const Key('cancel_remove_button'),
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_remove_button'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.critical),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              // Never await write!
              final workerRepo = ref.read(workerRepositoryProvider);
              workerRepo.toggleWorkerActive(siteId, worker.id, false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved on this device')),
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.watch(authRepositoryProvider);
    final user = authRepo.currentUser;
    final siteId = user?.siteId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Roster'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: OfflineBanner(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_worker_fab'),
        onPressed: siteId == null || siteId.isEmpty
            ? null
            : () => _showAddWorkerDialog(context, siteId, _workers ?? []),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Worker'),
      ),
      body: _buildBody(context, siteId),
    );
  }

  Widget _buildBody(BuildContext context, String? siteId) {
    if (siteId == null || siteId.isEmpty) {
      return const EmptyView(
        message: 'No project site is assigned to this account.',
      );
    }

    if (_isLoading) {
      return const LoadingView(message: 'Loading active workers...');
    }

    if (_error != null) {
      return ErrorView(
        message: 'Could not load worker roster.',
        onRetry: _setupWorkerStream,
      );
    }

    final allActiveWorkers = _workers ?? [];

    if (allActiveWorkers.isEmpty) {
      return EmptyView(
        message: 'No workers yet - add the first one',
        ctaLabel: 'Add Worker',
        onCta: () => _showAddWorkerDialog(context, siteId, allActiveWorkers),
      );
    }

    final filteredWorkers = allActiveWorkers.where((w) {
      if (_searchQuery.isEmpty) return true;
      final nameMatches = w.name.toLowerCase().contains(_searchQuery);
      final codeMatches = w.workerCode.toLowerCase().contains(_searchQuery);
      return nameMatches || codeMatches;
    }).toList();

    return Column(
      children: [
        // Header with count & Search Box
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Theme.of(context).colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Workers',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${allActiveWorkers.length} total',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('worker_search_field'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or worker code...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
        ),

        // Worker List
        Expanded(
          child: filteredWorkers.isEmpty
              ? Center(
                  child: Text(
                    'No active workers match "$_searchQuery"',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filteredWorkers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final worker = filteredWorkers[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              worker.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SyncChip(pending: worker.hasPendingWrites),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                worker.workerCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              worker.trade,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: IconButton(
                        key: Key('remove_worker_${worker.id}'),
                        icon: const Icon(
                          Icons.person_remove_outlined,
                          color: AppColors.critical,
                        ),
                        tooltip: 'Remove Worker',
                        onPressed: () =>
                            _confirmRemoveWorker(context, siteId, worker),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AddWorkerDialog extends StatefulWidget {
  final String workerId;
  final String siteId;
  final List<Worker> existingActiveWorkers;
  final ValueChanged<Worker> onSave;

  const _AddWorkerDialog({
    required this.workerId,
    required this.siteId,
    required this.existingActiveWorkers,
    required this.onSave,
  });

  @override
  State<_AddWorkerDialog> createState() => _AddWorkerDialogState();
}

class _AddWorkerDialogState extends State<_AddWorkerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _workerCodeController = TextEditingController();
  String _selectedTrade = kAvailableTrades.first;

  @override
  void dispose() {
    _nameController.dispose();
    _workerCodeController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  String? _validateWorkerCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Worker code is required';
    }
    final trimmedCode = value.trim().toUpperCase();
    final isDuplicate = widget.existingActiveWorkers.any(
      (w) => w.workerCode.trim().toUpperCase() == trimmedCode,
    );
    if (isDuplicate) {
      return 'Worker code already exists for an active worker';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newWorker = Worker(
      id: widget.workerId,
      name: _nameController.text.trim(),
      workerCode: _workerCodeController.text.trim().toUpperCase(),
      trade: _selectedTrade,
      active: true,
      siteId: widget.siteId,
      hasPendingWrites: true,
    );

    widget.onSave(newWorker);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Worker'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('add_worker_name_field'),
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Worker Name *',
                  hintText: 'e.g. Ramesh Patel',
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('add_worker_code_field'),
                controller: _workerCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Worker Code *',
                  hintText: 'e.g. MAS-101',
                ),
                validator: _validateWorkerCode,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('add_worker_trade_dropdown'),
                initialValue: _selectedTrade,
                decoration: const InputDecoration(labelText: 'Trade *'),
                items: kAvailableTrades.map((trade) {
                  return DropdownMenuItem(value: trade, child: Text(trade));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedTrade = val;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel_add_worker_button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save_worker_button'),
          onPressed: _submit,
          child: const Text('Add Worker'),
        ),
      ],
    );
  }
}
