class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;
  final StackTrace? stackTrace;

  AppException({
    required this.message,
    this.code,
    this.originalException,
    this.stackTrace,
  });

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException({
    String message = 'Network error occurred',
    String? code,
    dynamic originalException,
    StackTrace? stackTrace,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
    stackTrace: stackTrace,
  );
}

class TimeoutException extends AppException {
  TimeoutException({
    String message = 'Request timeout',
    String? code,
    dynamic originalException,
    StackTrace? stackTrace,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
    stackTrace: stackTrace,
  );
}

class AuthenticationException extends AppException {
  AuthenticationException({
    String message = 'Authentication failed',
    String? code,
    dynamic originalException,
    StackTrace? stackTrace,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
    stackTrace: stackTrace,
  );
}

class AuthorizationException extends AppException {
  AuthorizationException({
    String message = 'Access denied',
    String? code,
    dynamic originalException,
    StackTrace? stackTrace,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
    stackTrace: stackTrace,
  );
}

class NotFoundException extends AppException {
  NotFoundException({
    String message = 'Resource not found',
    String? code,
    dynamic originalException,
    StackTrace? stackTrace,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
    stackTrace: stackTrace,
  );
}

class ValidationException extends AppException {
  final Map<String, String> errors;

  ValidationException({
    String message = 'Validation failed',
    String? code,
    this.errors = const {},
    dynamic originalException,
    StackTrace? stackTrace,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
    stackTrace: stackTrace,
  );
}

class ServerException extends AppException {
  ServerException({
    String message = 'Server error occurred',
    String? code,
    dynamic originalException,
    StackTrace? stackTrace,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
    stackTrace: stackTrace,
  );
}

class CacheException extends AppException {
  CacheException({
    String message = 'Cache error',
    String? code,
    dynamic originalException,
    StackTrace? stackTrace,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
    stackTrace: stackTrace,
  );
}
