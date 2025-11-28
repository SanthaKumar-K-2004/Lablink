class AppConstants {
  // App Info
  static const String appName = 'LabLink';
  static const String appVersion = '1.0.0';

  // Timeouts
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration animationDuration = Duration(milliseconds: 200);

  // Pagination
  static const int itemsPerPage = 50;
  static const int maxRetries = 3;

  // Cache Duration
  static const Duration cacheDuration = Duration(hours: 1);

  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int minNameLength = 2;
  static const int maxNameLength = 100;
}
