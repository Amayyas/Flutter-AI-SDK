import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/providers/base_provider.dart';
import 'package:flutter_ai_sdk/src/providers/google_ai/google_ai_mapper.dart';
import 'package:flutter_ai_sdk/src/utils/http_client.dart';

/// Google AI (Gemini) API provider implementation.
///
/// Supports the Gemini 3.x model family with full
/// support for streaming, multimodal input, and function calling.
///
/// Example:
/// ```dart
/// final provider = GoogleAIProvider(
///   AIConfig(
///     apiKey: 'your-api-key',
///     model: 'gemini-3.5-flash',
///   ),
/// );
///
/// final response = await provider.chat([
///   Message.user('Hello!'),
/// ]);
/// ```
class GoogleAIProvider extends BaseProvider {
  /// Creates a [GoogleAIProvider].
  ///
  /// A custom HTTP [client] can be injected, mainly for testing.
  GoogleAIProvider(super.config, {AIHttpClient? client})
      : _client = client ?? AIHttpClient(config);

  final AIHttpClient _client;

  static const GoogleAIMapper _mapper = GoogleAIMapper();

  @override
  AIProvider get providerType => AIProvider.googleAI;

  @override
  String get defaultModel => DefaultModels.googleAI;

  @override
  Set<ModelCapability> get capabilities => {
        ModelCapability.text,
        ModelCapability.vision,
        ModelCapability.audio,
        ModelCapability.tools,
        ModelCapability.streaming,
        ModelCapability.systemPrompt,
      };

  /// Google AI API endpoint for generating content.
  String get _generateEndpoint {
    final base = config.baseUrl ?? APIEndpoints.googleAI;
    return '$base/models/$model:generateContent?key=${config.apiKey}';
  }

  /// Google AI API endpoint for streaming content.
  String get _streamEndpoint {
    final base = config.baseUrl ?? APIEndpoints.googleAI;
    return '$base/models/$model:streamGenerateContent'
        '?key=${config.apiKey}&alt=sse';
  }

  @override
  Future<AIResponse> chat(List<Message> messages) async {
    validateConfig();

    final body = _mapper.buildRequestBody(messages, config: config);
    final response = await _client.post(_generateEndpoint, body: body);

    return _mapper.parseResponse(
      response.data as Map<String, dynamic>,
      model: model,
    );
  }

  @override
  Stream<String> openStream(List<Message> messages) {
    final body = _mapper.buildRequestBody(messages, config: config);
    return _client.postStream(_streamEndpoint, body: body);
  }

  @override
  StreamChunk? parseStreamChunk(String rawChunk) =>
      _mapper.parseStreamChunk(rawChunk);

  @override
  void dispose() {
    _client.dispose();
  }
}
