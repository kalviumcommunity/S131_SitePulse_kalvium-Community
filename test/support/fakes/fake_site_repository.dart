import 'dart:async';

import 'package:site_pulse/data/models/site.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';
import 'package:site_pulse/data/repositories/site_repository.dart';

class FakeSiteRepository implements SiteRepository {
  static List<Site> get defaultSites => [
    Site(
      id: 'site-1',
      name: 'Downtown Heights',
      lastEntryAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Site(
      id: 'site-2',
      name: 'Westside Commercial Hub',
      lastEntryAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    Site(
      id: 'site-3',
      name: 'Harbor Bridge Expansion',
      lastEntryAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final Map<String, Site> _sites = {};
  final StreamController<List<Site>> _sitesController =
      StreamController<List<Site>>.broadcast();
  final StreamController<RepositoryError> _errorController =
      StreamController<RepositoryError>.broadcast();

  FakeSiteRepository({List<Site>? initialSites}) {
    final list = initialSites ?? defaultSites;
    for (final s in list) {
      _sites[s.id] = s;
    }
  }

  @override
  Stream<List<Site>> watchSites() async* {
    yield _sites.values.toList();
    yield* _sitesController.stream;
  }

  @override
  Stream<Site?> watchSite(String siteId) async* {
    yield _sites[siteId];
    yield* _sitesController.stream.map((list) {
      try {
        return list.firstWhere((s) => s.id == siteId);
      } catch (_) {
        return null;
      }
    });
  }

  @override
  Stream<RepositoryError> get errorStream => _errorController.stream;

  void dispose() {
    _sitesController.close();
    _errorController.close();
  }
}
