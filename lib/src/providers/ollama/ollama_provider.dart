import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/providers/base_provider.dart';
import 'package:flutter_ai_sdk/src/providers/ollama/ollama_mapper.dart';
import 'package:flutter_ai_sdk/src/utils/http_client.dart';

/// Ollama provider implementation for locally hosted models.
///
/// Talks to an Ollama server (default `http://localhost:11434`) using its
/// native chat API, with support for streaming, tool use, JSON mode and
/// vision-capable models.
///
/// No API key is required: pass an empty string (or anything) as [AIConfig]
/// `apiKey`, and set `baseUrl` if the server is not on localhost.
///
/// Example:
/// ```dart
/// final provider = OllamaProvider(
///   AIConfig(
///     apiKey: '',
///     model: 'llama3.1',
///   ),
/// );
///
/// final response = await provider.chat([
///   Message.user('Hello!'),
/// ]);
/// ```
class OllamaProvider extends BaseProvider {
  /// Creates an [OllamaProvider].
  ///
  /// A custom HTTP [client] can be injected, mainly for testing.
  OllamaProvider(super.config, {AIHttpClient? client})
      : _client = client ?? AIHttpClient(config);

  final AIHttpClient _client;

  static const OllamaMapper _mapper = OllamaMapper();

  @override
  AIProvider get providerType => AIProvider.ollama;

  @override
  String get defaultModel => DefaultModels.ollama;

  @override
  Set<ModelCapability> get capabilities => {
        ModelCapability.text,
        ModelCapability.vision,
        ModelCapability.tools,
        ModelCapability.jsonMode,
        ModelCapability.streaming,
        ModelCapability.systemPrompt,
      };

  /// Ollama chat endpoint.
  String get _chatEndpoint {
    final base = config.baseUrl ?? APIEndpoints.ollama;
    return '$base/chat';
  }

  /// Ollama runs locally and does not require an API key.
  @override
  void validateConfig() {}

  @override
  Future<AIResponse> chat(List<Message> messages) async {
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
