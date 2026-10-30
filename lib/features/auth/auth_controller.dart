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

final authControllerProvider = Provider<AuthController>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return AuthController(authRepo);
});

class AuthController {
  final repository.AuthRepository _authRepo;

  AuthController(this._authRepo);

  Future<AppUser> signIn(String email, String password) async {
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
