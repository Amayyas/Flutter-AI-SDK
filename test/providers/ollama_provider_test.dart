import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockAIHttpClient extends Mock implements AIHttpClient {}

/// Formats an event as an NDJSON line (Ollama streams NDJSON, not SSE).
String ndjson(Map<String, dynamic> event) => jsonEncode(event);

Response<dynamic> jsonResponse(Map<String, dynamic> data) => Response<dynamic>(
      requestOptions: RequestOptions(),
      data: data,
      statusCode: 200,
    );

Map<String, dynamic> ollamaResponse({
  Map<String, dynamic>? message,
  String doneReason = 'stop',
}) =>
    {
      'model': 'llama3.1',
      'created_at': '2026-07-07T10:00:00.000Z',
      'message': message ?? {'role': 'assistant', 'content': 'Hello!'},
      'done': true,
      'done_reason': doneReason,
      'prompt_eval_count': 10,
      'eval_count': 5,
    };

void main() {
  late MockAIHttpClient client;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    client = MockAIHttpClient();
  });

  OllamaProvider buildProvider(AIConfig config) =>
      OllamaProvider(config, client: client);

  void stubPost([Map<String, dynamic>? data]) {
    when(
      () => client.post(
        any(),
        body: any(named: 'body'),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer((_) async => jsonResponse(data ?? ollamaResponse()));
  }

  /// Runs a chat and returns the captured request body.
  Future<Map<String, dynamic>> capturedBody(
    AIConfig config, {
    List<Message>? messages,
  }) async {
    stubPost();
    final provider = buildProvider(config);
    await provider.chat(messages ?? [Message.user('Hi')]);
    final captured = verify(
      () => client.post(
        any(),
        body: captureAny(named: 'body'),
        headers: any(named: 'headers'),
      ),
    ).captured;
    return captured.single as Map<String, dynamic>;
  }

  group('OllamaProvider metadata', () {
    test('exposes provider type, default model and capabilities', () {
      final provider = buildProvider(const AIConfig(apiKey: ''));

      expect(provider.providerType, AIProvider.ollama);
      expect(provider.defaultModel, DefaultModels.ollama);
      expect(provider.hasCapability(ModelCapability.tools), isTrue);
      expect(provider.hasCapability(ModelCapability.vision), isTrue);
      expect(provider.hasCapability(ModelCapability.jsonMode), isTrue);
    });

    test('does not require an API key', () async {
      stubPost();
      final provider = buildProvider(const AIConfig(apiKey: ''));

      final response = await provider.chat([Message.user('Hi')]);

      expect(response.text, 'Hello!');
    });
  });

  group('request building', () {
    test('targets the local chat endpoint by default', () async {
      stubPost();
      final provider = buildProvider(const AIConfig(apiKey: ''));
      await provider.chat([Message.user('Hi')]);

      final url = verify(
        () => client.post(
          captureAny(),
          body: any(named: 'body'),
          headers: any(named: 'headers'),
        ),
      ).captured.single;
      expect(url, 'http://localhost:11434/api/chat');
    });

    test('honours a custom base URL', () async {
      stubPost();
      final provider = buildProvider(
        const AIConfig(apiKey: '', baseUrl: 'http://192.168.1.10:11434/api'),
      );
      await provider.chat([Message.user('Hi')]);

      final url = verify(
        () => client.post(
          captureAny(),
          body: any(named: 'body'),
          headers: any(named: 'headers'),
        ),
      ).captured.single;
      expect(url, 'http://192.168.1.10:11434/api/chat');
    });

    test('maps generation parameters into options', () async {
      final body = await capturedBody(
        const AIConfig(
          apiKey: '',
          maxTokens: 256,
          temperature: 0.7,
          topP: 0.9,
          stopSequences: ['END'],
        ),
      );

      final options = body['options'] as Map<String, dynamic>;
      expect(options['num_predict'], 256);
      expect(options['temperature'], 0.7);
      expect(options['top_p'], 0.9);
      expect(options['stop'], ['END']);
    });

    test('omits options when nothing is configured', () async {
      final body = await capturedBody(const AIConfig(apiKey: ''));

      expect(body.containsKey('options'), isFalse);
      expect(body['model'], DefaultModels.ollama);
      expect(body['stream'], isFalse);
    });

    test('requests JSON format when configured', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: '', responseFormat: JsonResponseFormat()),
      );

      expect(body['format'], 'json');
    });

    test('formats tools with the OpenAI function schema', () async {
      final tool = Tool(
        name: 'get_weather',
        description: 'Get the weather',
        parameters: ToolParameters(
          properties: {'city': ToolProperty.string(description: 'City')},
          required: const ['city'],
        ),
      );
      final body = await capturedBody(AIConfig(apiKey: '', tools: [tool]));

      final tools = body['tools'] as List<dynamic>;
      final first = tools.single as Map<String, dynamic>;
      expect(first['type'], 'function');
      final function = first['function'] as Map<String, dynamic>;
      expect(function['name'], 'get_weather');
    });
  });

  group('message formatting', () {
    test('formats text messages with plain content', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: ''),
        messages: [Message.system('Be brief.'), Message.user('Hi')],
      );

      final messages = body['messages'] as List<dynamic>;
      expect(messages.first, {'role': 'system', 'content': 'Be brief.'});
      expect(messages.last, {'role': 'user', 'content': 'Hi'});
    });

    test('formats base64 images in the images array', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: ''),
        messages: [
          Message(
            role: MessageRole.user,
            content: const [
              TextContent('Describe this'),
              ImageContent.fromBase64('aGVsbG8=', mimeType: 'image/png'),
            ],
          ),
        ],
      );

      final messages = body['messages'] as List<dynamic>;
      final message = messages.single as Map<String, dynamic>;
      expect(message['content'], 'Describe this');
      expect(message['images'], ['aGVsbG8=']);
    });

    test('serializes assistant tool calls', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: ''),
        messages: [
          Message.assistant(
            'Checking...',
            toolCalls: const [
              ToolCallContent(
                id: 'call_1',
                name: 'get_weather',
                arguments: {'city': 'Paris'},
              ),
            ],
          ),
        ],
      );

      final messages = body['messages'] as List<dynamic>;
      final toolCalls = (messages.single as Map<String, dynamic>)['tool_calls']
          as List<dynamic>;
      final function = (toolCalls.single as Map<String, dynamic>)['function']
          as Map<String, dynamic>;
      expect(function['name'], 'get_weather');
      expect(function['arguments'], {'city': 'Paris'});
    });

    test('formats tool results as tool role messages', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: ''),
        messages: [
          Message.toolResult(
            toolCallId: 'call_1',
            name: 'get_weather',
            result: {'temp': 20},
          ),
        ],
      );

      final messages = body['messages'] as List<dynamic>;
      final toolMessage = messages.single as Map<String, dynamic>;
      expect(toolMessage['role'], 'tool');
      expect(toolMessage['tool_name'], 'get_weather');
      expect(toolMessage['content'], '{"temp":20}');
    });
  });

  group('response parsing', () {
    test('parses text content, usage and metadata', () async {
      stubPost();
      final provider = buildProvider(const AIConfig(apiKey: ''));
      final response = await provider.chat([Message.user('Hi')]);

      expect(response.text, 'Hello!');
      expect(response.model, 'llama3.1');
      expect(response.provider, AIProvider.ollama);
      expect(response.finishReason, FinishReason.stop);
      expect(response.usage?.promptTokens, 10);
      expect(response.usage?.completionTokens, 5);
      expect(response.createdAt, DateTime.parse('2026-07-07T10:00:00.000Z'));
    });

    test('parses tool calls with generated IDs', () async {
      stubPost(
        ollamaResponse(
          message: {
            'role': 'assistant',
            'content': '',
            'tool_calls': [
              {
                'function': {
                  'name': 'get_weather',
                  'arguments': {'city': 'Paris'},
                },
              },
            ],
          },
        ),
      );
      final provider = buildProvider(const AIConfig(apiKey: ''));
      final response = await provider.chat([Message.user('Weather?')]);

      expect(response.hasToolCalls, isTrue);
      expect(response.finishReason, FinishReason.toolCalls);
      final call = response.toolCalls!.single;
      expect(call.name, 'get_weather');
      expect(call.arguments, {'city': 'Paris'});
      expect(call.id, startsWith('get_weather_'));
    });

    for (final (reason, expected) in [
      ('stop', FinishReason.stop),
      ('length', FinishReason.maxTokens),
      ('load', FinishReason.unknown),
    ]) {
      test('maps done reason $reason to $expected', () async {
        stubPost(ollamaResponse(doneReason: reason));
        final provider = buildProvider(const AIConfig(apiKey: ''));
        final response = await provider.chat([Message.user('Hi')]);

        expect(response.finishReason, expected);
      });
    }
  });

  group('streaming', () {
    void stubStream(List<String> lines) {
      when(
        () => client.postStream(
          any(),
          body: any(named: 'body'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) => Stream.fromIterable(lines));
    }

    test('decodes NDJSON deltas and the final done line', () async {
      stubStream([
        ndjson({
          'message': {'role': 'assistant', 'content': 'Hel'},
          'done': false,
        }),
        ndjson({
          'message': {'role': 'assistant', 'content': 'lo'},
          'done': false,
        }),
        ndjson({
          'message': {'role': 'assistant', 'content': ''},
          'done': true,
          'done_reason': 'stop',
          'prompt_eval_count': 3,
          'eval_count': 2,
        }),
      ]);
      final provider = buildProvider(const AIConfig(apiKey: ''));
      final chunks = await provider.streamChat([Message.user('Hi')]).toList();

      expect(chunks.first.isStart, isTrue);
      final text = chunks.where((c) => c.isDelta).map((c) => c.delta).join();
      expect(text, 'Hello');
      final last = chunks.last;
      expect(last.isDone, isTrue);
      expect(last.finishReason, FinishReason.stop);
      expect(last.usage?.promptTokens, 3);
    });

    test('emits tool call chunks', () async {
      stubStream([
        ndjson({
          'message': {
            'role': 'assistant',
            'content': '',
            'tool_calls': [
              {
                'function': {
                  'name': 'get_weather',
                  'arguments': {'city': 'Paris'},
                },
              },
            ],
          },
          'done': false,
        }),
      ]);
      final provider = buildProvider(const AIConfig(apiKey: ''));
      final chunks = await provider.streamChat([Message.user('Hi')]).toList();

      final toolChunk =
          chunks.firstWhere((c) => c.type == StreamEventType.toolCallDelta);
      expect(toolChunk.toolCallDelta?.name, 'get_weather');
    });

    test('emits an error chunk on malformed JSON', () async {
      stubStream(['{not json}']);
      final provider = buildProvider(const AIConfig(apiKey: ''));
      final chunks = await provider.streamChat([Message.user('Hi')]).toList();

      expect(chunks.any((c) => c.isError), isTrue);
    });
  });

  test('dispose releases the HTTP client', () {
    buildProvider(const AIConfig(apiKey: '')).dispose();

    verify(() => client.dispose()).called(1);
  });
}
