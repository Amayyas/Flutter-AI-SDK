import 'package:equatable/equatable.dart';

import 'package:flutter_ai_sdk/src/models/enums.dart';
import 'package:flutter_ai_sdk/src/models/tool.dart';

/// Configuration for AI requests.
///
/// Contains all settings for interacting with AI providers.
///
/// Example:
/// ```dart
/// final config = AIConfig(
///   apiKey: 'your-api-key',
///   model: 'gpt-4-turbo',
///   maxTokens: 4096,
///   temperature: 0.7,
///   systemPrompt: 'You are a helpful assistant.',
/// );
/// ```
class AIConfig with EquatableMixin {
  /// Creates an [AIConfig].
  const AIConfig({
    required this.apiKey,
    this.model,
    this.maxTokens,
    this.temperature,
    this.topP,
    this.frequencyPenalty,
    this.presencePenalty,
    this.stopSequences,
    this.systemPrompt,
    this.tools,
    this.toolChoice,
    this.responseFormat,
    this.baseUrl,
    this.timeout,
    this.headers,
    this.metadata,
  });

  /// API key for authentication.
  final String apiKey;

  /// The model to use (e.g., 'gpt-4', 'claude-3-opus').
  final String? model;

  /// Maximum number of tokens to generate.
  final int? maxTokens;

  /// Sampling temperature (0.0 to 2.0).
  ///
  /// Higher values make output more random.
  final double? temperature;

  /// Top-p (nucleus) sampling parameter.
  ///
  /// Alternative to temperature sampling.
  final double? topP;

  /// Frequency penalty (-2.0 to 2.0).
  ///
  /// Reduces repetition of frequent tokens.
  final double? frequencyPenalty;

  /// Presence penalty (-2.0 to 2.0).
  ///
  /// Reduces repetition of any tokens that have appeared.
  final double? presencePenalty;

  /// Sequences where the model should stop generating.
  final List<String>? stopSequences;

  /// System prompt for the conversation.
  final String? systemPrompt;

  /// Tools available to the model.
  final List<Tool>? tools;

  /// How the model should use tools.
  final ToolChoice? toolChoice;

  /// Response format configuration.
  final ResponseFormat? responseFormat;

  /// Custom base URL for the API.
  final String? baseUrl;

  /// Request timeout.
  final Duration? timeout;

  /// Custom headers to include in requests.
  final Map<String, String>? headers;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  /// Creates a copy with updated fields.
  AIConfig copyWith({
    String? apiKey,
    String? model,
    int? maxTokens,
    double? temperature,
    double? topP,
    double? frequencyPenalty,
    double? presencePenalty,
    List<String>? stopSequences,
    String? systemPrompt,
    List<Tool>? tools,
    ToolChoice? toolChoice,
    ResponseFormat? responseFormat,
    String? baseUrl,
    Duration? timeout,
    Map<String, String>? headers,
    Map<String, dynamic>? metadata,
  }) =>
      AIConfig(
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        maxTokens: maxTokens ?? this.maxTokens,
        temperature: temperature ?? this.temperature,
        topP: topP ?? this.topP,
        frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
        presencePenalty: presencePenalty ?? this.presencePenalty,
        stopSequences: stopSequences ?? this.stopSequences,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        tools: tools ?? this.tools,
        toolChoice: toolChoice ?? this.toolChoice,
        responseFormat: responseFormat ?? this.responseFormat,
        baseUrl: baseUrl ?? this.baseUrl,
        timeout: timeout ?? this.timeout,
        headers: headers ?? this.headers,
        metadata: metadata ?? this.metadata,
      );

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
        'model': model,
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (temperature != null) 'temperature': temperature,
        if (topP != null) 'top_p': topP,
        if (frequencyPenalty != null) 'frequency_penalty': frequencyPenalty,
        if (presencePenalty != null) 'presence_penalty': presencePenalty,
        if (stopSequences != null) 'stop': stopSequences,
        if (systemPrompt != null) 'system_prompt': systemPrompt,
        if (tools != null) 'tools': tools!.map((t) => t.toJson()).toList(),
        if (responseFormat != null) 'response_format': responseFormat!.toJson(),
      };

  @override
  List<Object?> get props => [
        apiKey,
        model,
        maxTokens,
        temperature,
        topP,
        frequencyPenalty,
        presencePenalty,
        stopSequences,
        systemPrompt,
        tools,
        toolChoice,
        responseFormat,
        baseUrl,
        timeout,
        headers,
        metadata,
      ];
}

/// Response format configuration.
///
/// Controls the format of the model's output.
sealed class ResponseFormat with EquatableMixin {
  /// Creates a [ResponseFormat].
  const ResponseFormat();

  /// Text response format (default).
  const factory ResponseFormat.text() = TextResponseFormat;

  /// JSON response format.
  const factory ResponseFormat.json({Map<String, dynamic>? schema}) =
      JsonResponseFormat;

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson();
}

/// Text response format.
final class TextResponseFormat extends ResponseFormat {
  /// Creates a [TextResponseFormat].
  const TextResponseFormat();

  @override
  Map<String, dynamic> toJson() => {'type': 'text'};

  @override
  List<Object?> get props => [];
}

/// JSON response format.
final class JsonResponseFormat extends ResponseFormat {
  /// Creates a [JsonResponseFormat].
  const JsonResponseFormat({this.schema});

  /// Optional JSON schema for structured output.
  final Map<String, dynamic>? schema;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'json_object',
        if (schema != null) 'schema': schema,
      };

  @override
  List<Object?> get props => [schema];
}

/// Default models for each provider.
class DefaultModels {
  DefaultModels._();

  /// Default OpenAI model.
  static const String openai = 'gpt-4-turbo';

  /// Default Anthropic model.
  static const String anthropic = 'claude-3-5-sonnet-latest';

  /// Default Google AI model.
  static const String googleAI = 'gemini-1.5-pro';

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
