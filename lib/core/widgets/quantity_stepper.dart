import 'package:flutter/material.dart';
import 'package:site_pulse/core/theme/app_theme.dart';

/// Quantity stepper with large tap targets (48dp+) for decrementing/incrementing a number.
/// Enforces min and max bounds.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    this.step = 1.0,
  });

  final double value;
  final double min;
  final double max;
  final String unit;
  final ValueChanged<double> onChanged;
  final double step;

  bool get canDecrement => value > min;
  bool get canIncrement => value < max;

  String _formatNumber(double num) {
    if (num % 1 == 0) {
      return num.toInt().toString();
    }
    return num.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Decrement button
        SizedBox(
          width: 52,
          height: 52,
          child: FilledButton.tonal(
            key: const Key('stepper_decrement_button'),
            onPressed: canDecrement
                ? () {
                    final next = (value - step).clamp(min, max);
                    onChanged(next);
                  }
                : null,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Icon(Icons.remove, size: 26),
          ),
        ),
        const SizedBox(width: 16),
        // Number and unit in the middle
        Container(
          constraints: const BoxConstraints(minWidth: 100),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatNumber(value),
                key: const Key('stepper_value_text'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Increment button
        SizedBox(
          width: 52,
          height: 52,
          child: FilledButton.tonal(
            key: const Key('stepper_increment_button'),
            onPressed: canIncrement
                ? () {
                    final next = (value + step).clamp(min, max);
                    onChanged(next);
                  }
                : null,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Icon(Icons.add, size: 26),
          ),
        ),
      ],
    );
  }
}
