enum AuthFailureCode {
  invalidCredentials,
  noNetwork,
  accountNotSetUp,
  unknown;
}

class AuthFailure implements Exception {
  final AuthFailureCode code;
  final String? message;

  const AuthFailure(this.code, [this.message]);

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
}
