import 'package:flutter_ai_sdk/src/config/ai_config.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';

/// Base class for AI providers.
///
/// Defines the contract that all provider implementations must follow.
/// Each provider handles communication with a specific AI service.
///
/// Example:
/// ```dart
/// class CustomProvider extends BaseProvider {
///   CustomProvider(super.config);
///
///   @override
///   AIProvider get providerType => AIProvider.custom;
///
///   @override
///   Future<AIResponse> chat(List<Message> messages) async {
///     // Implementation
///   }
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
  Stream<StreamChunk> streamChat(List<Message> messages);

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
