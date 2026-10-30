import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    if (kDebugMode && const bool.fromEnvironment('USE_EMULATOR')) {
      FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
      FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
    }
  } catch (e) {
    debugPrint('Firebase init: $e');
  }
  runApp(
    ProviderScope(child: SitePulseApp(firebaseReady: Firebase.apps.isNotEmpty)),
  );
}
