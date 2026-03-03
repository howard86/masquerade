/// Base exception class for the application
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(this.message, {this.code, this.originalError});

  @override
  String toString() {
    return 'AppException: $message${code != null ? ' (Code: $code)' : ''}';
  }
}

/// Network-related exceptions
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.originalError});

  factory NetworkException.fromDioException(dynamic dioException) {
    return NetworkException(
      dioException.message ?? 'Network error occurred',
      code: dioException.response?.statusCode?.toString(),
      originalError: dioException,
    );
  }
}

/// Server-related exceptions
class ServerException extends AppException {
  const ServerException(super.message, {super.code, super.originalError});

  factory ServerException.fromStatusCode(int statusCode, String message) {
    return ServerException(message, code: statusCode.toString());
  }
}

/// Validation-related exceptions
class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.originalError});

  factory ValidationException.fromField(String field, String message) {
    return ValidationException(
      'Validation failed for $field: $message',
      code: 'VALIDATION_ERROR',
    );
  }
}

/// Authentication-related exceptions
class AuthenticationException extends AppException {
  const AuthenticationException(
    super.message, {
    super.code,
    super.originalError,
  });

  factory AuthenticationException.unauthorized() {
    return const AuthenticationException(
      'User is not authenticated',
      code: 'UNAUTHORIZED',
    );
  }

  factory AuthenticationException.expired() {
    return const AuthenticationException(
      'Authentication token has expired',
      code: 'TOKEN_EXPIRED',
    );
  }
}

/// Authorization-related exceptions
class AuthorizationException extends AppException {
  const AuthorizationException(
    super.message, {
    super.code,
    super.originalError,
  });

  factory AuthorizationException.forbidden() {
    return const AuthorizationException(
      'User does not have permission to perform this action',
      code: 'FORBIDDEN',
    );
  }
}

/// Cache-related exceptions
class CacheException extends AppException {
  const CacheException(super.message, {super.code, super.originalError});

  factory CacheException.notFound(String key) {
    return CacheException(
      'Cache entry not found for key: $key',
      code: 'CACHE_NOT_FOUND',
    );
  }
}

/// Unknown exceptions
class UnknownException extends AppException {
  const UnknownException(super.message, {super.code, super.originalError});

  factory UnknownException.fromError(dynamic error) {
    return UnknownException(
      error.toString(),
      code: 'UNKNOWN_ERROR',
      originalError: error,
    );
  }
}

/// Result class for handling success and failure states
class Result<T> {
  final T? data;
  final AppException? error;

  const Result._(this.data, this.error);

  factory Result.success(T data) => Result._(data, null);
  factory Result.failure(AppException error) => Result._(null, error);

  bool get isSuccess => error == null;
  bool get isFailure => error != null;

  T get value {
    if (isSuccess) return data as T;
    throw error!;
  }

  Result<R> map<R>(R Function(T) mapper) {
    if (isSuccess) {
      return Result.success(mapper(data as T));
    } else {
      return Result.failure(error!);
    }
  }

  Result<T> mapError(AppException Function(AppException) mapper) {
    if (isFailure) {
      return Result.failure(mapper(error!));
    } else {
      return Result.success(data as T);
    }
  }
}
