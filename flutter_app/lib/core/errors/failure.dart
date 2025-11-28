import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({
    required this.message,
    this.code,
  });

  @override
  List<Object?> get props => [message, code];
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    String message = 'Network error occurred',
    String? code,
  }) : super(message: message, code: code);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({
    String message = 'Request timeout',
    String? code,
  }) : super(message: message, code: code);
}

class AuthenticationFailure extends Failure {
  const AuthenticationFailure({
    String message = 'Authentication failed',
    String? code,
  }) : super(message: message, code: code);
}

class AuthorizationFailure extends Failure {
  const AuthorizationFailure({
    String message = 'Access denied',
    String? code,
  }) : super(message: message, code: code);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({
    String message = 'Resource not found',
    String? code,
  }) : super(message: message, code: code);
}

class ValidationFailure extends Failure {
  final Map<String, String> errors;

  const ValidationFailure({
    String message = 'Validation failed',
    String? code,
    this.errors = const {},
  }) : super(message: message, code: code);

  @override
  List<Object?> get props => [message, code, errors];
}

class ServerFailure extends Failure {
  const ServerFailure({
    String message = 'Server error occurred',
    String? code,
  }) : super(message: message, code: code);
}

class CacheFailure extends Failure {
  const CacheFailure({
    String message = 'Cache error',
    String? code,
  }) : super(message: message, code: code);
}

class UnknownFailure extends Failure {
  const UnknownFailure({
    String message = 'An unknown error occurred',
    String? code,
  }) : super(message: message, code: code);
}
