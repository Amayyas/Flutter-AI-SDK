import 'dart:async';

import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/utils/token_counter.dart';

/// Manages conversation context and history.
///
/// The context manager handles:
/// - Message history management
/// - Token counting and truncation
/// - Context window management
/// - Sliding window for long conversations
///
/// Example:
/// ```dart
/// final manager = ContextManager(
///   maxTokens: 8000,
///   systemPrompt: 'You are a helpful assistant.',
/// );
///
/// manager.addUserMessage('Hello!');
/// final messages = manager.getMessages();
/// ```
class ContextManager {
  /// Creates a [ContextManager].
  ContextManager({
    this.maxTokens = 8000,
    this.reservedTokens = 1000,
    this.systemPrompt,
    this.windowStrategy = WindowStrategy.slidingWindow,
  }) : _conversation = Conversation(systemPrompt: systemPrompt);

  /// Maximum tokens for the context window.
  final int maxTokens;

  /// Tokens reserved for the response.
  final int reservedTokens;

  /// System prompt for the conversation.
  final String? systemPrompt;

  /// Strategy for managing context window overflow.
  final WindowStrategy windowStrategy;

  /// The conversation being managed.
  Conversation _conversation;

  /// Token counter for estimation.
  final TokenCounter _tokenCounter = const TokenCounter();

  /// Stream controller for context updates.
  final _updateController = StreamController<ContextUpdate>.broadcast();

  /// Stream of context updates.
  Stream<ContextUpdate> get updates => _updateController.stream;

  /// Gets the current conversation.
  Conversation get conversation => _conversation;

  /// Gets all messages including system prompt.
  List<Message> get messages => _conversation.allMessages;

  /// Gets the estimated token count.
  int get estimatedTokens => _estimateTokens(messages);

  /// Gets the available tokens for the response.
  int get availableTokens => maxTokens - estimatedTokens - reservedTokens;

  /// Adds a user message.
  void addUserMessage(dynamic content, {String? name}) {
    _conversation.addUserMessage(content, name: name);
    _enforceContextLimit();
    _emitUpdate(ContextUpdateType.messageAdded);
  }

  /// Adds an assistant message.
  void addAssistantMessage(dynamic content) {
    _conversation.addAssistantMessage(content);
    _enforceContextLimit();
    _emitUpdate(ContextUpdateType.messageAdded);
  }

  /// Adds a tool result message.
  void addToolResult({
    required String toolCallId,
    required String name,
    required dynamic result,
    bool isError = false,
  }) {
    _conversation.addToolResult(
      toolCallId: toolCallId,
      name: name,
      result: result,
      isError: isError,
    );
    _enforceContextLimit();
    _emitUpdate(ContextUpdateType.messageAdded);
  }

  /// Adds a message directly.
  void addMessage(Message message) {
    _conversation.addMessage(message);
    _enforceContextLimit();
    _emitUpdate(ContextUpdateType.messageAdded);
  }

  /// Removes a message by ID.
  bool removeMessage(String messageId) {
    final removed = _conversation.removeMessage(messageId);
    if (removed) {
      _emitUpdate(ContextUpdateType.messageRemoved);
    }
    return removed;
  }

  /// Clears all messages.
  void clear() {
    _conversation.clear();
    _emitUpdate(ContextUpdateType.cleared);
  }

  /// Resets with a new system prompt.
  void reset({String? systemPrompt}) {
    _conversation =
        Conversation(systemPrompt: systemPrompt ?? this.systemPrompt);
    _emitUpdate(ContextUpdateType.reset);
  }

  /// Gets messages formatted for API requests.
  List<Message> getMessagesForRequest() {
    _enforceContextLimit();
    return messages;
  }

  /// Enforces the context token limit.
  void _enforceContextLimit() {
    final targetTokens = maxTokens - reservedTokens;

    while (estimatedTokens > targetTokens && _conversation.length > 0) {
      switch (windowStrategy) {
        case WindowStrategy.slidingWindow:
          _removeLRUMessage();
        case WindowStrategy.truncateOldest:
          _removeOldestMessage();
        case WindowStrategy.summarize:
          _summarizeOldMessages();
          return; // Summarization handles it differently
      }
    }
  }

  /// Removes the oldest non-system message.
  void _removeOldestMessage() {
    final msgs = _conversation.messages;
    if (msgs.isEmpty) return;

    // Find first non-system message
    final toRemove = msgs.firstWhere(
      (m) => m.role != MessageRole.system,
      orElse: () => msgs.first,
    );

    _conversation.removeMessage(toRemove.id);
    _emitUpdate(ContextUpdateType.messageTruncated);
  }

  /// Removes least recently used messages (pairs if possible).
  void _removeLRUMessage() {
    final msgs = _conversation.messages;
    if (msgs.isEmpty) return;

    // Remove oldest user-assistant pair
    var removed = false;
    for (var i = 0; i < msgs.length; i++) {
      if (msgs[i].role == MessageRole.user) {
        _conversation.removeMessage(msgs[i].id);
        // Also remove following assistant message if exists
        if (i + 1 < msgs.length && msgs[i + 1].role == MessageRole.assistant) {
          _conversation.removeMessage(msgs[i + 1].id);
        }
        removed = true;
        break;
      }
    }

    if (!removed && msgs.isNotEmpty) {
      _conversation.removeMessage(msgs.first.id);
    }

    _emitUpdate(ContextUpdateType.messageTruncated);
  }

  /// Summarizes old messages (placeholder - requires AI call).
  void _summarizeOldMessages() {
    // This would require an AI call to summarize
    // For now, fall back to truncation
    _removeOldestMessage();
  }

  /// Estimates tokens for a list of messages.
  int _estimateTokens(List<Message> messages) {
    var total = 0;
    for (final msg in messages) {
      total += _tokenCounter.estimateTokens(msg.text);
      total += 4; // Overhead per message
    }
    return total;
  }

  /// Emits a context update.
  void _emitUpdate(ContextUpdateType type) {
    _updateController.add(ContextUpdate(
      type: type,
      messageCount: _conversation.length,
      estimatedTokens: estimatedTokens,
    ));
  }

  /// Disposes resources.
  void dispose() {
    _updateController.close();
  }
}

/// Strategy for handling context window overflow.
enum WindowStrategy {
  /// Remove oldest messages to make room.
  slidingWindow,

  /// Truncate oldest messages.
  truncateOldest,

  /// Summarize old messages (requires AI).
  summarize,
}

/// Types of context updates.
enum ContextUpdateType {
  /// A message was added.
  messageAdded,

  /// A message was removed.
  messageRemoved,

  /// A message was truncated for space.
  messageTruncated,

  /// The context was cleared.
  cleared,

  /// The context was reset.
  reset,
}

/// Represents a context update event.
class ContextUpdate {
  /// Creates a [ContextUpdate].
  const ContextUpdate({
    required this.type,
    required this.messageCount,
    required this.estimatedTokens,
  });

  /// The type of update.
  final ContextUpdateType type;

  /// The current message count.
  final int messageCount;

  /// The estimated token count.
  final int estimatedTokens;

  @override
  String toString() =>
      'ContextUpdate(type: $type, messages: $messageCount, tokens: $estimatedTokens)';
}
