import 'dart:async';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/repositories/auth_repository.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

class FakeAuthRepository implements AuthRepository {
  static final List<AppUser> defaultUsers = [
    const AppUser(
      uid: 'user-sup-1',
      role: UserRole.supervisor,
      name: 'Suresh Kumar',
      siteId: 'site-1',
      email: 'sup1@sitepulse.test',
    ),
    const AppUser(
      uid: 'user-pm-1',
      role: UserRole.pm,
      name: 'Priya Sharma',
      siteId: null,
      email: 'pm@sitepulse.test',
    ),
  ];

  final Map<String, AppUser> _users = {};
  AppUser? _currentUser;
  final StreamController<AppUser?> _userController =
      StreamController<AppUser?>.broadcast();
  final StreamController<RepositoryError> _errorController =
      StreamController<RepositoryError>.broadcast();

  FakeAuthRepository({List<AppUser>? initialUsers, AppUser? initialUser}) {
    final seed = initialUsers ?? defaultUsers;
    for (final u in seed) {
      _users[u.uid] = u;
    }
    _currentUser = initialUser ?? _users['user-sup-1'] ?? (seed.isNotEmpty ? seed.first : null);
  }

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> watchCurrentUser() async* {
    yield _currentUser;
    yield* _userController.stream;
  }

  @override
  Stream<RepositoryError> get errorStream => _errorController.stream;

  @override
  void signOut() {
    _currentUser = null;
    _userController.add(null);
  }

  @override
  void switchUser(String uid) {
    if (_users.containsKey(uid)) {
      _currentUser = _users[uid];
      _userController.add(_currentUser);
    } else {
      _errorController.add(
        RepositoryError(
          operation: 'switchUser',
          message: 'User with uid $uid not found',
        ),
      );
    }
  }

  @override
  Future<AppUser> signIn(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    final user = _users.values.firstWhere(
      (u) =>
          u.uid.toLowerCase() == normalized ||
          u.name.toLowerCase() == normalized,
      orElse: () => _currentUser ?? (defaultUsers.isNotEmpty ? defaultUsers.first : const AppUser(uid: 'user-sup-1', role: UserRole.supervisor, name: 'Suresh Kumar', siteId: 'site-1')),
    );
    _currentUser = user;
    _userController.add(_currentUser);
    return user;
  }

  void dispose() {
    _userController.close();
    _errorController.close();
  }
}
