/// Simple token counter for estimating token usage.
///
/// This is a rough estimation and may not match exact provider counts.
/// For precise counts, use the usage data returned in responses.
class TokenCounter {
  /// Creates a [TokenCounter].
  const TokenCounter();

  /// Estimates the number of tokens in a string.
  ///
  /// This is a rough approximation. Different models use different
  /// tokenizers, so actual counts may vary.
  ///
  /// Approximation rules:
  /// - 1 token ≈ 4 characters for English text
  /// - 1 token ≈ ¾ words
  int estimateTokens(String text) {
    if (text.isEmpty) return 0;

    // Count characters (excluding whitespace for more accuracy)
    final nonWhitespace = text.replaceAll(RegExp(r'\s+'), '');

    // Use character-based estimation (roughly 4 chars per token)
    final charEstimate = (nonWhitespace.length / 4).ceil();

    // Word-based estimation for comparison
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final wordEstimate = (words * 1.3).ceil();

    // Return average of both methods
    return ((charEstimate + wordEstimate) / 2).ceil();
  }

  /// Estimates tokens for a list of messages.
  int estimateMessagesTokens(List<Map<String, dynamic>> messages) {
    var total = 0;

    for (final message in messages) {
      // Add overhead for message structure (role, etc.)
      total += 4; // Approximate overhead per message

      final content = message['content'];
      if (content is String) {
        total += estimateTokens(content);
      } else if (content is List) {
        for (final part in content) {
          if (part is Map && part['type'] == 'text') {
            total += estimateTokens(part['text'] as String? ?? '');
          } else if (part is Map && part['type'] == 'image_url') {
            // Images use a fixed token count depending on detail level
            final detail = (part['image_url'] as Map?)?['detail'];
            total += detail == 'high' ? 765 : 85;
          }
        }
      }
    }

    // Add base overhead
    total += 3; // Every reply is primed with <|start|>assistant<|message|>

    return total;
  }

  /// Checks if the estimated tokens exceed a limit.
  bool exceedsLimit(String text, int maxTokens) =>
      estimateTokens(text) > maxTokens;

  /// Truncates text to fit within a token limit.
  ///
  /// Returns the truncated text and actual estimated tokens.
  ({String text, int tokens}) truncateToFit(String text, int maxTokens) {
    final estimated = estimateTokens(text);
    if (estimated <= maxTokens) {
      return (text: text, tokens: estimated);
    }

    // Estimate characters per token
    final charsPerToken = text.length / estimated;
    final targetChars = (maxTokens * charsPerToken * 0.9).floor();

    // Find a good break point (word boundary)
    var truncated = text.substring(0, targetChars.clamp(0, text.length));
    final lastSpace = truncated.lastIndexOf(' ');
    if (lastSpace > targetChars * 0.8) {
      truncated = truncated.substring(0, lastSpace);
    }

    return (text: truncated, tokens: estimateTokens(truncated));
  }
}

/// Model context limits.
///
/// Contains maximum context lengths for various models.
class ModelContextLimits {
  ModelContextLimits._();

  /// OpenAI model limits.
  static const Map<String, int> openai = {
    'gpt-5.5': 400000,
    'gpt-5.4': 400000,
    'gpt-5.4-mini': 400000,
    'gpt-5.4-nano': 400000,
    'gpt-5.1': 400000,
    'gpt-5': 400000,
    // Legacy models (deprecated by OpenAI)
    'gpt-4o': 128000,
    'gpt-4o-mini': 128000,
    'gpt-4-turbo': 128000,
    'gpt-4': 8192,
    'gpt-3.5-turbo': 16385,
  };

  /// Anthropic model limits.
  static const Map<String, int> anthropic = {
    'claude-opus-4-8': 1000000,
    'claude-opus-4-7': 1000000,
    'claude-opus-4-6': 1000000,
    'claude-sonnet-5': 1000000,
    'claude-sonnet-4-6': 1000000,
    'claude-haiku-4-5': 200000,
    // Legacy models
    'claude-opus-4-5': 200000,
    'claude-sonnet-4-5': 200000,
  };

  /// Google AI model limits.
  static const Map<String, int> googleAI = {
    'gemini-3.5-flash': 1048576, // 1M tokens
    'gemini-3.1-pro-preview': 1048576,
    'gemini-3.1-flash-lite': 1048576,
    // Legacy models
    'gemini-2.5-pro': 1048576,
    'gemini-2.5-flash': 1048576,
  };

  /// Gets the context limit for a model.
  static int? getLimit(String model) =>
      openai[model] ?? anthropic[model] ?? googleAI[model];
}
