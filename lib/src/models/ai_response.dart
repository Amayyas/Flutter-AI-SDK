import 'package:equatable/equatable.dart';

import 'package:flutter_ai_sdk/src/models/content.dart';
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
class AIResponse with EquatableMixin {
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

/// Represents a streaming chunk from an AI model.
///
/// Chunks are emitted during streaming responses.
///
/// Example:
/// ```dart
/// await for (final chunk in ai.streamChat('Hello')) {
///   switch (chunk.type) {
///     case StreamEventType.delta:
///       print(chunk.delta);
///       break;
///     case StreamEventType.done:
///       print('Finished: ${chunk.usage}');
///       break;
///   }
/// }
/// ```
class StreamChunk with EquatableMixin {
  /// Creates a [StreamChunk].
  const StreamChunk({
    required this.type,
    this.delta,
    this.toolCallDelta,
    this.finishReason,
    this.usage,
    this.error,
    this.metadata,
  });

  /// Creates a start chunk.
  const StreamChunk.start() : this(type: StreamEventType.start);

  /// Creates a text delta chunk.
  const StreamChunk.delta(String text)
      : this(type: StreamEventType.delta, delta: text);

  /// Creates a tool call chunk.
  const StreamChunk.toolCall(ToolCallContent toolCall)
      : this(type: StreamEventType.toolCallDelta, toolCallDelta: toolCall);

  /// Creates a done chunk.
  const StreamChunk.done({Usage? usage, FinishReason? finishReason})
      : this(
          type: StreamEventType.done,
          finishReason: finishReason,
          usage: usage,
        );

  /// Creates an error chunk.
  const StreamChunk.error(Object error)
      : this(type: StreamEventType.error, error: error);

  /// The type of this streaming event.
  final StreamEventType type;

  /// Text content delta (for text responses).
  final String? delta;

  /// Tool call delta (for tool calls).
  final ToolCallContent? toolCallDelta;

  /// The finish reason (when type is done).
  final FinishReason? finishReason;

  /// Usage statistics (when type is done).
  final Usage? usage;

  /// Error information (when type is error).
  final Object? error;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  /// Whether this is a start event.
  bool get isStart => type == StreamEventType.start;

  /// Whether this is a delta event.
  bool get isDelta => type == StreamEventType.delta;

  /// Whether this is a done event.
  bool get isDone => type == StreamEventType.done;

  /// Whether this is an error event.
  bool get isError => type == StreamEventType.error;

  @override
  List<Object?> get props => [
        type,
        delta,
        toolCallDelta,
        finishReason,
        usage,
        error,
        metadata,
      ];

  @override
  String toString() => switch (type) {
        StreamEventType.start => 'StreamChunk.start()',
        StreamEventType.delta => 'StreamChunk.delta($delta)',
        StreamEventType.done =>
          'StreamChunk.done(reason: $finishReason, tokens: ${usage?.totalTokens})',
        StreamEventType.error => 'StreamChunk.error($error)',
        _ => 'StreamChunk(type: $type)',
      };
}
