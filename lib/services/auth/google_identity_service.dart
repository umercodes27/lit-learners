import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_config.dart';
import '../../repositories/auth_repository.dart';

/// The Google half of Google sign-in, kept separate from Firebase so the
/// Firebase side can be exercised in tests without the platform plugin.
abstract class GoogleIdentityService {
  /// Runs the account chooser and returns the Google ID token, or null when
  /// the parent backs out of the sheet.
  Future<String?> requestIdToken();

  /// Clears the cached Google account so the next sign-in asks again.
  Future<void> signOut();
}

class PluginGoogleIdentityService implements GoogleIdentityService {
  PluginGoogleIdentityService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  Future<void>? _initialization;

  @override
  Future<String?> requestIdToken() async {
    await _ensureInitialized();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw const AuthException(
        'Google sign-in is not available on this platform.',
      );
    }

    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(_missingTokenMessage);
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      // A parent dismissing the sheet is not a failure worth shouting about.
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthException(googleSignInMessageFor(error));
    }
  }

  @override
  Future<void> signOut() async {
    if (_initialization == null) return;
    try {
      await _googleSignIn.signOut();
    } on GoogleSignInException {
      // Signing out of Firebase is what matters; a stale Google cache only
      // means the chooser skips a step next time.
    }
  }

  Future<void> _ensureInitialized() {
    // `initialize` is documented as a once-per-process call, so the future is
    // cached rather than re-run on every button press.
    return _initialization ??= _googleSignIn.initialize(
      clientId: _clientId,
      serverClientId: AppConfig.googleServerClientId.isEmpty
          ? null
          : AppConfig.googleServerClientId,
    );
  }

  /// Which client id this platform identifies itself with.
  ///
  /// Android is the one platform that needs none: the Gradle plugin bakes it
  /// into a resource from `google-services.json`. iOS reads its own from
  /// `GoogleService-Info.plist`, and web has no file to read at all, so in a
  /// browser this has to be passed in or the chooser never opens.
  String? get _clientId {
    const id = kIsWeb
        ? AppConfig.googleWebClientId
        : AppConfig.googleIosClientId;
    return id.isEmpty ? null : id;
  }
}

String googleSignInMessageFor(GoogleSignInException error) {
  return switch (error.code) {
    GoogleSignInExceptionCode.canceled => 'Google sign-in was cancelled.',
    GoogleSignInExceptionCode.interrupted =>
      'Google sign-in was interrupted. Please try again.',
    GoogleSignInExceptionCode.uiUnavailable =>
      'Google sign-in could not open. Please try again.',
    GoogleSignInExceptionCode.clientConfigurationError ||
    GoogleSignInExceptionCode.providerConfigurationError =>
      _setupMessage,
    GoogleSignInExceptionCode.userMismatch =>
      'Sign out of the other Google account first.',
    GoogleSignInExceptionCode.unknownError =>
      error.description ?? 'Google sign-in failed. Please try again.',
  };
}

const _missingTokenMessage =
    'Google did not return an ID token. Check that the Web client ID '
    '(serverClientId) is set for this app in the Firebase console.';

const _setupMessage =
    'Google sign-in is not configured yet. In Firebase Console, open '
    'Authentication > Sign-in method and enable Google, then add this app\'s '
    'SHA-1 and SHA-256 fingerprints and re-download google-services.json.';
