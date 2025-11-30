import 'dart:async';
import 'dart:convert';

import 'package:flutter_ai_sdk/src/config/ai_config.dart';
import 'package:flutter_ai_sdk/src/context/context_manager.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/providers/providers.dart';

/// Main entry point for the Flutter AI SDK.
///
/// Provides a unified interface for interacting with multiple AI providers.
/// Supports both simple chat and advanced features like streaming,
/// context management, and multimodal content.
///
/// ## Basic Usage
///
/// ```dart
/// // Initialize with OpenAI
/// final ai = FlutterAI(
///   provider: AIProvider.openai,
///   config: AIConfig(
///     apiKey: 'your-api-key',
///     model: 'gpt-4-turbo',
///   ),
/// );
///
/// // Simple chat
/// final response = await ai.chat('Hello, how are you?');
/// print(response.text);
///
/// // Streaming
/// await for (final chunk in ai.streamChat('Tell me a story')) {
///   print(chunk.delta);
/// }
/// ```
///
/// ## With Context Management
///
/// ```dart
/// final ai = FlutterAI(
///   provider: AIProvider.anthropic,
///   config: AIConfig(
///     apiKey: 'your-api-key',
///     systemPrompt: 'You are a helpful coding assistant.',
///   ),
/// );
///
/// // Multi-turn conversation
/// await ai.chat('What is Dart?');
/// await ai.chat('Can you show me an example?');
/// await ai.chat('How does it compare to JavaScript?');
/// ```
///
/// ## Multimodal Content
///
/// ```dart
/// final ai = FlutterAI(
///   provider: AIProvider.openai,
///   config: AIConfig(
///     apiKey: 'your-api-key',
///     model: 'gpt-4-turbo',
///   ),
/// );
///
/// final response = await ai.chatWithContent([
///   TextContent('What is in this image?'),
///   ImageContent.fromUrl('https://example.com/image.png'),
/// ]);
/// ```
class FlutterAI {
  /// Creates a [FlutterAI] instance.
  ///
  /// [provider] specifies which AI provider to use.
  /// [config] contains API key and other settings.
  FlutterAI({
    required AIProvider provider,
    required AIConfig config,
    ContextManager? contextManager,
  })  : _providerType = provider,
        _config = config,
        _contextManager = contextManager ??
            ContextManager(
              systemPrompt: config.systemPrompt,
              maxTokens: 8000,
            ),
        _provider = _createProvider(provider, config);

  /// The provider type.
  final AIProvider _providerType;

  /// The configuration.
  final AIConfig _config;

  /// The underlying provider.
  final BaseProvider _provider;

  /// The context manager.
  final ContextManager _contextManager;

  /// Gets the provider type.
  AIProvider get provider => _providerType;

  /// Gets the configuration.
  AIConfig get config => _config;

  /// Gets the context manager.
  ContextManager get context => _contextManager;

  /// Gets the current conversation.
  Conversation get conversation => _contextManager.conversation;

  /// Creates the appropriate provider.
  static BaseProvider _createProvider(AIProvider provider, AIConfig config) {
    switch (provider) {
      case AIProvider.openai:
        return OpenAIProvider(config);
      case AIProvider.anthropic:
        return AnthropicProvider(config);
      case AIProvider.googleAI:
        return GoogleAIProvider(config);
    }
  }

  /// Sends a simple text message and gets a response.
  ///
  /// This is the simplest way to interact with the AI.
  /// Messages are automatically added to the conversation context.
  ///
  /// Example:
  /// ```dart
  /// final response = await ai.chat('Hello!');
  /// print(response.text);
  /// ```
  Future<AIResponse> chat(
    String message, {
    bool addToContext = true,
  }) async {
    if (addToContext) {
      _contextManager.addUserMessage(message);
    }

    final messages = _contextManager.getMessagesForRequest();
    final response = await _provider.chat(messages);

    if (addToContext) {
      _contextManager.addAssistantMessage(response.text);
    }

    return response;
  }

  /// Sends content (potentially multimodal) and gets a response.
  ///
  /// Use this for sending images, documents, etc.
  ///
  /// Example:
  /// ```dart
  /// final response = await ai.chatWithContent([
  ///   TextContent('Describe this image'),
  ///   ImageContent.fromUrl('https://...'),
  /// ]);
  /// ```
  Future<AIResponse> chatWithContent(
    List<Content> content, {
    bool addToContext = true,
  }) async {
    final message = Message(
      role: MessageRole.user,
      content: content,
    );

    if (addToContext) {
      _contextManager.addMessage(message);
    }

    final messages = _contextManager.getMessagesForRequest();
    final response = await _provider.chat(messages);

    if (addToContext) {
      _contextManager.addAssistantMessage(response.text);
    }

    return response;
  }

  /// Sends a message with tools/functions available.
  ///
  /// The response may include tool calls that your code should handle.
  ///
  /// Example:
  /// ```dart
  /// final response = await ai.chatWithTools(
  ///   'What is the weather in Paris?',
  ///   tools: [weatherTool],
  /// );
  ///
  /// if (response.hasToolCalls) {
  ///   for (final call in response.toolCalls!) {
  ///     final result = await executeToolCall(call);
  ///     await ai.submitToolResult(
  ///       toolCallId: call.id,
  ///       name: call.name,
  ///       result: result,
  ///     );
  ///   }
  /// }
  /// ```
  Future<AIResponse> chatWithTools(
    String message, {
    required List<Tool> tools,
    ToolChoice? toolChoice,
    bool addToContext = true,
  }) async {
    // Create a modified config with tools
    final toolConfig = _config.copyWith(
      tools: tools,
      toolChoice: toolChoice,
    );

    // Create a temporary provider with the tool config
    final toolProvider = _createProvider(_providerType, toolConfig);

    if (addToContext) {
      _contextManager.addUserMessage(message);
    }

    final messages = _contextManager.getMessagesForRequest();
    final response = await toolProvider.chat(messages);

    // Add assistant response with tool calls to context
    if (addToContext) {
      final assistantMessage = Message.assistant(
        response.text,
        toolCalls: response.toolCalls,
      );
      _contextManager.addMessage(assistantMessage);
    }

    return response;
  }

