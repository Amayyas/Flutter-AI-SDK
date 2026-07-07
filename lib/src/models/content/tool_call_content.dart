part of 'content.dart';

/// Tool call content.
///
/// Represents a request from the model to call a tool/function.
///
/// Example:
/// ```dart
/// final toolCall = ToolCallContent(
///   id: 'call_abc123',
///   name: 'get_weather',
///   arguments: {'location': 'Paris', 'unit': 'celsius'},
/// );
/// ```
final class ToolCallContent extends Content {
  /// Creates a [ToolCallContent].
  const ToolCallContent({
    required this.id,
    required this.name,
    required this.arguments,
  }) : super(type: ContentType.toolCall);

  /// Unique identifier for this tool call.
  final String id;

  /// Name of the tool/function to call.
  final String name;

  /// Arguments to pass to the tool.
  final Map<String, dynamic> arguments;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'tool_call',
        'id': id,
        'name': name,
        'arguments': arguments,
      };

  @override
  List<Object?> get props => [type, id, name, arguments];

  @override
  String toString() => 'ToolCallContent($name, args: $arguments)';
}
