import 'package:flutter/material.dart';
import 'package:site_pulse/core/theme/app_theme.dart';
import 'package:site_pulse/data/models/incident.dart';

class SeveritySelector extends StatelessWidget {
  const SeveritySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Severity? value;
  final ValueChanged<Severity> onChanged;

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

  String _severityLabel(Severity s) {
    switch (s) {
      case Severity.minor:
        return 'Minor';
      case Severity.moderate:
        return 'Moderate';
      case Severity.high:
        return 'High';
      case Severity.critical:
        return 'Critical';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: Severity.values.map((s) {
            final isSelected = value == s;
            final color = _severityColor(s);
            final icon = _severityIcon(s);
            final label = _severityLabel(s);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: SizedBox(
                  height: 52, // >= 48dp target
                  child: InkWell(
                    key: Key('severity_${s.name}'),
                    onTap: () => onChanged(s),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color
                            : color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : color.withValues(alpha: 0.4),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: 18,
                            color: isSelected ? Colors.white : color,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected ? Colors.white : color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