  /// Submits a tool result back to the model.
  ///
  /// Call this after executing a tool call to continue the conversation.
  ///
  /// Example:
  /// ```dart
  /// final response = await ai.submitToolResult(
  ///   toolCallId: 'call_123',
  ///   name: 'get_weather',
  ///   result: {'temperature': 22, 'condition': 'sunny'},
  /// );
  /// ```
  Future<AIResponse> submitToolResult({
    required String toolCallId,
    required String name,
    required dynamic result,
    bool isError = false,
  }) async {
    _contextManager.addToolResult(
      toolCallId: toolCallId,
      name: name,
      result: result,
      isError: isError,
    );

    final messages = _contextManager.getMessagesForRequest();
    final response = await _provider.chat(messages);

    _contextManager.addAssistantMessage(response.text);

    return response;
  }

  /// Streams a response from the AI.
  ///
  /// Yields chunks as they are generated.
  ///
  /// Example:
  /// ```dart
  /// final buffer = StringBuffer();
  /// await for (final chunk in ai.streamChat('Tell me a story')) {
  ///   if (chunk.isDelta) {
  ///     buffer.write(chunk.delta);
  ///     print(chunk.delta);
  ///   }
  /// }
  /// ```
  Stream<StreamChunk> streamChat(
    String message, {
    bool addToContext = true,
  }) async* {
    if (addToContext) {
      _contextManager.addUserMessage(message);
    }

    final messages = _contextManager.getMessagesForRequest();
    final buffer = StringBuffer();

    await for (final chunk in _provider.streamChat(messages)) {
      if (chunk.isDelta && chunk.delta != null) {
        buffer.write(chunk.delta);
      }
      yield chunk;
    }

    if (addToContext) {
      _contextManager.addAssistantMessage(buffer.toString());
    }
  }

  /// Streams a response with multimodal content.
  ///
  /// Example:
  /// ```dart
  /// await for (final chunk in ai.streamChatWithContent([
  ///   TextContent('Describe this image'),
  ///   ImageContent.fromUrl('https://...'),
  /// ])) {
  ///   print(chunk.delta);
  /// }
  /// ```
  Stream<StreamChunk> streamChatWithContent(
    List<Content> content, {
    bool addToContext = true,
  }) async* {
    final message = Message(
      role: MessageRole.user,
      content: content,
    );

    if (addToContext) {
      _contextManager.addMessage(message);
    }

    final messages = _contextManager.getMessagesForRequest();
    final buffer = StringBuffer();

    await for (final chunk in _provider.streamChat(messages)) {
      if (chunk.isDelta && chunk.delta != null) {
        buffer.write(chunk.delta);
      }
      yield chunk;
    }

    if (addToContext) {
      _contextManager.addAssistantMessage(buffer.toString());
    }
  }

  /// Clears the conversation context.
  void clearContext() {
    _contextManager.clear();
  }

  /// Resets the conversation with an optional new system prompt.
  void reset({String? systemPrompt}) {
    _contextManager.reset(systemPrompt: systemPrompt);
  }

  /// Gets conversation history.
  List<Message> get history => _contextManager.messages;

  /// Disposes resources.
  void dispose() {
    _provider.dispose();
    _contextManager.dispose();
  }
}

/// Extension for convenience methods.
extension FlutterAIExtensions on FlutterAI {
  /// Sends a message and extracts JSON from the response.
  ///
  /// Useful for structured data extraction.
  ///
  /// Example:
  /// ```dart
  /// final data = await ai.chatForJson(
  ///   'Extract the following information as JSON: ...',
  /// );
  /// ```
  Future<Map<String, dynamic>?> chatForJson(
    String message, {
    bool addToContext = true,
  }) async {
    final jsonConfig = _config.copyWith(
      responseFormat: const JsonResponseFormat(),
    );

    final jsonProvider = FlutterAI._createProvider(provider, jsonConfig);

    if (addToContext) {
      context.addUserMessage(message);
    }

    final messages = context.getMessagesForRequest();
    final response = await jsonProvider.chat(messages);

    if (addToContext) {
      context.addAssistantMessage(response.text);
    }

    try {
      // Attempt to parse JSON from response
      final text = response.text.trim();
      // Find JSON object in response
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final jsonStr = text.substring(start, end + 1);
        final decoded = json.decode(jsonStr);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {
      // Return null if parsing fails
    }

    return null;
  }

  /// Generates a summary of the conversation.
  Future<String> summarizeConversation() async {
    final messages = context.messages;
    if (messages.isEmpty) return '';

    final summaryPrompt = '''
Please provide a brief summary of the following conversation:

${messages.map((m) => '${m.role.name}: ${m.text}').join('\n')}

Summary:''';

    final response = await chat(summaryPrompt, addToContext: false);
    return response.text;
  }

  /// Checks if the provider supports a capability.
  bool hasCapability(ModelCapability capability) =>
      (_provider).hasCapability(capability);
}
