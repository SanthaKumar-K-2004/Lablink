class ErrorMessages {
  // Network Errors
  static const String networkError = 'Network error. Please check your connection.';
  static const String timeoutError = 'Request timeout. Please try again.';
  static const String serverError = 'Server error. Please try again later.';
  static const String notFoundError = 'Resource not found.';

  // Authentication Errors
  static const String invalidCredentials = 'Invalid email or password.';
  static const String userNotFound = 'User not found.';
  static const String emailAlreadyExists = 'Email already registered.';
  static const String weakPassword = 'Password is too weak.';
  static const String sessionExpired = 'Session expired. Please login again.';
  static const String unauthorizedAccess = 'You do not have permission to access this resource.';

  // Validation Errors
  static const String emptyEmail = 'Email is required.';
  static const String invalidEmail = 'Invalid email address.';
  static const String emptyPassword = 'Password is required.';
  static const String passwordTooShort = 'Password must be at least 8 characters.';
  static const String emptyName = 'Name is required.';
  static const String emptyField = 'This field is required.';

  // Generic Errors
  static const String unknownError = 'An unknown error occurred.';
  static const String tryAgainLater = 'Please try again later.';
  static const String noInternetConnection = 'No internet connection.';
}
