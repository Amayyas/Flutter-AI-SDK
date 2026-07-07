import 'package:equatable/equatable.dart';

import 'package:flutter_ai_sdk/src/models/content/content.dart';
import 'package:flutter_ai_sdk/src/models/enums.dart';
import 'package:flutter_ai_sdk/src/models/usage.dart';

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
class StreamChunk with Equatable {
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
