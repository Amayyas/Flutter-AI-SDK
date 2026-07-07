import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/providers/anthropic/anthropic_mapper.dart';
import 'package:flutter_ai_sdk/src/providers/base_provider.dart';
import 'package:flutter_ai_sdk/src/utils/http_client.dart';

/// Anthropic (Claude) API provider implementation.
///
/// Supports current Claude models (Opus, Sonnet, Haiku) with full
/// support for streaming, vision, and tool use.
///
/// Note: recent Claude models (Opus 4.7+, Sonnet 5) reject the sampling
/// parameters `temperature`, `topP` and the penalty parameters — leave them
/// unset in [AIConfig] when targeting those models.
///
/// Example:
/// ```dart
/// final provider = AnthropicProvider(
///   AIConfig(
///     apiKey: 'sk-ant-...',
///     model: 'claude-opus-4-8',
///   ),
/// );
///
/// final response = await provider.chat([
///   Message.user('Hello!'),
/// ]);
/// ```
class AnthropicProvider extends BaseProvider {
  /// Creates an [AnthropicProvider].
  ///
  /// A custom HTTP [client] can be injected, mainly for testing.
  AnthropicProvider(super.config, {AIHttpClient? client})
      : _client = client ?? AIHttpClient(config);

  final AIHttpClient _client;

  static const AnthropicMapper _mapper = AnthropicMapper();

  /// Current Anthropic API version.
  static const String apiVersion = '2023-06-01';

  @override
  AIProvider get providerType => AIProvider.anthropic;

  @override
  String get defaultModel => DefaultModels.anthropic;

  @override
  Set<ModelCapability> get capabilities => {
        ModelCapability.text,
        ModelCapability.vision,
        ModelCapability.tools,
        ModelCapability.streaming,
        ModelCapability.systemPrompt,
      };

  /// Anthropic API endpoint for messages.
  String get _messagesEndpoint {
    final base = config.baseUrl ?? APIEndpoints.anthropic;
    return '$base/messages';
  }

  /// Custom headers for Anthropic API.
  Map<String, String> get _headers => {
        'x-api-key': config.apiKey,
        'anthropic-version': apiVersion,
        'content-type': 'application/json',
        ...?config.headers,
      };

  @override
  Future<AIResponse> chat(List<Message> messages) async {
    validateConfig();

    final body = _mapper.buildRequestBody(
      messages,
      config: config,
      model: model,
      stream: false,
    );
    final response = await _client.post(
      _messagesEndpoint,
      body: body,
      headers: _headers,
    );

    return _mapper.parseResponse(response.data as Map<String, dynamic>);
  }

  @override
  Stream<String> openStream(List<Message> messages) {
    final body = _mapper.buildRequestBody(
      messages,
      config: config,
      model: model,
      stream: true,
    );
    return _client.postStream(
      _messagesEndpoint,
      body: body,
      headers: _headers,
    );
  }

  @override
  StreamChunk? parseStreamChunk(String rawChunk) =>
      _mapper.parseStreamChunk(rawChunk);

  @override
  void dispose() {
    _client.dispose();
  }
}
