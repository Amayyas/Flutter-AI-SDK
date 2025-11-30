import 'package:flutter_ai_sdk/src/models/message.dart';
import 'package:uuid/uuid.dart';

/// Represents a conversation with an AI model.
///
/// A conversation is a collection of messages exchanged between
/// the user, the system, and the AI assistant.
///
/// Example:
/// ```dart
/// final conversation = Conversation(
///   systemPrompt: 'You are a helpful assistant.',
/// );
///
/// conversation.addUserMessage('Hello!');
/// final response = await ai.chat(conversation: conversation);
/// conversation.addAssistantMessage(response.content);
/// ```
class Conversation {
  /// Creates a [Conversation] with optional initial configuration.
  Conversation({
    String? id,
    this.title,
    this.systemPrompt,
    List<Message>? messages,
    DateTime? createdAt,
    this.metadata,
  })  : id = id ?? const Uuid().v4(),
        _messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        _updatedAt = DateTime.now();

  /// Unique identifier for this conversation.
  final String id;

  /// Optional title for this conversation.
  final String? title;

  /// System prompt for this conversation.
  final String? systemPrompt;

  /// Internal list of messages.
  final List<Message> _messages;

  /// When this conversation was created.
  final DateTime createdAt;

  /// Internal updated timestamp.
  DateTime _updatedAt;

  /// When this conversation was last updated.
  DateTime get updatedAt => _updatedAt;

  /// Optional metadata for the conversation.
  final Map<String, dynamic>? metadata;

  /// Gets an unmodifiable view of the messages.
  List<Message> get messages => List.unmodifiable(_messages);

  /// Gets all messages including the system message.
  List<Message> get allMessages {
    if (systemPrompt == null || systemPrompt!.isEmpty) {
      return messages;
    }
    return [
      Message.system(systemPrompt!),
      ...messages,
    ];
  }

  /// The number of messages in this conversation.
  int get length => _messages.length;

  /// Whether this conversation is empty.
  bool get isEmpty => _messages.isEmpty;

  /// Whether this conversation has messages.
  bool get isNotEmpty => _messages.isNotEmpty;

  /// The last message in this conversation.
  Message? get lastMessage => _messages.isNotEmpty ? _messages.last : null;

  /// Adds a message to this conversation.
  void addMessage(Message message) {
    _messages.add(message);
    _updatedAt = DateTime.now();
  }

  /// Adds a user message to this conversation.
  void addUserMessage(dynamic content, {String? name}) {
    addMessage(Message.user(content, name: name));
  }

  /// Adds an assistant message to this conversation.
  void addAssistantMessage(dynamic content) {
    addMessage(Message.assistant(content));
  }

  /// Adds a tool result message to this conversation.
  void addToolResult({
    required String toolCallId,
    required String name,
    required dynamic result,
    bool isError = false,
  }) {
    addMessage(Message.toolResult(
      toolCallId: toolCallId,
      name: name,
      result: result,
      isError: isError,
    ));
  }

  /// Removes a message by ID.
  bool removeMessage(String messageId) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages.removeAt(index);
      _updatedAt = DateTime.now();
      return true;
    }
    return false;
  }

  /// Clears all messages (except system prompt).
  void clear() {
    _messages.clear();
    _updatedAt = DateTime.now();
  }

  /// Gets the last N messages.
  List<Message> getLastMessages(int count) {
    if (count >= _messages.length) return messages;
    return _messages.sublist(_messages.length - count);
  }

  /// Truncates the conversation to the last N messages.
  void truncate(int maxMessages) {
    if (_messages.length > maxMessages) {
      _messages.removeRange(0, _messages.length - maxMessages);
      _updatedAt = DateTime.now();
    }
  }

  /// Creates a copy of this conversation.
  Conversation copyWith({
    String? id,
    String? title,
    String? systemPrompt,
    List<Message>? messages,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) =>
      Conversation(
        id: id ?? this.id,
        title: title ?? this.title,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        messages: messages ?? List.from(_messages),
        createdAt: createdAt ?? this.createdAt,
        metadata: metadata ?? this.metadata,
      );

  /// Converts this conversation to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
        'id': id,
        if (title != null) 'title': title,
        if (systemPrompt != null) 'system_prompt': systemPrompt,
        'messages': _messages.map((m) => m.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      };

  /// Creates a [Conversation] from a JSON map.
  factory Conversation.fromJson(Map<String, dynamic> json) {
    final messagesList = json['messages'] as List<dynamic>?;
    final messages = messagesList
        ?.map((m) => Message.fromJson(m as Map<String, dynamic>))
        .toList();

    return Conversation(
      id: json['id'] as String?,
      title: json['title'] as String?,
      systemPrompt: json['system_prompt'] as String?,
      messages: messages,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Conversation(id: $id, title: $title, messages: ${_messages.length})';
}
