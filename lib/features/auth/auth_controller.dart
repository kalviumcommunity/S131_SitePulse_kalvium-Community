import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/data/repositories/auth_repository.dart';
import 'package:site_pulse/router.dart';
import 'auth_failure.dart';

final authStateProvider = StreamProvider<AppUser?>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.watchCurrentUser();
});

typedef SignInFn = Future<AppUser> Function(String email, String password);

final signInOverrideProvider = Provider<SignInFn?>((ref) => null);

final authControllerProvider = Provider<AuthController>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final signInOverride = ref.watch(signInOverrideProvider);
  return AuthController(authRepo, signInOverride: signInOverride);
});

class AuthController {
  final AuthRepository _authRepo;
  final SignInFn? signInOverride;

  AuthController(this._authRepo, {this.signInOverride});

  Future<AppUser> signIn(String email, String password) async {
    final overrideFn = signInOverride;
    if (overrideFn != null) {
      return overrideFn(email, password);
    }

    // If repository has signIn (added by partner), invoke dynamically
    try {
      final dynamic repo = _authRepo;
      final result = repo.signIn(email, password);
      if (result is Future<AppUser>) {
        return await result;
      }
    } on AuthFailure {
      rethrow;
    } on NoSuchMethodError {
      // Repository has not implemented signIn yet; use standard PRD fake logic
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw const AuthFailure(AuthFailureCode.unknown);
    }

    // PRD Default Authentication Logic for Fake Repository
    const validPassword = 'SitePulse#2026';
    final trimmedEmail = email.trim().toLowerCase();

    if (password != validPassword) {
      throw const AuthFailure(AuthFailureCode.invalidCredentials);
    }

    String? targetUid;
    if (trimmedEmail == 'sup1@sitepulse.test') {
      targetUid = 'user-sup-1';
    } else if (trimmedEmail == 'sup2@sitepulse.test') {
      targetUid = 'user-sup-2';
    } else if (trimmedEmail == 'sup3@sitepulse.test') {
      targetUid = 'user-sup-3';
    } else if (trimmedEmail == 'pm@sitepulse.test') {
      targetUid = 'user-pm-1';
    } else if (trimmedEmail.endsWith('@sitepulse.test')) {
      throw const AuthFailure(AuthFailureCode.accountNotSetUp);
    } else {
      throw const AuthFailure(AuthFailureCode.invalidCredentials);
    }

    _authRepo.switchUser(targetUid);
    if (currentAuthRepository != _authRepo) {
      currentAuthRepository.switchUser(targetUid);
    }
    final user = _authRepo.currentUser;
    if (user == null) {
      throw const AuthFailure(AuthFailureCode.accountNotSetUp);
    }
    return user;
  }

  void signOut() {
    _authRepo.signOut();
    if (currentAuthRepository != _authRepo) {
      currentAuthRepository.signOut();
    }
  }
}
