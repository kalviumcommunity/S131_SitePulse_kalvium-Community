import 'package:site_pulse/data/models/site.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

abstract class SiteRepository {
  Stream<List<Site>> watchSites();

  Stream<Site?> watchSite(String siteId);

  Stream<RepositoryError> get errorStream;
}
