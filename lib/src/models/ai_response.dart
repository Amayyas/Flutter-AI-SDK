import 'package:equatable/equatable.dart';

import 'package:flutter_ai_sdk/src/models/content/content.dart';
import 'package:flutter_ai_sdk/src/models/enums.dart';
import 'package:flutter_ai_sdk/src/models/usage.dart';

/// Represents a response from an AI model.
///
/// Contains the generated content, usage statistics, and metadata.
///
/// Example:
/// ```dart
/// final response = await ai.chat('Hello');
/// print(response.content); // Text content
/// print(response.usage.totalTokens); // Token usage
/// ```
class AIResponse with Equatable {
  /// Creates an [AIResponse].
  const AIResponse({
    required this.id,
    required this.content,
    required this.finishReason,
    this.toolCalls,
    this.usage,
    this.model,
    this.provider,
    this.createdAt,
    this.metadata,
  });

  /// Unique identifier for this response.
  final String id;

  /// The generated content.
  final List<Content> content;

  /// The reason the model stopped generating.
  final FinishReason finishReason;

  /// Tool calls made by the model (if any).
  final List<ToolCallContent>? toolCalls;

  /// Token usage statistics.
  final Usage? usage;

  /// The model that generated this response.
  final String? model;

  /// The provider that generated this response.
  final AIProvider? provider;

  /// When this response was created.
  final DateTime? createdAt;

  /// Additional metadata from the provider.
  final Map<String, dynamic>? metadata;

  /// Gets the text content of this response.
  String get text => content.whereType<TextContent>().map((c) => c.text).join();

  /// Whether this response contains tool calls.
  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;

  /// Whether the response was cut off due to max tokens.
  bool get wasMaxTokens => finishReason == FinishReason.maxTokens;

  /// Whether the response was filtered for safety.
  bool get wasFiltered => finishReason == FinishReason.contentFilter;

  /// Creates a copy with updated fields.
  AIResponse copyWith({
    String? id,
    List<Content>? content,
    FinishReason? finishReason,
    List<ToolCallContent>? toolCalls,
    Usage? usage,
    String? model,
    AIProvider? provider,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) =>
      AIResponse(
        id: id ?? this.id,
        content: content ?? this.content,
        finishReason: finishReason ?? this.finishReason,
        toolCalls: toolCalls ?? this.toolCalls,
        usage: usage ?? this.usage,
        model: model ?? this.model,
        provider: provider ?? this.provider,
        createdAt: createdAt ?? this.createdAt,
        metadata: metadata ?? this.metadata,
      );

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content.map((c) => c.toJson()).toList(),
        'finish_reason': finishReason.name,
        if (toolCalls != null)
          'tool_calls': toolCalls!.map((tc) => tc.toJson()).toList(),
        if (usage != null) 'usage': usage!.toJson(),
        if (model != null) 'model': model,
        if (provider != null) 'provider': provider!.name,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      };

  @override
  List<Object?> get props => [
        id,
        content,
        finishReason,
        toolCalls,
        usage,
        model,
        provider,
        metadata,
      ];

  @override
  String toString() =>
      'AIResponse(id: $id, finishReason: $finishReason, tokens: ${usage?.totalTokens})';
}
