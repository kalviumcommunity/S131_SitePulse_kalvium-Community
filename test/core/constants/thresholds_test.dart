import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/core/constants/thresholds.dart';
import 'package:site_pulse/data/models/incident.dart';
import 'package:site_pulse/data/models/material.dart';

void main() {
  group('thresholds', () {
    group('isLowStock', () {
      test('returns true when currentStock is strictly less than threshold', () {
        const material = Material(
          id: 'mat-1',
          name: 'Cement',
          unit: 'bags',
          openingStock: 100,
          currentStock: 15,
          lowStockThreshold: 25,
        );
        expect(isLowStock(material), isTrue);
      });

      test('returns true when currentStock equals lowStockThreshold (<=)', () {
        const material = Material(
          id: 'mat-2',
          name: 'Sand',
          unit: 'tonnes',
          openingStock: 50,
          currentStock: 10,
          lowStockThreshold: 10,
        );
        expect(isLowStock(material), isTrue);
      });

      test('returns false when currentStock is above threshold', () {
        const material = Material(
          id: 'mat-3',
          name: 'Steel',
          unit: 'kg',
          openingStock: 100,
          currentStock: 50,
          lowStockThreshold: 20,
        );
        expect(isLowStock(material), isFalse);
      });
    });

    group('isHighSeverity', () {
      test('returns true for Severity.high', () {
        expect(isHighSeverity(Severity.high), isTrue);
      });

      test('returns true for Severity.critical', () {
        expect(isHighSeverity(Severity.critical), isTrue);
      });

      test('returns false for Severity.minor', () {
        expect(isHighSeverity(Severity.minor), isFalse);
      });

      test('returns false for Severity.moderate', () {
        expect(isHighSeverity(Severity.moderate), isFalse);
      });
    });
  });
}
