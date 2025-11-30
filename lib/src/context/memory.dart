import 'package:flutter_ai_sdk/src/models/models.dart';

/// Memory interface for persisting conversation data.
///
/// Implement this interface to provide custom storage backends
/// for conversation history and context.
///
/// Example:
/// ```dart
/// class LocalStorageMemory implements Memory {
///   @override
///   Future<void> saveConversation(Conversation conversation) async {
///     final json = jsonEncode(conversation.toJson());
///     await localStorage.setString(conversation.id, json);
///   }
///   // ... other methods
/// }
/// ```
abstract interface class Memory {
  /// Saves a conversation.
  Future<void> saveConversation(Conversation conversation);

  /// Loads a conversation by ID.
  Future<Conversation?> loadConversation(String id);

  /// Deletes a conversation by ID.
  Future<bool> deleteConversation(String id);

  /// Lists all conversation IDs.
  Future<List<String>> listConversationIds();

  /// Clears all stored conversations.
  Future<void> clearAll();
}

/// In-memory implementation of [Memory].
///
/// Stores conversations in memory. Data is lost when the app closes.
/// Useful for testing or temporary conversations.
///
/// Example:
/// ```dart
/// final memory = InMemoryMemory();
/// await memory.saveConversation(conversation);
/// ```
class InMemoryMemory implements Memory {
  /// Creates an [InMemoryMemory].
  InMemoryMemory();

  /// Internal storage map.
  final Map<String, Conversation> _storage = {};

  @override
  Future<void> saveConversation(Conversation conversation) async {
    _storage[conversation.id] = conversation;
  }

  @override
  Future<Conversation?> loadConversation(String id) async => _storage[id];

  @override
  Future<bool> deleteConversation(String id) async {
    final existed = _storage.containsKey(id);
    _storage.remove(id);
    return existed;
  }

  @override
  Future<List<String>> listConversationIds() async => _storage.keys.toList();

  @override
  Future<void> clearAll() async {
    _storage.clear();
  }

  /// Gets all stored conversations.
  List<Conversation> get conversations => _storage.values.toList();

  /// Gets the number of stored conversations.
  int get length => _storage.length;
}

/// Memory decorator that limits the number of stored conversations.
///
/// Automatically removes oldest conversations when the limit is exceeded.
///
/// Example:
/// ```dart
/// final memory = LimitedMemory(
///   delegate: InMemoryMemory(),
///   maxConversations: 100,
/// );
/// ```
class LimitedMemory implements Memory {
  /// Creates a [LimitedMemory].
  LimitedMemory({
    required this.delegate,
    this.maxConversations = 100,
  });

  /// The underlying memory implementation.
  final Memory delegate;

  /// Maximum number of conversations to store.
  final int maxConversations;

  /// Tracks conversation order (oldest first).
  final List<String> _order = [];

  @override
  Future<void> saveConversation(Conversation conversation) async {
    // Remove oldest if at capacity
    while (_order.length >= maxConversations) {
      final oldest = _order.removeAt(0);
      await delegate.deleteConversation(oldest);
    }

    // Update order tracking
    _order.remove(conversation.id);
    _order.add(conversation.id);

    await delegate.saveConversation(conversation);
  }

  @override
  Future<Conversation?> loadConversation(String id) async {
    final conversation = await delegate.loadConversation(id);
    if (conversation != null) {
      // Move to end (most recent)
      _order.remove(id);
      _order.add(id);
    }
    return conversation;
  }

  @override
  Future<bool> deleteConversation(String id) async {
    _order.remove(id);
    return delegate.deleteConversation(id);
  }

  @override
  Future<List<String>> listConversationIds() => delegate.listConversationIds();

  @override
  Future<void> clearAll() async {
    _order.clear();
    await delegate.clearAll();
  }
}

/// A conversation with additional metadata for search and filtering.
///
/// Extends [Conversation] with tags, summary, and other metadata
/// useful for organizing and finding conversations.
class IndexedConversation {
  /// Creates an [IndexedConversation].
  IndexedConversation({
    required this.conversation,
    this.tags = const [],
    this.summary,
    this.pinned = false,
    this.archived = false,
  });

  /// The underlying conversation.
  final Conversation conversation;

  /// Tags for categorization.
  final List<String> tags;

  /// AI-generated summary of the conversation.
  final String? summary;

  /// Whether the conversation is pinned.
  final bool pinned;

  /// Whether the conversation is archived.
  final bool archived;

  /// Gets the conversation ID.
  String get id => conversation.id;

  /// Gets the conversation title.
  String? get title => conversation.title;

  /// Gets when the conversation was created.
  DateTime get createdAt => conversation.createdAt;

  /// Gets when the conversation was last updated.
  DateTime get updatedAt => conversation.updatedAt;

  /// Creates a copy with updated fields.
  IndexedConversation copyWith({
    Conversation? conversation,
    List<String>? tags,
    String? summary,
    bool? pinned,
    bool? archived,
  }) =>
      IndexedConversation(
        conversation: conversation ?? this.conversation,
        tags: tags ?? this.tags,
        summary: summary ?? this.summary,
        pinned: pinned ?? this.pinned,
        archived: archived ?? this.archived,
      );

  /// Converts to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
        'conversation': conversation.toJson(),
        'tags': tags,
        if (summary != null) 'summary': summary,
        'pinned': pinned,
        'archived': archived,
      };

  /// Creates from a JSON map.
  factory IndexedConversation.fromJson(Map<String, dynamic> json) =>
      IndexedConversation(
        conversation:
            Conversation.fromJson(json['conversation'] as Map<String, dynamic>),
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        summary: json['summary'] as String?,
        pinned: json['pinned'] as bool? ?? false,
        archived: json['archived'] as bool? ?? false,
      );
}
