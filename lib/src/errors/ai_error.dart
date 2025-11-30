import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Base class for all AI SDK errors.
///
/// All errors in the SDK inherit from this class, providing a consistent
/// interface for error handling across all operations.
///
/// Example:
/// ```dart
/// try {
///   await ai.chat('Hello');
/// } on AIError catch (e) {
///   print('Error: ${e.message}');
///   print('Code: ${e.code}');
/// }
/// ```
@immutable
sealed class AIError extends Equatable implements Exception {
  /// Creates an [AIError] with the given [message] and optional [code].
  const AIError({
    required this.message,
    this.code,
    this.details,
    this.stackTrace,
  });

  /// Human-readable error message.
  final String message;

  /// Optional error code from the provider.
  final String? code;

  /// Additional details about the error.
  final Map<String, dynamic>? details;

  /// Stack trace when the error occurred.
  final StackTrace? stackTrace;

  @override
  List<Object?> get props => [message, code, details];

  @override
  String toString() =>
      'AIError: $message${code != null ? ' (code: $code)' : ''}';
}

/// Error thrown when authentication fails.
///
/// This usually indicates an invalid or expired API key.
///
/// Example:
/// ```dart
/// try {
///   await ai.chat('Hello');
/// } on AIAuthenticationError catch (e) {
///   print('Please check your API key');
/// }
/// ```
@immutable
final class AIAuthenticationError extends AIError {
  /// Creates an [AIAuthenticationError].
  const AIAuthenticationError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
  });

  @override
  String toString() => 'AIAuthenticationError: $message';
}

/// Error thrown when the rate limit is exceeded.
///
/// Contains information about when to retry the request.
///
/// Example:
/// ```dart
/// try {
///   await ai.chat('Hello');
/// } on AIRateLimitError catch (e) {
///   await Future.delayed(e.retryAfter ?? Duration(seconds: 60));
///   // Retry the request
/// }
/// ```
@immutable
final class AIRateLimitError extends AIError {
  /// Creates an [AIRateLimitError].
  const AIRateLimitError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
    this.retryAfter,
  });

  /// Duration to wait before retrying.
  final Duration? retryAfter;

  @override
  List<Object?> get props => [...super.props, retryAfter];

  @override
  String toString() =>
      'AIRateLimitError: $message${retryAfter != null ? ' (retry after: ${retryAfter!.inSeconds}s)' : ''}';
}

/// Error thrown when the request is invalid.
///
/// This indicates a problem with the request parameters.
@immutable
final class AIInvalidRequestError extends AIError {
  /// Creates an [AIInvalidRequestError].
  const AIInvalidRequestError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
    this.parameter,
  });

  /// The parameter that caused the error.
  final String? parameter;

  @override
  List<Object?> get props => [...super.props, parameter];

  @override
  String toString() =>
      'AIInvalidRequestError: $message${parameter != null ? ' (parameter: $parameter)' : ''}';
}

/// Error thrown when there's a network issue.
///
/// This includes connection timeouts, DNS failures, etc.
@immutable
final class AINetworkError extends AIError {
  /// Creates an [AINetworkError].
  const AINetworkError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
    this.isTimeout,
  });

  /// Whether the error was caused by a timeout.
  final bool? isTimeout;

  @override
  List<Object?> get props => [...super.props, isTimeout];

  @override
  String toString() =>
      'AINetworkError: $message${isTimeout == true ? ' (timeout)' : ''}';
}

/// Error thrown when the server returns an error.
///
/// This indicates a problem on the provider's side.
@immutable
final class AIServerError extends AIError {
  /// Creates an [AIServerError].
  const AIServerError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
    this.statusCode,
  });

  /// HTTP status code.
  final int? statusCode;

  @override
  List<Object?> get props => [...super.props, statusCode];

  @override
  String toString() =>
      'AIServerError: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

/// Error thrown when the model returns an unexpected response.
///
/// This includes content filtering, model overload, etc.
@immutable
final class AIModelError extends AIError {
  /// Creates an [AIModelError].
  const AIModelError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
    this.finishReason,
  });

  /// The reason the model stopped generating.
  final String? finishReason;

  @override
  List<Object?> get props => [...super.props, finishReason];

  @override
  String toString() =>
      'AIModelError: $message${finishReason != null ? ' (reason: $finishReason)' : ''}';
}

/// Error thrown when content is blocked by safety filters.
@immutable
final class AIContentFilterError extends AIError {
  /// Creates an [AIContentFilterError].
  const AIContentFilterError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
    this.categories,
  });

  /// Categories that triggered the filter.
  final List<String>? categories;

  @override
  List<Object?> get props => [...super.props, categories];

  @override
  String toString() =>
      'AIContentFilterError: $message${categories != null ? ' (categories: ${categories!.join(', ')})' : ''}';
}

/// Error thrown when the context is too long.
@immutable
final class AIContextLengthError extends AIError {
  /// Creates an [AIContextLengthError].
  const AIContextLengthError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
    this.maxTokens,
    this.requestedTokens,
  });

  /// Maximum allowed tokens.
  final int? maxTokens;

  /// Number of tokens requested.
  final int? requestedTokens;

  @override
  List<Object?> get props => [...super.props, maxTokens, requestedTokens];

  @override
  String toString() =>
      'AIContextLengthError: $message (max: $maxTokens, requested: $requestedTokens)';
}

/// Error thrown when the provider is not supported.
@immutable
final class AIProviderNotSupportedError extends AIError {
  /// Creates an [AIProviderNotSupportedError].
  const AIProviderNotSupportedError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
    this.provider,
  });

  /// The unsupported provider name.
  final String? provider;

  @override
  List<Object?> get props => [...super.props, provider];

  @override
  String toString() =>
      'AIProviderNotSupportedError: $message${provider != null ? ' (provider: $provider)' : ''}';
}

/// Error thrown when a feature is not supported.
@immutable
final class AIFeatureNotSupportedError extends AIError {
  /// Creates an [AIFeatureNotSupportedError].
  const AIFeatureNotSupportedError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
    this.feature,
  });

  /// The unsupported feature name.
  final String? feature;

  @override
  List<Object?> get props => [...super.props, feature];

  @override
  String toString() =>
      'AIFeatureNotSupportedError: $message${feature != null ? ' (feature: $feature)' : ''}';
}

/// Generic error for unexpected issues.
@immutable
final class AIUnknownError extends AIError {
  /// Creates an [AIUnknownError].
  const AIUnknownError({
    required super.message,
    super.code,
    super.details,
    super.stackTrace,
    this.originalError,
  });

  /// The original error that caused this error.
  final Object? originalError;

  @override
  List<Object?> get props => [...super.props, originalError];

  @override
  String toString() => 'AIUnknownError: $message';
}
