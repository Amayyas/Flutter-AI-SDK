import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_ai_sdk/src/models/content.dart';
import 'package:flutter_ai_sdk/src/models/enums.dart';

/// Represents a message in a conversation.
///
/// Messages are the fundamental unit of communication with AI models.
/// Each message has a role (system, user, assistant, or tool) and content.
///
/// Example:
/// ```dart
/// // Simple text message
/// final message = Message.user('Hello, how are you?');
///
/// // Message with image
/// final imageMessage = Message.user([
///   TextContent('What is in this image?'),
///   ImageContent.fromUrl('https://example.com/image.png'),
/// ]);
///
/// // System message
/// final system = Message.system('You are a helpful assistant.');
/// ```
class Message with EquatableMixin {
  /// Creates a [Message] with the given properties.
  Message({
    String? id,
    required this.role,
    required this.content,
    this.name,
    this.toolCalls,
    DateTime? createdAt,
    this.metadata,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Creates a user message with text content.
  factory Message.user(dynamic content, {String? name}) => Message(
        role: MessageRole.user,
        content: _normalizeContent(content),
        name: name,
      );

  /// Creates an assistant message with text content.
  factory Message.assistant(dynamic content,
          {List<ToolCallContent>? toolCalls}) =>
      Message(
        role: MessageRole.assistant,
        content: _normalizeContent(content),
        toolCalls: toolCalls,
      );

  /// Creates a system message.
  factory Message.system(String content) => Message(
        role: MessageRole.system,
        content: [TextContent(content)],
      );

  /// Creates a tool result message.
  factory Message.toolResult({
    required String toolCallId,
    required String name,
    required dynamic result,
    bool isError = false,
  }) =>
      Message(
        role: MessageRole.tool,
        content: [
          ToolResultContent(
            toolCallId: toolCallId,
            name: name,
            result: result,
            isError: isError,
          ),
        ],
      );

  /// Unique identifier for this message.
  final String id;

  /// The role of this message.
  final MessageRole role;

  /// The content of this message.
  final List<Content> content;

  /// Optional name for the message sender.
  final String? name;

  /// Tool calls made by the assistant (if any).
  final List<ToolCallContent>? toolCalls;

  /// When this message was created.
  final DateTime createdAt;

  /// Optional metadata for the message.
  final Map<String, dynamic>? metadata;

  /// Gets the text content of this message.
  ///
  /// Combines all [TextContent] parts into a single string.
  String get text =>
      content.whereType<TextContent>().map((c) => c.text).join('\n');

  /// Whether this message contains only text.
  bool get isTextOnly => content.every((c) => c.type == ContentType.text);

  /// Whether this message contains images.
  bool get hasImages => content.any((c) => c.type == ContentType.image);

  /// Whether this message contains tool calls.
  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;

  /// Creates a copy of this message with the given fields replaced.
  Message copyWith({
    String? id,
    MessageRole? role,
    List<Content>? content,
    String? name,
    List<ToolCallContent>? toolCalls,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) =>
      Message(
        id: id ?? this.id,
        role: role ?? this.role,
        content: content ?? this.content,
        name: name ?? this.name,
        toolCalls: toolCalls ?? this.toolCalls,
        createdAt: createdAt ?? this.createdAt,
        metadata: metadata ?? this.metadata,
      );

  /// Converts this message to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content.map((c) => c.toJson()).toList(),
        if (name != null) 'name': name,
        if (toolCalls != null)
          'tool_calls': toolCalls!.map((tc) => tc.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      };

  /// Creates a [Message] from a JSON map.
  factory Message.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String;
    final role = MessageRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => MessageRole.user,
    );

    final contentList = json['content'];
    List<Content> content;

    if (contentList is String) {
      content = [TextContent(contentList)];
    } else if (contentList is List) {
      content = contentList
          .map((c) => _parseContent(c as Map<String, dynamic>))
          .toList();
    } else {
      content = [];
    }

    return Message(
      id: json['id'] as String?,
      role: role,
      content: content,
      name: json['name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Normalizes content to a list of [Content].
  static List<Content> _normalizeContent(dynamic content) {
    if (content is String) {
      return [TextContent(content)];
    } else if (content is Content) {
      return [content];
    } else if (content is List<Content>) {
      return content;
    } else if (content is List) {
      return content.map((c) {
        if (c is String) return TextContent(c);
        if (c is Content) return c;
        throw ArgumentError('Invalid content type: ${c.runtimeType}');
      }).toList();
    }
    throw ArgumentError('Invalid content type: ${content.runtimeType}');
  }

  /// Parses a content JSON map to a [Content] object.
  static Content _parseContent(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'text':
        return TextContent(json['text'] as String);
      case 'image_url':
        final imageUrl = json['image_url'] as Map<String, dynamic>;
        return ImageContent.fromUrl(imageUrl['url'] as String);
      case 'tool_call':
        return ToolCallContent(
          id: json['id'] as String,
          name: json['name'] as String,
          arguments: json['arguments'] as Map<String, dynamic>,
        );
      case 'tool_result':
        return ToolResultContent(
          toolCallId: json['tool_call_id'] as String,
          name: json['name'] as String,
          result: json['result'],
          isError: json['is_error'] as bool? ?? false,
        );
      default:
        return TextContent(json['text'] as String? ?? '');
    }
  }

  @override
  List<Object?> get props => [id, role, content, name, toolCalls, metadata];

  @override
  String toString() =>
      'Message(role: $role, content: ${text.length > 50 ? '${text.substring(0, 50)}...' : text})';
}
