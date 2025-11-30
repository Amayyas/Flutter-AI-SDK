import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:flutter_ai_sdk/src/config/ai_config.dart';
import 'package:flutter_ai_sdk/src/errors/errors.dart';

/// HTTP client for making API requests to AI providers.
///
/// Handles authentication, error handling, retry logic, and streaming.
///
/// Example:
/// ```dart
/// final client = AIHttpClient(config);
/// final response = await client.post(
///   'https://api.openai.com/v1/chat/completions',
///   body: {'model': 'gpt-4', ...},
/// );
/// ```
class AIHttpClient {
  /// Creates an [AIHttpClient] with the given configuration.
  AIHttpClient(this.config) : _dio = _createDio(config);

  /// The configuration.
  final AIConfig config;

  /// The underlying Dio client.
  final Dio _dio;

  /// Error handler for parsing errors.
  final ErrorHandler _errorHandler = const ErrorHandler();

  /// Creates a configured Dio instance.
  static Dio _createDio(AIConfig config) {
    final dio = Dio(BaseOptions(
      connectTimeout: config.timeout ?? const Duration(seconds: 30),
      receiveTimeout: config.timeout ?? const Duration(minutes: 5),
      sendTimeout: config.timeout ?? const Duration(minutes: 2),
      headers: {
        'Content-Type': 'application/json',
        ...?config.headers,
      },
    ));

    // Add authorization header if not already in custom headers
    if (config.headers?['Authorization'] == null &&
        config.headers?['x-api-key'] == null) {
      dio.options.headers['Authorization'] = 'Bearer ${config.apiKey}';
    }

    return dio;
  }

  /// Makes a POST request.
  ///
  /// [url] is the endpoint URL.
  /// [body] is the request body.
  /// [headers] are optional additional headers.
  Future<Response<dynamic>> post(
    String url, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        url,
        data: body,
        options: Options(headers: headers),
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Makes a streaming POST request.
  ///
  /// [url] is the endpoint URL.
  /// [body] is the request body.
  /// [headers] are optional additional headers.
  ///
  /// Yields raw SSE chunks as strings.
  Stream<String> postStream(
    String url, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        url,
        data: body,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
      );

      final stream = response.data!.stream;
      final buffer = StringBuffer();

      await for (final chunk in stream) {
        final text = utf8.decode(chunk);
        buffer.write(text);

        // Process complete lines
        final lines = buffer.toString().split('\n');
        buffer.clear();

        for (var i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isNotEmpty) {
            yield line;
          }
        }

        // Keep incomplete line in buffer
        if (lines.last.isNotEmpty) {
          buffer.write(lines.last);
        }
      }

      // Yield any remaining content
      if (buffer.isNotEmpty) {
        yield buffer.toString().trim();
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Makes a GET request.
  Future<Response<dynamic>> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        url,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Handles Dio exceptions and converts them to AI errors.
  AIError _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return _errorHandler.parseNetworkError(e, isTimeout: true);

      case DioExceptionType.connectionError:
        return _errorHandler.parseNetworkError(e);

      case DioExceptionType.badResponse:
        final response = e.response;
        if (response == null) {
          return AIUnknownError(
            message: e.message ?? 'Unknown error',
            originalError: e,
          );
        }

        final statusCode = response.statusCode ?? 500;
        final data = response.data;

        Map<String, dynamic> body;
        if (data is Map<String, dynamic>) {
          body = data;
        } else if (data is String) {
          try {
            body = jsonDecode(data) as Map<String, dynamic>;
          } catch (_) {
            body = {
              'error': {'message': data}
            };
          }
        } else {
          body = {
            'error': {'message': 'Unknown error'}
          };
        }

        // Determine provider from URL
        final url = e.requestOptions.uri.toString();
        if (url.contains('openai.com')) {
          return _errorHandler.parseOpenAIError(statusCode, body);
        } else if (url.contains('anthropic.com')) {
          return _errorHandler.parseAnthropicError(statusCode, body);
        } else if (url.contains('googleapis.com') ||
            url.contains('generativelanguage')) {
          return _errorHandler.parseGoogleAIError(statusCode, body);
        }

        // Generic error handling
        return _errorHandler.parseOpenAIError(statusCode, body);

      case DioExceptionType.cancel:
        return const AINetworkError(message: 'Request cancelled');

      default:
        return AIUnknownError(
          message: e.message ?? 'Unknown error',
          originalError: e,
        );
    }
  }

  /// Closes the client and releases resources.
  void dispose() {
    _dio.close();
  }
}

/// Extension for making requests with retry logic.
extension RetryExtension on AIHttpClient {
  /// Makes a POST request with automatic retry on transient errors.
  ///
  /// [maxRetries] is the maximum number of retry attempts.
  /// [retryDelay] is the base delay between retries (exponential backoff).
  Future<Response<dynamic>> postWithRetry(
    String url, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    var attempt = 0;
    while (true) {
      try {
        return await post(url, body: body, headers: headers);
      } on AIError catch (e) {
        attempt++;

        // Don't retry auth errors or invalid requests
        if (e is AIAuthenticationError ||
            e is AIInvalidRequestError ||
            e is AIContentFilterError) {
          rethrow;
        }

        // Don't retry if we've exhausted attempts
        if (attempt >= maxRetries) {
          rethrow;
        }

        // Calculate delay with exponential backoff
        final delay = retryDelay * (1 << (attempt - 1));

        // Handle rate limit with server-provided retry-after
        if (e is AIRateLimitError && e.retryAfter != null) {
          await Future<void>.delayed(e.retryAfter!);
        } else {
          await Future<void>.delayed(delay);
        }
      }
    }
  }
}
