import 'package:site_pulse/data/models/incident.dart';
import 'package:site_pulse/data/models/material.dart';

/// Pure function to check if a material is at or below its low stock threshold.
/// Hard rule: low stock = currentStock <= lowStockThreshold.
bool isLowStock(Material material) {
  return material.currentStock <= material.lowStockThreshold;
}

/// Pure function to check if an incident severity is high or critical.
/// Hard rule: high severity = high or critical.
bool isHighSeverity(Severity severity) {
  return severity == Severity.high || severity == Severity.critical;
}
