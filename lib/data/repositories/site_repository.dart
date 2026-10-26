import 'package:site_pulse/data/models/site.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

abstract class SiteRepository {
  /// PM reads all sites
  Stream<List<Site>> watchSites();

  /// Supervisor or site detail reads single site
  Stream<Site?> watchSite(String siteId);

  /// Fire-and-forget write: returns document ID immediately,
  /// failures reported through errorStream.
  String createOrUpdateSite(Site site);

  Stream<RepositoryError> get errorStream;
}
