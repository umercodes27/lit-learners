class AppConfig {
  const AppConfig._();

  static const useFirebase = bool.fromEnvironment(
    'USE_FIREBASE',
    defaultValue: true,
  );
}
