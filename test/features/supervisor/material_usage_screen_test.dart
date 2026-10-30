import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:site_pulse/core/constants/thresholds.dart';
import 'package:site_pulse/data/models/material.dart' as sp;
import 'package:site_pulse/data/models/material_log.dart';
import 'package:site_pulse/features/supervisor/material/material_usage_screen.dart';

import '../../support/fakes/fakes.dart';
import '../../support/test_overrides.dart';

class _TrackingMaterialRepository extends FakeMaterialRepository {
  _TrackingMaterialRepository({super.initialMaterials});

  final List<String?> materialSiteIds = [];
  final List<String?> logSiteIds = [];
  final List<String?> usageSiteIds = [];

  @override
  Stream<List<sp.Material>> watchMaterials({String? siteId}) {
    materialSiteIds.add(siteId);
    return super.watchMaterials(siteId: siteId);
  }

  @override
  Stream<List<MaterialLog>> watchMaterialLogs({
    String? siteId,
    String? materialId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    logSiteIds.add(siteId);
    return super.watchMaterialLogs(
      siteId: siteId,
      materialId: materialId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  String logUsage({
    required String materialId,
    required double qtyUsed,
    String? siteId,
    DateTime? date,
    String? logId,
  }) {
    usageSiteIds.add(siteId);
    return super.logUsage(
      materialId: materialId,
      qtyUsed: qtyUsed,
      siteId: siteId,
      date: date,
      logId: logId,
    );
  }
}

Widget buildScreen({FakeMaterialRepository? repository}) {
  return ProviderScope(
    overrides: fakeRepositoryOverrides(materialRepository: repository),
    child: const MaterialApp(home: MaterialUsageScreen()),
  );
}

void main() {
  group('MaterialUsageScreen Widget Tests', () {
    testWidgets('supervisor material queries and usage are site-scoped', (
      tester,
    ) async {
      final repository = _TrackingMaterialRepository(
        initialMaterials: const [
          sp.Material(
            id: 'mat_shared',
            name: 'Site 1 Cement',
            unit: 'bags',
            openingStock: 100,
            currentStock: 80,
            lowStockThreshold: 20,
            siteId: 'site-1',
          ),
          sp.Material(
            id: 'mat_shared',
            name: 'Site 2 Cement',
            unit: 'bags',
            openingStock: 100,
            currentStock: 15,
            lowStockThreshold: 20,
            siteId: 'site-2',
          ),
        ],
      );

      await tester.pumpWidget(buildScreen(repository: repository));
      await tester.pumpAndSettle();

      expect(repository.materialSiteIds, isNotEmpty);
      expect(repository.materialSiteIds, everyElement('site-1'));
      expect(repository.logSiteIds, isNotEmpty);
      expect(repository.logSiteIds, everyElement('site-1'));
      expect(find.text('Site 1 Cement'), findsOneWidget);
      expect(find.text('Site 2 Cement'), findsNothing);

      await tester.tap(find.byKey(const Key('log_usage_button')));
      await tester.pump();

      expect(repository.usageSiteIds, ['site-1']);
    });

    testWidgets('renders material dropdown', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('material_dropdown')), findsOneWidget);
    });

    testWidgets('renders quantity stepper', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('quantity_stepper')), findsOneWidget);
    });

    testWidgets('renders log usage button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('log_usage_button')), findsOneWidget);
    });

    testWidgets('tapping Log Usage shows saved snackbar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('log_usage_button')));
      await tester.pump();

      expect(find.text('Saved on this device'), findsOneWidget);
    });

    testWidgets('shows current and projected stock labels', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('current_stock_label')), findsOneWidget);
      expect(find.byKey(const Key('projected_stock_label')), findsOneWidget);
    });
  });

  group('isLowStock Threshold Tests', () {
    test('returns true when currentStock <= lowStockThreshold', () {
      const m = sp.Material(
        id: 'm1',
        name: 'Cement',
        unit: 'bags',
        openingStock: 100,
        currentStock: 20,
        lowStockThreshold: 20,
      );
      expect(isLowStock(m), isTrue);
    });

    test('returns false when currentStock > lowStockThreshold', () {
      const m = sp.Material(
        id: 'm2',
        name: 'Sand',
        unit: 'kg',
        openingStock: 500,
        currentStock: 200,
        lowStockThreshold: 50,
      );
      expect(isLowStock(m), isFalse);
    });

    test('returns true when currentStock is 0', () {
      const m = sp.Material(
        id: 'm3',
        name: 'Paint',
        unit: 'L',
        openingStock: 100,
        currentStock: 0,
        lowStockThreshold: 10,
      );
      expect(isLowStock(m), isTrue);
    });
  });

  group('FakeMaterialRepository Tests', () {
    test('watchMaterials emits seeded materials', () async {
      final repo = FakeMaterialRepository();
      final materials = await repo.watchMaterials().first;
      expect(materials.isNotEmpty, isTrue);
    });

    test('logUsage decrements stock and adds a log', () async {
      final repo = FakeMaterialRepository();
      final mats = await repo.watchMaterials().first;
      expect(mats.isNotEmpty, isTrue);
      final mat = mats.first;
      final stockBefore = mat.currentStock;

      repo.logUsage(materialId: mat.id, qtyUsed: 5.0);

      final updatedMats = await repo.watchMaterials().first;
      final updated = updatedMats.firstWhere((m) => m.id == mat.id);
      expect(updated.currentStock, stockBefore - 5.0);
    });
  });
}
