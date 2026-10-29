import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/providers.dart';
import 'package:site_pulse/data/repositories/auth_repository.dart'
    as repository;

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
  final repository.AuthRepository _authRepo;
  final SignInFn? signInOverride;

  AuthController(this._authRepo, {this.signInOverride});

  Future<AppUser> signIn(String email, String password) async {
    final overrideFn = signInOverride;
    if (overrideFn != null) {
      return overrideFn(email, password);
    }
    try {
      return await _authRepo.signIn(email, password);
    } on repository.AuthFailure catch (error) {
      final code = switch (error.code) {
        repository.AuthFailureCode.invalidCredentials =>
          AuthFailureCode.invalidCredentials,
        repository.AuthFailureCode.noNetwork => AuthFailureCode.noNetwork,
        repository.AuthFailureCode.accountNotSetUp =>
          AuthFailureCode.accountNotSetUp,
        repository.AuthFailureCode.unknown => AuthFailureCode.unknown,
      };
      throw AuthFailure(code, error.message);
    } catch (e) {
      throw AuthFailure(AuthFailureCode.unknown, e.toString());
    }
  }

  void signOut() {
    _authRepo.signOut();
  }
}
