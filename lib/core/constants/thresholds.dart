import 'package:site_pulse/data/models/incident.dart';
import 'package:site_pulse/data/models/material.dart';

bool isLowStock(Material material) {
  return material.currentStock <= material.lowStockThreshold;
}

bool isHighSeverity(Severity severity) {
  return severity == Severity.high || severity == Severity.critical;
}
