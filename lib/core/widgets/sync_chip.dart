import 'package:flutter/material.dart';
import 'package:site_pulse/core/theme/app_theme.dart';

/// Small pill that shows whether a record is pending sync or synced to the server.
/// Uses icon + text so it never relies on color alone.
class SyncChip extends StatelessWidget {
  const SyncChip({
    super.key,
    required this.pending,
  });

  final bool pending;

  @override
  Widget build(BuildContext context) {
    final color = pending ? AppColors.warning : AppColors.success;
    final icon = pending ? Icons.access_time : Icons.check_circle_outline;
    final label = pending ? 'Pending' : 'Synced';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
