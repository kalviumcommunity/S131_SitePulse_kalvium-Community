// ignore_for_file: subtype_of_sealed_class
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:site_pulse/data/models/app_user.dart';
import 'package:site_pulse/data/repositories/auth_repository.dart';
import 'package:site_pulse/data/repositories/firestore_auth_repository.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockSnapshotMetadata extends Mock implements SnapshotMetadata {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockUsersCollection;
  late MockDocumentReference mockUserDocRef;
  late MockDocumentSnapshot mockUserSnapshot;
  late MockSnapshotMetadata mockMetadata;
  late FirestoreAuthRepository repository;

  const testUid = 'user_test_123';
  const testEmail = 'sup1@sitepulse.test';
  const testPassword = 'SitePulse#2026';

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockUsersCollection = MockCollectionReference();
    mockUserDocRef = MockDocumentReference();
    mockUserSnapshot = MockDocumentSnapshot();
    mockMetadata = MockSnapshotMetadata();

    when(() => mockFirestore.collection('users'))
        .thenReturn(mockUsersCollection);
    when(() => mockUsersCollection.doc(any())).thenReturn(mockUserDocRef);
    when(() => mockUserDocRef.get()).thenAnswer((_) async => mockUserSnapshot);
    when(() => mockUserSnapshot.metadata).thenReturn(mockMetadata);
    when(() => mockMetadata.hasPendingWrites).thenReturn(false);

    when(() => mockAuth.signOut()).thenAnswer((_) async {});

    repository = FirestoreAuthRepository(
      auth: mockAuth,
      firestore: mockFirestore,
    );
  });

  tearDown(() {
    repository.dispose();
  });

  group('FirestoreAuthRepository.signIn', () {
    test(
      'successfully signs in and maps user profile from users/{uid}',
      () async {
        final mockCredential = MockUserCredential();
        final mockUser = MockUser();

        when(() => mockUser.uid).thenReturn(testUid);
        when(() => mockCredential.user).thenReturn(mockUser);
        when(
          () => mockAuth.signInWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          ),
        ).thenAnswer((_) async => mockCredential);

        when(() => mockUserSnapshot.exists).thenReturn(true);
        when(() => mockUserSnapshot.data()).thenReturn({
          'role': 'supervisor',
          'name': 'Ramesh Yadav',
          'siteId': 'site_metro',
        });

        final result = await repository.signIn(testEmail, testPassword);

        expect(result.uid, testUid);
        expect(result.role, UserRole.supervisor);
        expect(result.name, 'Ramesh Yadav');
        expect(result.siteId, 'site_metro');
        expect(repository.currentUser, result);
      },
    );

    test(
      'signs out and throws accountNotSetUp if users/{uid} doc does not exist',
      () async {
        final mockCredential = MockUserCredential();
        final mockUser = MockUser();

        when(() => mockUser.uid).thenReturn(testUid);
        when(() => mockCredential.user).thenReturn(mockUser);
        when(
          () => mockAuth.signInWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          ),
        ).thenAnswer((_) async => mockCredential);

        when(() => mockUserSnapshot.exists).thenReturn(false);
        when(() => mockUserSnapshot.data()).thenReturn(null);

        try {
          await repository.signIn(testEmail, testPassword);
          fail('Expected AuthFailure to be thrown');
        } on AuthFailure catch (e) {
          expect(e.code, AuthFailureCode.accountNotSetUp);
        }

        verify(() => mockAuth.signOut()).called(1);
        expect(repository.currentUser, isNull);
      },
    );

    test(
      'maps invalid-credential to AuthFailureCode.invalidCredentials',
      () async {
        when(
          () => mockAuth.signInWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          ),
        ).thenThrow(FirebaseAuthException(code: 'invalid-credential'));

        try {
          await repository.signIn(testEmail, testPassword);
          fail('Expected AuthFailure');
        } on AuthFailure catch (e) {
          expect(e.code, AuthFailureCode.invalidCredentials);
        }
      },
    );

    test('maps wrong-password to AuthFailureCode.invalidCredentials', () async {
      when(
        () => mockAuth.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        ),
      ).thenThrow(FirebaseAuthException(code: 'wrong-password'));

      try {
        await repository.signIn(testEmail, testPassword);
        fail('Expected AuthFailure');
      } on AuthFailure catch (e) {
        expect(e.code, AuthFailureCode.invalidCredentials);
      }
    });

    test('maps user-not-found to AuthFailureCode.invalidCredentials', () async {
      when(
        () => mockAuth.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        ),
      ).thenThrow(FirebaseAuthException(code: 'user-not-found'));

      try {
        await repository.signIn(testEmail, testPassword);
        fail('Expected AuthFailure');
      } on AuthFailure catch (e) {
        expect(e.code, AuthFailureCode.invalidCredentials);
      }
    });

    test('maps network-request-failed to AuthFailureCode.noNetwork', () async {
      when(
        () => mockAuth.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        ),
      ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      try {
        await repository.signIn(testEmail, testPassword);
        fail('Expected AuthFailure');
      } on AuthFailure catch (e) {
        expect(e.code, AuthFailureCode.noNetwork);
      }
    });

    test('maps SocketException (DNS / connection refused) to AuthFailureCode.noNetwork', () async {
      when(
        () => mockAuth.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        ),
      ).thenThrow(const SocketException('Failed host lookup'));

      try {
        await repository.signIn(testEmail, testPassword);
        fail('Expected AuthFailure');
      } on AuthFailure catch (e) {
        expect(e.code, AuthFailureCode.noNetwork);
      }
    });

    test('maps HandshakeException (certificate / SSL error) to AuthFailureCode.noNetwork', () async {
      when(
        () => mockAuth.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        ),
      ).thenThrow(const HandshakeException('Certificate verify failed'));

      try {
        await repository.signIn(testEmail, testPassword);
        fail('Expected AuthFailure');
      } on AuthFailure catch (e) {
        expect(e.code, AuthFailureCode.noNetwork);
      }
    });

    test('maps FirebaseAuthException with network message to AuthFailureCode.noNetwork', () async {
      when(
        () => mockAuth.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        ),
      ).thenThrow(
        FirebaseAuthException(
          code: 'unknown',
          message: 'A network error (such as timeout, interrupted connection) occurred.',
        ),
      );

      try {
        await repository.signIn(testEmail, testPassword);
        fail('Expected AuthFailure');
      } on AuthFailure catch (e) {
        expect(e.code, AuthFailureCode.noNetwork);
      }
    });

    test(
      'maps unrecognized FirebaseAuthException to AuthFailureCode.unknown',
      () async {
        when(
          () => mockAuth.signInWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          ),
        ).thenThrow(FirebaseAuthException(code: 'too-many-requests'));

        try {
          await repository.signIn(testEmail, testPassword);
          fail('Expected AuthFailure');
        } on AuthFailure catch (e) {
          expect(e.code, AuthFailureCode.unknown);
        }
      },
    );
  });

  group('FirestoreAuthRepository.watchCurrentUser', () {
    test('emits null when authStateChanges emits null', () async {
      when(() => mockAuth.authStateChanges())
          .thenAnswer((_) => Stream.value(null));

      final stream = repository.watchCurrentUser();
      final user = await stream.first;

      expect(user, isNull);
      expect(repository.currentUser, isNull);
    });

    test(
      'maps authStateChanges with user to AppUser via users/{uid}',
      () async {
        final mockUser = MockUser();
        when(() => mockUser.uid).thenReturn(testUid);
        when(() => mockAuth.authStateChanges())
            .thenAnswer((_) => Stream.value(mockUser));

        when(() => mockUserSnapshot.exists).thenReturn(true);
        when(() => mockUserSnapshot.data())
            .thenReturn({'role': 'pm', 'name': 'Priya Nair'});

        final stream = repository.watchCurrentUser();
        final user = await stream.first;

        expect(user, isNotNull);
        expect(user!.uid, testUid);
        expect(user.role, UserRole.pm);
        expect(user.name, 'Priya Nair');
        expect(user.siteId, isNull);
        expect(repository.currentUser, user);
      },
    );
  });

  group('FirestoreAuthRepository.signOut', () {
    test('signs out from FirebaseAuth and clears currentUser', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      repository.signOut();

      verify(() => mockAuth.signOut()).called(1);
      expect(repository.currentUser, isNull);
    });
  });
}
