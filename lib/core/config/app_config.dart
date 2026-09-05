class AppConfig {
  const AppConfig._();

  static const useFirebase = bool.fromEnvironment(
    'USE_FIREBASE',
    defaultValue: true,
  );

  /// OAuth *Web* client id from the Firebase console. Android reads this from
  /// the generated `default_web_client_id` resource when it is left blank, so
  /// only set it when the generated value is wrong or missing.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// OAuth *iOS* client id. Blank on Android; iOS reads it from
  /// `GoogleService-Info.plist` when left blank.
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  /// OAuth *Web* client id, used when the app runs in a browser.
  ///
  /// The web build has nothing to read this from - there is no
  /// `google-services.json` or plist on web - so Google sign-in in a browser
  /// works only once this is passed in. It is the same Web client id as
  /// [googleServerClientId]; they are separate because web passes it as the
  /// *client*, while Android passes it as the *server* it wants a token for.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
}
