import 'package:flutter_ai_sdk/src/models/enums.dart';

/// Default models for each provider.
class DefaultModels {
  DefaultModels._();

  /// Default OpenAI model.
  static const String openai = 'gpt-5.5';

  /// Default Anthropic model.
  static const String anthropic = 'claude-opus-4-8';

  /// Default Google AI model.
  static const String googleAI = 'gemini-3.5-flash';

  /// Gets the default model for a provider.
  static String forProvider(AIProvider provider) => switch (provider) {
        AIProvider.openai => openai,
        AIProvider.anthropic => anthropic,
        AIProvider.googleAI => googleAI,
      };
}

/// API endpoints for each provider.
class APIEndpoints {
  APIEndpoints._();

  /// OpenAI API base URL.
  static const String openai = 'https://api.openai.com/v1';

  /// Anthropic API base URL.
  static const String anthropic = 'https://api.anthropic.com/v1';

  /// Google AI API base URL.
  static const String googleAI =
      'https://generativelanguage.googleapis.com/v1beta';

  /// Gets the default endpoint for a provider.
  static String forProvider(AIProvider provider) => switch (provider) {
        AIProvider.openai => openai,
        AIProvider.anthropic => anthropic,
        AIProvider.googleAI => googleAI,
      };
}
