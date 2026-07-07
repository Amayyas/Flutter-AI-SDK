import 'package:equatable/equatable.dart';

import 'package:flutter_ai_sdk/src/config/response_format.dart';
import 'package:flutter_ai_sdk/src/models/tools/tools.dart';

/// Configuration for AI requests.
///
/// Contains all settings for interacting with AI providers.
///
/// Example:
/// ```dart
/// final config = AIConfig(
///   apiKey: 'your-api-key',
///   model: 'gpt-5.5',
///   maxTokens: 4096,
///   temperature: 0.7,
///   systemPrompt: 'You are a helpful assistant.',
/// );
/// ```
class AIConfig with Equatable {
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

  /// The model to use (e.g., 'gpt-5.5', 'claude-opus-4-8').
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
