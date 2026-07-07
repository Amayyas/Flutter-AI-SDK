import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockAIHttpClient extends Mock implements AIHttpClient {}

/// Formats an event as an SSE data line.
String sse(Map<String, dynamic> event) => 'data: ${jsonEncode(event)}';

Response<dynamic> jsonResponse(Map<String, dynamic> data) => Response<dynamic>(
      requestOptions: RequestOptions(),
      data: data,
      statusCode: 200,
    );

Map<String, dynamic> openAIResponse({
  Map<String, dynamic>? message,
  String finishReason = 'stop',
  Map<String, dynamic>? usage,
  List<dynamic>? choices,
}) =>
    {
      'id': 'chatcmpl-123',
      'model': 'gpt-5.5',
      'created': 1751500000,
      'choices': choices ??
          [
            {
              'message': message ?? {'role': 'assistant', 'content': 'Hello!'},
              'finish_reason': finishReason,
            },
          ],
      'usage': usage ??
          {'prompt_tokens': 10, 'completion_tokens': 5, 'total_tokens': 15},
    };

void main() {
  late MockAIHttpClient client;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    client = MockAIHttpClient();
  });

  OpenAIProvider buildProvider(AIConfig config) =>
      OpenAIProvider(config, client: client);

  void stubPost([Map<String, dynamic>? data]) {
    when(() => client.post(
          any(),
          body: any(named: 'body'),
          headers: any(named: 'headers'),
        ),).thenAnswer((_) async => jsonResponse(data ?? openAIResponse()));
  }

  /// Runs a chat and returns the captured request body.
  Future<Map<String, dynamic>> capturedBody(
    AIConfig config, {
    List<Message>? messages,
  }) async {
    stubPost();
    final provider = buildProvider(config);
    await provider.chat(messages ?? [Message.user('Hi')]);
    final captured = verify(() => client.post(
          any(),
          body: captureAny(named: 'body'),
          headers: any(named: 'headers'),
        ),).captured;
    return captured.single as Map<String, dynamic>;
  }

  group('OpenAIProvider metadata', () {
    test('exposes provider type, default model and capabilities', () {
      final provider = buildProvider(const AIConfig(apiKey: 'key'));

      expect(provider.providerType, AIProvider.openai);
      expect(provider.defaultModel, DefaultModels.openai);
      expect(provider.hasCapability(ModelCapability.tools), isTrue);
      expect(provider.hasCapability(ModelCapability.jsonMode), isTrue);
      expect(provider.hasCapability(ModelCapability.vision), isTrue);
    });

    test('chat throws when API key is empty', () {
      final provider = buildProvider(const AIConfig(apiKey: ''));

      expect(
        () => provider.chat([Message.user('Hi')]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('request building', () {
    test('targets the chat completions endpoint', () async {
      stubPost();
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      await provider.chat([Message.user('Hi')]);

      final url = verify(() => client.post(
            captureAny(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          ),).captured.single;
      expect(url, 'https://api.openai.com/v1/chat/completions');
    });

    test('uses default model when none is configured', () async {
      final body = await capturedBody(const AIConfig(apiKey: 'key'));

      expect(body['model'], DefaultModels.openai);
      expect(body['stream'], isFalse);
    });

    test('sends sampling and penalty parameters when set', () async {
      final body = await capturedBody(
        const AIConfig(
          apiKey: 'key',
          maxTokens: 512,
          temperature: 0.7,
          topP: 0.9,
          frequencyPenalty: 0.1,
          presencePenalty: 0.2,
          stopSequences: ['END'],
        ),
      );

      expect(body['max_tokens'], 512);
      expect(body['temperature'], 0.7);
      expect(body['top_p'], 0.9);
      expect(body['frequency_penalty'], 0.1);
      expect(body['presence_penalty'], 0.2);
      expect(body['stop'], ['END']);
    });

    test('omits optional parameters when unset', () async {
      final body = await capturedBody(const AIConfig(apiKey: 'key'));

      expect(body.containsKey('max_tokens'), isFalse);
      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('response_format'), isFalse);
      expect(body.containsKey('stream_options'), isFalse);
    });

    test('sends response_format when configured', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key', responseFormat: JsonResponseFormat()),
      );

      expect(
        (body['response_format'] as Map<String, dynamic>)['type'],
        'json_object',
      );
    });

    test('formats tools in OpenAI format', () async {
      final tool = Tool(
        name: 'get_weather',
        description: 'Get the weather',
        parameters: ToolParameters(
          properties: {'city': ToolProperty.string(description: 'City')},
          required: const ['city'],
        ),
      );
      final body = await capturedBody(AIConfig(apiKey: 'key', tools: [tool]));

      final tools = body['tools'] as List<dynamic>;
      final first = tools.single as Map<String, dynamic>;
      expect(first['type'], 'function');
      final function = first['function'] as Map<String, dynamic>;
      expect(function['name'], 'get_weather');
    });
  });

  group('message formatting', () {
    test('formats text-only messages with string content', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key'),
        messages: [Message.system('Be brief.'), Message.user('Hi')],
      );

      final messages = body['messages'] as List<dynamic>;
      expect(messages, hasLength(2));
      expect(messages.first, {'role': 'system', 'content': 'Be brief.'});
      expect(messages.last, {'role': 'user', 'content': 'Hi'});
    });

    test('formats multimodal messages as content parts', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key'),
        messages: [
          Message(
            role: MessageRole.user,
            content: const [
              TextContent('Describe this'),
              ImageContent.fromUrl('https://example.com/a.png'),
            ],
          ),
        ],
      );

      final messages = body['messages'] as List<dynamic>;
      final content =
          (messages.single as Map<String, dynamic>)['content'] as List<dynamic>;
      expect(content, hasLength(2));
      expect((content.first as Map<String, dynamic>)['type'], 'text');
    });

    test('serializes assistant tool calls', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key'),
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
      final toolCalls = (messages.single
          as Map<String, dynamic>)['tool_calls'] as List<dynamic>;
      final call = toolCalls.single as Map<String, dynamic>;
      expect(call['id'], 'call_1');
      expect(call['type'], 'function');
      final function = call['function'] as Map<String, dynamic>;
      expect(function['name'], 'get_weather');
      expect(function['arguments'], '{"city":"Paris"}');
    });

    test('formats tool results with tool_call_id', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key'),
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
      expect(toolMessage['tool_call_id'], 'call_1');
      expect(toolMessage['content'], '{"temp":20}');
    });
  });

  group('response parsing', () {
    test('parses text content, usage and metadata', () async {
      stubPost();
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      final response = await provider.chat([Message.user('Hi')]);

      expect(response.id, 'chatcmpl-123');
      expect(response.text, 'Hello!');
      expect(response.model, 'gpt-5.5');
      expect(response.provider, AIProvider.openai);
      expect(response.finishReason, FinishReason.stop);
      expect(response.usage?.promptTokens, 10);
      expect(response.usage?.completionTokens, 5);
      expect(
        response.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1751500000 * 1000),
      );
    });

    test('parses tool calls and decodes their JSON arguments', () async {
      stubPost(openAIResponse(
        message: {
          'role': 'assistant',
          'content': null,
          'tool_calls': [
            {
              'id': 'call_1',
              'type': 'function',
              'function': {
                'name': 'get_weather',
                'arguments': '{"city":"Paris"}',
              },
            },
          ],
        },
        finishReason: 'tool_calls',
      ),);
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      final response = await provider.chat([Message.user('Weather?')]);

      expect(response.hasToolCalls, isTrue);
      expect(response.finishReason, FinishReason.toolCalls);
      final call = response.toolCalls!.single;
      expect(call.name, 'get_weather');
      expect(call.arguments, {'city': 'Paris'});
    });

    test('throws AIModelError when no choices are returned', () async {
      stubPost(openAIResponse(choices: []));
      final provider = buildProvider(const AIConfig(apiKey: 'key'));

      expect(
        () => provider.chat([Message.user('Hi')]),
        throwsA(isA<AIModelError>()),
      );
    });

    for (final (reason, expected) in [
      ('stop', FinishReason.stop),
      ('length', FinishReason.maxTokens),
      ('content_filter', FinishReason.contentFilter),
      ('tool_calls', FinishReason.toolCalls),
      ('something_new', FinishReason.unknown),
    ]) {
      test('maps finish reason $reason to $expected', () async {
        stubPost(openAIResponse(finishReason: reason));
        final provider = buildProvider(const AIConfig(apiKey: 'key'));
        final response = await provider.chat([Message.user('Hi')]);

        expect(response.finishReason, expected);
      });
    }
  });

  group('streaming', () {
    void stubStream(List<String> lines) {
      when(() => client.postStream(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          ),).thenAnswer((_) => Stream.fromIterable(lines));
    }

    test('requests usage reporting in stream mode', () async {
      stubStream([]);
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      await provider.streamChat([Message.user('Hi')]).drain<void>();

      final body = verify(() => client.postStream(
            any(),
            body: captureAny(named: 'body'),
            headers: any(named: 'headers'),
          ),).captured.single as Map<String, dynamic>;
      expect(body['stream'], isTrue);
      expect(body['stream_options'], {'include_usage': true});
    });

    test('emits start, deltas and a final done chunk', () async {
      stubStream([
        sse({
          'choices': [
            {'delta': {'content': 'Hel'}},
          ],
        }),
        sse({
          'choices': [
            {'delta': {'content': 'lo'}},
          ],
        }),
        sse({
          'choices': [
            {'delta': <String, dynamic>{}, 'finish_reason': 'stop'},
          ],
        }),
        sse({
          'choices': <dynamic>[],
          'usage': {'prompt_tokens': 3, 'completion_tokens': 2},
        }),
        'data: [DONE]',
      ]);
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      final chunks = await provider.streamChat([Message.user('Hi')]).toList();

      expect(chunks.first.isStart, isTrue);
      final text = chunks.where((c) => c.isDelta).map((c) => c.delta).join();
      expect(text, 'Hello');
      final last = chunks.last;
      expect(last.isDone, isTrue);
      expect(last.finishReason, FinishReason.stop);
      expect(last.usage?.promptTokens, 3);
    });

    test('emits tool call deltas with partial arguments', () async {
      stubStream([
        r'data: {"choices":[{"delta":{"tool_calls":[{"function":{"arguments":"{\"ci"}}]}}]}',
        'data: [DONE]',
      ]);
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      final chunks = await provider.streamChat([Message.user('Hi')]).toList();

      final toolChunk =
          chunks.firstWhere((c) => c.type == StreamEventType.toolCallDelta);
      expect(toolChunk.metadata?['partial_args'], '{"ci');
    });

    test('emits an error chunk on malformed JSON', () async {
      stubStream(['data: {not json}']);
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      final chunks = await provider.streamChat([Message.user('Hi')]).toList();

      expect(chunks.any((c) => c.isError), isTrue);
    });
  });

  test('dispose releases the HTTP client', () {
    buildProvider(const AIConfig(apiKey: 'key')).dispose();

    verify(() => client.dispose()).called(1);
  });
}
