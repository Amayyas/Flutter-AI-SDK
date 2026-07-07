import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/providers/base_provider.dart';
import 'package:flutter_ai_sdk/src/providers/openai/openai_mapper.dart';
import 'package:flutter_ai_sdk/src/utils/http_client.dart';

/// OpenAI API provider implementation.
///
/// Supports GPT-5.x and other OpenAI models with full
/// support for streaming, vision, and function calling.
///
/// Example:
/// ```dart
/// final provider = OpenAIProvider(
///   AIConfig(
///     apiKey: 'sk-...',
///     model: 'gpt-5.5',
///   ),
/// );
///
/// final response = await provider.chat([
///   Message.user('Hello!'),
/// ]);
/// ```
class OpenAIProvider extends BaseProvider {
  /// Creates an [OpenAIProvider].
  ///
  /// A custom HTTP [client] can be injected, mainly for testing.
  OpenAIProvider(super.config, {AIHttpClient? client})
      : _client = client ?? AIHttpClient(config);

  final AIHttpClient _client;

  static const OpenAIMapper _mapper = OpenAIMapper();

  @override
  AIProvider get providerType => AIProvider.openai;

  @override
  String get defaultModel => DefaultModels.openai;

  @override
  Set<ModelCapability> get capabilities => {
        ModelCapability.text,
        ModelCapability.vision,
        ModelCapability.tools,
        ModelCapability.jsonMode,
        ModelCapability.streaming,
        ModelCapability.systemPrompt,
      };

  /// OpenAI API endpoint for chat completions.
  String get _chatEndpoint {
    final base = config.baseUrl ?? APIEndpoints.openai;
    return '$base/chat/completions';
  }

  @override
  Future<AIResponse> chat(List<Message> messages) async {
    validateConfig();

    final body = _mapper.buildRequestBody(
      messages,
      config: config,
      model: model,
      stream: false,
    );
    final response = await _client.post(_chatEndpoint, body: body);

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
    return _client.postStream(_chatEndpoint, body: body);
  }

  @override
  StreamChunk? parseStreamChunk(String rawChunk) =>
      _mapper.parseStreamChunk(rawChunk);

  @override
  void dispose() {
    _client.dispose();
  }
}
