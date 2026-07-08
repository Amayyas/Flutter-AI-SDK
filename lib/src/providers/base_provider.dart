import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/utils/token_counter.dart';
import 'package:meta/meta.dart';

/// Base class for AI providers.
///
/// Defines the contract that all provider implementations must follow.
/// Each provider handles communication with a specific AI service.
///
/// Streaming follows the template method pattern: [streamChat] implements
/// the shared accumulation loop, while subclasses provide the transport
/// via [openStream] and the wire-format decoding via [parseStreamChunk].
///
/// Example:
/// ```dart
/// class CustomProvider extends BaseProvider {
///   CustomProvider(super.config);
///
///   @override
///   Future<AIResponse> chat(List<Message> messages) async {
///     // Implementation
///   }
///
///   // ... openStream, parseStreamChunk, metadata getters
/// }
/// ```
abstract class BaseProvider {
  /// Creates a [BaseProvider] with the given configuration.
  BaseProvider(this.config);

  /// The configuration for this provider.
  final AIConfig config;

  /// The type of this provider.
  AIProvider get providerType;

  /// The default model for this provider.
  String get defaultModel;

  /// Supported capabilities of this provider.
  Set<ModelCapability> get capabilities;

  /// Sends a chat completion request.
  ///
  /// [messages] is the list of messages in the conversation.
  /// Returns an [AIResponse] with the model's response.
  Future<AIResponse> chat(List<Message> messages);

  /// Streams a chat completion response.
  ///
  /// [messages] is the list of messages in the conversation.
  /// Yields [StreamChunk] objects as the response is generated.
  ///
  /// This is a template method: it validates the configuration, opens the
  /// provider-specific stream via [openStream], decodes each raw chunk via
  /// [parseStreamChunk], and always terminates with a final done chunk that
  /// carries the accumulated finish reason and usage.
  Stream<StreamChunk> streamChat(List<Message> messages) async* {
    validateConfig();

    yield const StreamChunk.start();

    FinishReason? finishReason;
    Usage? usage;

    await for (final rawChunk in openStream(messages)) {
      final parsed = parseStreamChunk(rawChunk);
      if (parsed == null) continue;

      if (parsed.finishReason != null) {
        finishReason = parsed.finishReason;
      }
      if (parsed.usage != null) {
        usage = parsed.usage;
      }
      yield parsed;
    }

    yield StreamChunk.done(
      usage: usage,
      finishReason: finishReason ?? FinishReason.stop,
    );
  }

  /// Opens the provider-specific raw stream for [messages].
  ///
  /// Yields raw wire-format chunks (e.g. SSE lines) to be decoded by
  /// [parseStreamChunk].
  @protected
  Stream<String> openStream(List<Message> messages);

  /// Decodes a raw wire-format chunk into a [StreamChunk].
  ///
  /// Returns null for chunks that carry no event (comments, keep-alives...).
  @protected
  StreamChunk? parseStreamChunk(String rawChunk);

  /// Counts the tokens the provider would read for [messages].
  ///
  /// The default implementation is a local heuristic estimation; providers
  /// with a native token counting endpoint (Anthropic, Google AI) override
  /// it with an exact server-side count.
  Future<int> countTokens(List<Message> messages) async {
    const counter = TokenCounter();
    return counter.estimateMessagesTokens([
      for (final message in messages)
        {'role': message.role.name, 'content': message.text},
    ]);
  }

  /// Checks if a capability is supported.
  bool hasCapability(ModelCapability capability) =>
      capabilities.contains(capability);

  /// Gets the model to use, falling back to default.
  String get model => config.model ?? defaultModel;

  /// Validates the configuration for this provider.
  void validateConfig() {
    if (config.apiKey.isEmpty) {
      throw ArgumentError('API key is required');
    }
  }

  /// Closes any resources held by this provider.
  void dispose() {}
}
