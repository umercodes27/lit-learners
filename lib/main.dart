import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/firebase_web_options.dart';
import 'services/firebase/admin_firebase_app.dart';
import 'services/local/db_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDatabaseFactory();
  if (AppConfig.useFirebase) {
    await _initializeFirebase();
  }
  // Channels and the timezone database have to exist before any reminder can
  // be scheduled, and scheduling happens as soon as a parent opens the list.
  await localNotificationService.initialize();
  // Read the parent's mute and volume choices before the first frame, so a
  // family who silenced the app last night does not get a burst of music
  // while the setting loads.
  await loadSoundSettings();
  runApp(const LittleLearnersApp());
}

/// Brings Firebase up, or explains clearly why it could not.
///
/// A failure here is not fatal: `app.dart` checks `Firebase.apps.isNotEmpty`
/// and falls back to the in-memory repositories, so the app still runs. That
/// fallback is easy to mistake for working Firebase, which is why the reason
/// is printed rather than swallowed.
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: FirebaseWebOptions.resolveOrNull(),
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    await _initializeAdminApp();
  } catch (error) {
    debugPrint('=' * 72);
    debugPrint('Firebase did not start. The app is running on local data only.');
    debugPrint('Reason: $error');
    if (kIsWeb && !FirebaseWebOptions.isConfigured) {
      debugPrint('');
      debugPrint('The web build has no Firebase config. There is no');
      debugPrint('google-services.json equivalent for web, so it must be');
      debugPrint('passed in. Missing: ${FirebaseWebOptions.missingKeys.join(', ')}');
      debugPrint('See docs/FIREBASE_ADMIN_SETUP.md.');
    }
    debugPrint('=' * 72);
  }
}

/// Brings up the secondary app the admin portal runs on.
///
/// Done here, at startup, rather than lazily on sign-in: the admin
/// repositories are built when the provider tree is created, and they need a
/// real Firestore instance on this app at that moment. See [AdminFirebaseApp]
/// for why the default instance will not do.
Future<void> _initializeAdminApp() async {
  try {
    await AdminFirebaseApp.ensureInitialized();
  } catch (error) {
    // Not fatal to the parent/child flow, which uses the default app — but the
    // admin portal cannot work, so say so rather than failing later with a
    // permission error that looks like a Firestore rules problem.
    debugPrint('=' * 72);
    debugPrint('The admin Firebase app did not start, so the admin portal');
    debugPrint('will not be able to read or write anything.');
    debugPrint('Reason: $error');
    debugPrint('=' * 72);
  }
}
