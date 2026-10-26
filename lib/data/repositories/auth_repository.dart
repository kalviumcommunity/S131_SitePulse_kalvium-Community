import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

abstract class AuthRepository {
  Stream<AppUser?> watchCurrentUser();
  AppUser? get currentUser;
  Stream<RepositoryError> get errorStream;

  void signOut();
  void switchUser(String uid);
}
