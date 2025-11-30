import 'package:flutter_ai_sdk/src/errors/ai_error.dart';

/// Utility class for handling and converting errors from different providers.
///
/// This class provides methods to parse error responses from various AI
/// providers and convert them to appropriate [AIError] subclasses.
class ErrorHandler {
  /// Creates an [ErrorHandler].
  const ErrorHandler();

  /// Parses an error response from OpenAI.
  ///
  /// [statusCode] is the HTTP status code.
  /// [body] is the response body as a map.
  AIError parseOpenAIError(int statusCode, Map<String, dynamic> body) {
    final error = body['error'] as Map<String, dynamic>?;
    final message = error?['message'] as String? ?? 'Unknown error';
    final code = error?['code'] as String?;
    final type = error?['type'] as String?;
    final param = error?['param'] as String?;

    return _createErrorFromStatusCode(
      statusCode: statusCode,
      message: message,
      code: code ?? type,
      parameter: param,
      details: body,
    );
  }

  /// Parses an error response from Anthropic.
  ///
  /// [statusCode] is the HTTP status code.
  /// [body] is the response body as a map.
  AIError parseAnthropicError(int statusCode, Map<String, dynamic> body) {
    final error = body['error'] as Map<String, dynamic>?;
    final message = error?['message'] as String? ?? 'Unknown error';
    final type = error?['type'] as String?;

    return _createErrorFromStatusCode(
      statusCode: statusCode,
      message: message,
      code: type,
      details: body,
    );
  }

  /// Parses an error response from Google AI.
  ///
  /// [statusCode] is the HTTP status code.
  /// [body] is the response body as a map.
  AIError parseGoogleAIError(int statusCode, Map<String, dynamic> body) {
    final error = body['error'] as Map<String, dynamic>?;
    final message = error?['message'] as String? ?? 'Unknown error';
    final code = error?['code']?.toString();
    final status = error?['status'] as String?;

    // Check for safety filtering
    final candidates = body['candidates'] as List<dynamic>?;
    if (candidates != null && candidates.isNotEmpty) {
      final candidate = candidates.first as Map<String, dynamic>;
      final finishReason = candidate['finishReason'] as String?;
      if (finishReason == 'SAFETY') {
        final safetyRatings = candidate['safetyRatings'] as List<dynamic>?;
        final categories = safetyRatings
            ?.map((r) => (r as Map<String, dynamic>)['category'] as String?)
            .whereType<String>()
            .toList();
        return AIContentFilterError(
          message: 'Content was blocked by safety filters',
          code: finishReason,
          categories: categories,
          details: body,
        );
      }
    }

    return _createErrorFromStatusCode(
      statusCode: statusCode,
      message: message,
      code: code ?? status,
      details: body,
    );
  }

  /// Creates an error from network exceptions.
  AIError parseNetworkError(Object error, {bool isTimeout = false}) =>
      AINetworkError(
        message: isTimeout ? 'Request timed out' : error.toString(),
        isTimeout: isTimeout,
        stackTrace: StackTrace.current,
      );

  /// Creates an appropriate error based on HTTP status code.
  AIError _createErrorFromStatusCode({
    required int statusCode,
    required String message,
    String? code,
    String? parameter,
    Map<String, dynamic>? details,
  }) {
    switch (statusCode) {
      case 401:
        return AIAuthenticationError(
          message: message,
          code: code,
          details: details,
        );
      case 429:
        // Try to extract retry-after from details
        final retryAfter = _extractRetryAfter(details);
        return AIRateLimitError(
          message: message,
          code: code,
          details: details,
          retryAfter: retryAfter,
        );
      case 400:
        if (code == 'context_length_exceeded' ||
            message.toLowerCase().contains('context') ||
            message.toLowerCase().contains('token')) {
          return AIContextLengthError(
            message: message,
            code: code,
            details: details,
          );
        }
        return AIInvalidRequestError(
          message: message,
          code: code,
          parameter: parameter,
          details: details,
        );
      case 403:
        return AIAuthenticationError(
          message: message,
          code: code,
          details: details,
        );
      case 404:
        return AIInvalidRequestError(
          message: message,
          code: code,
          details: details,
        );
      case >= 500:
        return AIServerError(
          message: message,
          code: code,
          statusCode: statusCode,
          details: details,
        );
      default:
        return AIUnknownError(
          message: message,
          code: code,
          details: details,
        );
    }
  }

  /// Extracts retry-after duration from error details.
  Duration? _extractRetryAfter(Map<String, dynamic>? details) {
    if (details == null) return null;

    // Try different common locations for retry-after
    final retryAfter = details['retry_after'] ??
        details['retryAfter'] ??
        details['Retry-After'];

    if (retryAfter is int) {
      return Duration(seconds: retryAfter);
    } else if (retryAfter is String) {
      final seconds = int.tryParse(retryAfter);
      if (seconds != null) {
        return Duration(seconds: seconds);
      }
    }

    return null;
  }
}
