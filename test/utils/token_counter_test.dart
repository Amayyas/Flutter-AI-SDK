import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';
import 'package:test/test.dart';

void main() {
  const counter = TokenCounter();

  group('estimateTokens', () {
    test('returns 0 for an empty string', () {
      expect(counter.estimateTokens(''), 0);
    });

    test('grows with text length', () {
      final short = counter.estimateTokens('Hello world');
      final long = counter.estimateTokens('Hello world ' * 50);

      expect(short, greaterThan(0));
      expect(long, greaterThan(short * 10));
    });

    test('roughly matches the 4-characters-per-token heuristic', () {
      // 400 non-whitespace chars → ~100 tokens by chars, ~65 by words.
      final text = List.generate(50, (i) => 'abcdefgh').join(' ');
      final estimate = counter.estimateTokens(text);

      expect(estimate, inInclusiveRange(50, 150));
    });
  });

  group('estimateMessagesTokens', () {
    test('adds per-message and base overhead', () {
      final tokens = counter.estimateMessagesTokens([
        {'role': 'user', 'content': 'Hello'},
      ]);

      // 4 (message overhead) + estimate('Hello') + 3 (base overhead)
      expect(tokens, greaterThanOrEqualTo(8));
    });

    test('counts image parts with fixed costs', () {
      final low = counter.estimateMessagesTokens([
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'detail': 'low'},
            },
          ],
        },
      ]);
      final high = counter.estimateMessagesTokens([
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'detail': 'high'},
            },
          ],
        },
      ]);

      expect(high - low, 765 - 85);
    });
  });

  group('exceedsLimit and truncateToFit', () {
    test('detects when a text exceeds a token limit', () {
      final text = 'word ' * 1000;

      expect(counter.exceedsLimit(text, 10), isTrue);
      expect(counter.exceedsLimit('short', 100), isFalse);
    });

    test('returns text unchanged when it fits', () {
      final result = counter.truncateToFit('short text', 100);

      expect(result.text, 'short text');
    });

    test('truncates text to fit within the limit', () {
      final text = 'word ' * 1000;
      final result = counter.truncateToFit(text, 50);

      expect(result.text.length, lessThan(text.length));
      expect(result.tokens, lessThanOrEqualTo(60));
    });
  });

  group('ModelContextLimits', () {
    test('knows current model context windows', () {
      expect(ModelContextLimits.getLimit('claude-opus-4-8'), 1000000);
      expect(ModelContextLimits.getLimit('claude-haiku-4-5'), 200000);
      expect(ModelContextLimits.getLimit('gpt-5.5'), 400000);
      expect(ModelContextLimits.getLimit('gemini-3.5-flash'), 1048576);
    });

    test('returns null for unknown models', () {
      expect(ModelContextLimits.getLimit('unknown-model'), isNull);
    });
  });
}
