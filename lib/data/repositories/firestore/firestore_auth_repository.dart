import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/repositories/auth_repository.dart';
import 'package:site_pulse/data/repositories/repository_error.dart';

class FirestoreAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AppUser? _currentUser;
  Stream<AppUser?>? _authStateStream;
  final StreamController<RepositoryError> _errorController =
      StreamController<RepositoryError>.broadcast();

  FirestoreAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<RepositoryError> get errorStream => _errorController.stream;

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _authStateStream ??= _auth.authStateChanges().asyncMap((
      firebaseUser,
    ) async {
      if (firebaseUser == null) {
        _currentUser = null;
        return null;
      }

      try {
        // Default source: Source.serverAndCache (works offline after first login)
        final doc = await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (!doc.exists || doc.data() == null) {
          await _auth.signOut();
          _currentUser = null;
          return null;
        }

        final data = doc.data()!;
        final appUser = AppUser(
          uid: firebaseUser.uid,
          role: UserRole.fromString(data['role'] as String? ?? ''),
          name: data['name'] as String? ?? '',
          siteId: data['siteId'] as String?,
          email: firebaseUser.email,
          hasPendingWrites: doc.metadata.hasPendingWrites,
        );
        _currentUser = appUser;
        return appUser;
      } catch (e, st) {
        _errorController.add(
          RepositoryError(
            operation: 'watchCurrentUser',
            message: e.toString(),
            error: e,
            stackTrace: st,
          ),
        );
        if (_currentUser?.uid == firebaseUser.uid) {
          return _currentUser;
        }
        return null;
      }
    }).asBroadcastStream();
  }

  @override
  Future<AppUser> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthFailure(
          code: AuthFailureCode.unknown,
          message: 'User is null after sign in.',
        );
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) {
        await _auth.signOut();
        _currentUser = null;
        throw const AuthFailure(
          code: AuthFailureCode.accountNotSetUp,
          message: 'User profile document users/{uid} does not exist.',
        );
      }

      final data = doc.data()!;
      final appUser = AppUser(
        uid: user.uid,
        role: UserRole.fromString(data['role'] as String? ?? ''),
        name: data['name'] as String? ?? '',
        siteId: data['siteId'] as String?,
        email: user.email,
        hasPendingWrites: doc.metadata.hasPendingWrites,
      );
      _currentUser = appUser;
      return appUser;
    } on FirebaseAuthException catch (e) {
      final failure = _mapFirebaseAuthException(e);
      _errorController.add(
        RepositoryError(
          operation: 'signIn',
          message: failure.message,
          error: e,
        ),
      );
      throw failure;
    } on AuthFailure catch (e) {
      _errorController.add(
        RepositoryError(operation: 'signIn', message: e.message, error: e),
      );
      rethrow;
    } catch (e, st) {
      final isNetwork = _isNetworkError(e);
      final failure = AuthFailure(
        code: isNetwork ? AuthFailureCode.noNetwork : AuthFailureCode.unknown,
        message: isNetwork
            ? 'Network error. Please check your connection.'
            : e.toString(),
      );
      _errorController.add(
        RepositoryError(
          operation: 'signIn',
          message: failure.message,
          error: e,
          stackTrace: st,
        ),
      );
      throw failure;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e, st) {
      _errorController.add(
        RepositoryError(
          operation: 'signOut',
          message: e.toString(),
          error: e,
          stackTrace: st,
        ),
      );
    } finally {
      _currentUser = null;
    }
  }

  @override
  void switchUser(String uid) {
    // Real authentication is controlled by FirebaseAuth.
  }

  bool _isNetworkError(Object error) {
    if (error is SocketException ||
        error is HttpException ||
        error is HandshakeException ||
        error is CertificateException ||
        error is TlsException ||
        error is TimeoutException) {
      return true;
    }
    if (error is FirebaseAuthException) {
      if (error.code == 'network-request-failed') return true;
      final msg = (error.message ?? '').toLowerCase();
      final code = error.code.toLowerCase();
      return msg.contains('network') ||
          msg.contains('connection') ||
          msg.contains('socket') ||
          msg.contains('dns') ||
          msg.contains('host lookup') ||
          msg.contains('unreachable') ||
          msg.contains('timeout') ||
          msg.contains('offline') ||
          msg.contains('handshake') ||
          msg.contains('certificate') ||
          code.contains('network') ||
          code.contains('timeout');
    }
    if (error is FirebaseException) {
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return true;
      }
    }
    final str = error.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('network-request-failed') ||
        str.contains('failed host lookup') ||
        str.contains('connection refused') ||
        str.contains('network is unreachable') ||
        str.contains('handshakeexception') ||
        str.contains('certificate') ||
        str.contains('timeoutexception');
  }

  AuthFailure _mapFirebaseAuthException(FirebaseAuthException e) {
    if (_isNetworkError(e)) {
      return AuthFailure(
        code: AuthFailureCode.noNetwork,
        message: e.message ?? 'Network connection failed.',
      );
    }

    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return AuthFailure(
          code: AuthFailureCode.invalidCredentials,
          message: e.message ?? 'Invalid email or password.',
        );
      default:
        return AuthFailure(
          code: AuthFailureCode.unknown,
          message: e.message ?? 'Authentication error occurred.',
        );
    }
  }

  void dispose() {
    _errorController.close();
  }
}
