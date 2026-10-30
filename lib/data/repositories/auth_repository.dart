import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

enum AuthFailureCode { invalidCredentials, noNetwork, accountNotSetUp, unknown }

class AuthFailure implements Exception {
  final AuthFailureCode code;
  final String message;

  const AuthFailure({required this.code, required this.message});

  String get userMessage {
    switch (code) {
      case AuthFailureCode.invalidCredentials:
        return 'Wrong email or password';
      case AuthFailureCode.noNetwork:
        return 'No network connection';
      case AuthFailureCode.accountNotSetUp:
        return 'This account is not set up. Contact your admin.';
      case AuthFailureCode.unknown:
        return 'Something went wrong. Try again.';
    }
  }

  @override
  String toString() => 'AuthFailure(code: $code, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthFailure &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(code, message);
}

abstract class AuthRepository {
  Stream<AppUser?> watchCurrentUser();
  AppUser? get currentUser;
  Stream<RepositoryError> get errorStream;

  void signOut();

  Future<AppUser> signIn(String email, String password) {
    throw UnimplementedError('signIn has not been implemented.');
  }
}
