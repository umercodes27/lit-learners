import 'package:firebase_core/firebase_core.dart';

import 'app_config.dart';

/// Whether the app is talking to Firebase, or running on local data.
///
/// `main.dart` treats a failed `Firebase.initializeApp` as non-fatal: the app
/// still runs, on the in-memory repositories, so a missing config is a
/// degraded app rather than no app. The cost is that the fallback looks
/// exactly like the real thing until something reveals it — a parent signing
/// in with Google and landing on a stub account, or a child profile that is
/// gone after a reload.
///
/// So the state is named once, here, and every screen that behaves differently
/// because of it asks the same question.
class FirebaseStatus {
  const FirebaseStatus._();

  static bool get isLive => AppConfig.useFirebase && Firebase.apps.isNotEmpty;

  /// Why a signed-out parent cannot use Google here. Written for the person
  /// running the app, because that is who can fix it.
  static const googleUnavailable =
      'Google sign-in needs Firebase, which is not connected. Run the app '
      'with its Firebase configuration (see docs/FIREBASE_ADMIN_SETUP.md), '
      'or sign in with an email and password to carry on locally.';

  /// The banner shown on the auth screens while local data is all there is.
  static const localOnlyNotice =
      'Not connected to Firebase. Accounts and children stay on this device '
      'and are lost on reload.';
}
