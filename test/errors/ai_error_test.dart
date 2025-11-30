import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('AIError', () {
    group('AINetworkError', () {
      test('creates with message', () {
        const error = AINetworkError(message: 'Connection failed');

        expect(error.message, 'Connection failed');
        expect(error.code, isNull);
        expect(error.isTimeout, isNull);
      });

      test('creates timeout error', () {
        const error = AINetworkError(
          message: 'Request timed out',
          isTimeout: true,
        );

        expect(error.isTimeout, isTrue);
      });

      test('toString includes message', () {
        const error = AINetworkError(message: 'Network error');
        expect(error.toString(), contains('Network error'));
      });

      test('toString indicates timeout', () {
        const error = AINetworkError(message: 'Timeout', isTimeout: true);
        expect(error.toString(), contains('timeout'));
      });
    });

    group('AIAuthenticationError', () {
      test('creates with message', () {
        const error = AIAuthenticationError(message: 'Invalid API key');

        expect(error.message, 'Invalid API key');
      });

      test('creates with code', () {
        const error = AIAuthenticationError(
          message: 'Auth failed',
          code: 'invalid_api_key',
        );

        expect(error.code, 'invalid_api_key');
      });

      test('toString includes message', () {
        const error = AIAuthenticationError(message: 'Auth error');
        expect(error.toString(), contains('Auth error'));
      });
    });

    group('AIRateLimitError', () {
      test('creates with retry after', () {
        const error = AIRateLimitError(
          message: 'Rate limit exceeded',
          retryAfter: Duration(seconds: 60),
        );

        expect(error.message, 'Rate limit exceeded');
        expect(error.retryAfter, const Duration(seconds: 60));
      });

      test('creates without retry after', () {
        const error = AIRateLimitError(message: 'Too many requests');

        expect(error.retryAfter, isNull);
      });

      test('toString includes retry after', () {
        const error = AIRateLimitError(
          message: 'Rate limited',
          retryAfter: Duration(seconds: 30),
        );
        expect(error.toString(), contains('30'));
      });
    });

    group('AIContextLengthError', () {
      test('creates with max tokens', () {
        const error = AIContextLengthError(
          message: 'Context too long',
          maxTokens: 4096,
        );

        expect(error.message, 'Context too long');
        expect(error.maxTokens, 4096);
      });

      test('creates with requested tokens', () {
        const error = AIContextLengthError(
          message: 'Context too long',
          maxTokens: 4096,
          requestedTokens: 5000,
        );

        expect(error.requestedTokens, 5000);
      });

      test('toString includes token info', () {
        const error = AIContextLengthError(
          message: 'Too long',
          maxTokens: 4096,
          requestedTokens: 5000,
        );
        expect(error.toString(), contains('4096'));
      });
    });

    group('AIContentFilterError', () {
      test('creates with categories', () {
        const error = AIContentFilterError(
          message: 'Content blocked',
          categories: ['violence', 'hate'],
        );

        expect(error.message, 'Content blocked');
        expect(error.categories, contains('violence'));
        expect(error.categories, contains('hate'));
      });

      test('creates without categories', () {
        const error = AIContentFilterError(message: 'Filtered');

        expect(error.categories, isNull);
      });

      test('toString includes categories', () {
        const error = AIContentFilterError(
          message: 'Blocked',
          categories: ['violence'],
        );
        expect(error.toString(), contains('violence'));
      });
    });

    group('AIInvalidRequestError', () {
      test('creates with message', () {
        const error = AIInvalidRequestError(
          message: 'Invalid parameter: temperature',
        );

        expect(error.message, 'Invalid parameter: temperature');
      });

      test('creates with parameter', () {
        const error = AIInvalidRequestError(
          message: 'Invalid value',
          parameter: 'temperature',
        );

        expect(error.parameter, 'temperature');
      });

      test('toString includes parameter', () {
        const error = AIInvalidRequestError(
          message: 'Error',
          parameter: 'model',
        );
        expect(error.toString(), contains('model'));
      });
    });

    group('AIServerError', () {
      test('creates with message', () {
        const error = AIServerError(message: 'Internal server error');

        expect(error.message, 'Internal server error');
      });

      test('creates with status code', () {
        const error = AIServerError(
          message: 'Server error',
          statusCode: 500,
        );

        expect(error.statusCode, 500);
      });

      test('toString includes status code', () {
        const error = AIServerError(
          message: 'Error',
          statusCode: 502,
        );
        expect(error.toString(), contains('502'));
      });
    });

    group('AIModelError', () {
      test('creates with message', () {
        const error = AIModelError(message: 'Model error occurred');

        expect(error.message, 'Model error occurred');
      });

      test('creates with finish reason', () {
        const error = AIModelError(
          message: 'Generation stopped',
          finishReason: 'content_filter',
        );

        expect(error.finishReason, 'content_filter');
      });

      test('toString includes finish reason', () {
        const error = AIModelError(
          message: 'Error',
          finishReason: 'length',
        );
        expect(error.toString(), contains('length'));
      });
    });

    group('AIProviderNotSupportedError', () {
      test('creates with provider', () {
        const error = AIProviderNotSupportedError(
          message: 'Provider not supported',
          provider: 'custom-provider',
        );

        expect(error.provider, 'custom-provider');
      });

      test('toString includes provider', () {
        const error = AIProviderNotSupportedError(
          message: 'Error',
          provider: 'unknown',
        );
        expect(error.toString(), contains('unknown'));
      });
    });

    group('AIFeatureNotSupportedError', () {
      test('creates with feature', () {
        const error = AIFeatureNotSupportedError(
          message: 'Feature not available',
          feature: 'vision',
        );

        expect(error.feature, 'vision');
      });

      test('toString includes feature', () {
        const error = AIFeatureNotSupportedError(
          message: 'Error',
          feature: 'streaming',
        );
        expect(error.toString(), contains('streaming'));
      });
    });

    group('AIUnknownError', () {
      test('creates with message', () {
        const error = AIUnknownError(message: 'Unknown error');

        expect(error.message, 'Unknown error');
      });

      test('creates with original error', () {
        final originalError = Exception('Original');
        final error = AIUnknownError(
          message: 'Wrapped error',
          originalError: originalError,
        );

        expect(error.originalError, originalError);
      });

      test('toString includes message', () {
        const error = AIUnknownError(message: 'Something went wrong');
        expect(error.toString(), contains('Something went wrong'));
      });
    });

    group('equality', () {
      test('same errors are equal', () {
        const e1 = AINetworkError(message: 'Error');
        const e2 = AINetworkError(message: 'Error');

        expect(e1, equals(e2));
      });

      test('different messages are not equal', () {
        const e1 = AINetworkError(message: 'Error 1');
        const e2 = AINetworkError(message: 'Error 2');

        expect(e1, isNot(equals(e2)));
      });

      test('different error types are not equal', () {
        const e1 = AINetworkError(message: 'Error');
        const e2 = AIServerError(message: 'Error');

        expect(e1, isNot(equals(e2)));
      });

      test('errors with same message but different codes are not equal', () {
        const e1 = AINetworkError(message: 'Error', code: 'a');
        const e2 = AINetworkError(message: 'Error', code: 'b');

        expect(e1, isNot(equals(e2)));
      });
    });

    group('AIError details', () {
      test('can include details map', () {
        const error = AIServerError(
          message: 'Error',
          details: {'request_id': '12345', 'timestamp': '2024-01-01'},
        );

        expect(error.details, isNotNull);
        expect(error.details!['request_id'], '12345');
      });

      test('can include stack trace', () {
        final stackTrace = StackTrace.current;
        final error = AIUnknownError(
          message: 'Error',
          stackTrace: stackTrace,
        );

        expect(error.stackTrace, isNotNull);
      });
    });
  });
}
