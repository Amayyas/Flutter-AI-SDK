import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/models/enums.dart';
import 'package:flutter_ai_sdk/src/providers/anthropic/anthropic_provider.dart';
import 'package:flutter_ai_sdk/src/providers/base_provider.dart';
import 'package:flutter_ai_sdk/src/providers/google_ai/google_ai_provider.dart';
import 'package:flutter_ai_sdk/src/providers/ollama/ollama_provider.dart';
import 'package:flutter_ai_sdk/src/providers/openai/openai_provider.dart';

/// Signature for a function that builds a provider from a configuration.
typedef ProviderFactory = BaseProvider Function(AIConfig config);

/// Registry of provider factories (factory pattern).
///
/// Maps each [AIProvider] to the factory that builds its implementation.
/// The built-in providers are pre-registered; [register] allows swapping
/// an implementation (e.g. a fake in tests, or a custom subclass).
///
/// Example:
/// ```dart
/// final provider = ProviderRegistry.create(
///   AIProvider.anthropic,
///   AIConfig(apiKey: 'sk-ant-...'),
/// );
/// ```
class ProviderRegistry {
  ProviderRegistry._();

  static final Map<AIProvider, ProviderFactory> _factories = {
    AIProvider.openai: OpenAIProvider.new,
    AIProvider.anthropic: AnthropicProvider.new,
    AIProvider.googleAI: GoogleAIProvider.new,
    AIProvider.ollama: OllamaProvider.new,
  };

  /// Creates a provider instance for [provider] with [config].
  ///
  /// Throws an [ArgumentError] if no factory is registered.
  static BaseProvider create(AIProvider provider, AIConfig config) {
    final factory = _factories[provider];
    if (factory == null) {
      throw ArgumentError('No factory registered for provider $provider');
    }
    return factory(config);
  }

  /// Registers (or replaces) the factory for [provider].
  static void register(AIProvider provider, ProviderFactory factory) {
    _factories[provider] = factory;
  }
}
