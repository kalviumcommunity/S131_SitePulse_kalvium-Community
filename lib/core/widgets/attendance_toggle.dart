import 'package:flutter/material.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/data/models/attendance_entry.dart';

class AttendanceToggle extends StatelessWidget {
  const AttendanceToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AttendanceStatus value;
  final ValueChanged<AttendanceStatus> onChanged;

  Color _statusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return AppColors.success;
      case AttendanceStatus.half:
        return AppColors.warning;
      case AttendanceStatus.absent:
        return AppColors.critical;
    }
  }

  IconData _statusIcon(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Icons.check_circle_outline;
      case AttendanceStatus.half:
        return Icons.timelapse;
      case AttendanceStatus.absent:
        return Icons.cancel_outlined;
    }
  }

  String _statusLabel(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.half:
        return 'Half-day';
      case AttendanceStatus.absent:
        return 'Absent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = [
      AttendanceStatus.present,
      AttendanceStatus.half,
      AttendanceStatus.absent,
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: statuses.map((status) {
        final isSelected = value == status;
        final color = _statusColor(status);
        final icon = _statusIcon(status);
        final label = _statusLabel(status);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: SizedBox(
            height: 48, // 48dp tap target
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: Key('attendance_toggle_${status.name}'),
                onTap: () => onChanged(status),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? color : color.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected ? Colors.white : color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isSelected ? Colors.white : color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
