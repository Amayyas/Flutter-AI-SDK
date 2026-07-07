part of 'content.dart';

/// Tool result content.
///
/// Contains the result of a tool/function call.
///
/// Example:
/// ```dart
/// final result = ToolResultContent(
///   toolCallId: 'call_abc123',
///   name: 'get_weather',
///   result: {'temperature': 22, 'condition': 'sunny'},
/// );
/// ```
final class ToolResultContent extends Content {
  /// Creates a [ToolResultContent].
  const ToolResultContent({
    required this.toolCallId,
    required this.name,
    required this.result,
    this.isError = false,
  }) : super(type: ContentType.toolResult);

  /// The ID of the tool call this is responding to.
  final String toolCallId;

  /// Name of the tool/function.
  final String name;

  /// The result of the tool call (can be any JSON-serializable value).
  final dynamic result;

  /// Whether this result represents an error.
  final bool isError;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'tool_result',
        'tool_call_id': toolCallId,
        'name': name,
        'result': result,
        'is_error': isError,
      };

  @override
  List<Object?> get props => [type, toolCallId, name, result, isError];

  @override
  String toString() => 'ToolResultContent($name: $result)';
}
