import 'flavors.dart';

class AppConfig {
  static const String appName = 'LabLink';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  static const int requestTimeout = 30000; // milliseconds
  static const int cacheExpiration = 3600; // seconds

  static String get supabaseUrl => FlavorConfig.instance.supabaseUrl;
  static String get supabaseAnonKey => FlavorConfig.instance.supabaseAnonKey;
  static bool get enableSentry => FlavorConfig.instance.enableSentry;
  static String get sentryDsn => FlavorConfig.instance.sentryDsn;
  static String get flavorName => FlavorConfig.instance.name;
  static bool get isDev => FlavorConfig.instance.isDev;
  static bool get isStaging => FlavorConfig.instance.isStaging;
  static bool get isProd => FlavorConfig.instance.isProd;

  // Feature Flags
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  static const bool enableDebugLogging = true;
}
