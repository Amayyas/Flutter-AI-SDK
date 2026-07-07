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

Map<String, dynamic> anthropicResponse({
  List<Map<String, dynamic>>? content,
  String stopReason = 'end_turn',
  Map<String, dynamic>? usage,
}) =>
    {
      'id': 'msg_123',
      'model': 'claude-opus-4-8',
      'content': content ??
          [
            {'type': 'text', 'text': 'Hello!'},
          ],
      'stop_reason': stopReason,
      'usage': usage ?? {'input_tokens': 10, 'output_tokens': 5},
    };

void main() {
  late MockAIHttpClient client;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    client = MockAIHttpClient();
  });

  AnthropicProvider buildProvider(AIConfig config) =>
      AnthropicProvider(config, client: client);

  void stubPost([Map<String, dynamic>? data]) {
    when(
      () => client.post(
        any(),
        body: any(named: 'body'),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer((_) async => jsonResponse(data ?? anthropicResponse()));
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

  group('AnthropicProvider metadata', () {
    test('exposes provider type, default model and capabilities', () {
      final provider = buildProvider(const AIConfig(apiKey: 'key'));

      expect(provider.providerType, AIProvider.anthropic);
      expect(provider.defaultModel, DefaultModels.anthropic);
      expect(provider.hasCapability(ModelCapability.tools), isTrue);
      expect(provider.hasCapability(ModelCapability.vision), isTrue);
      expect(provider.hasCapability(ModelCapability.streaming), isTrue);
      expect(provider.hasCapability(ModelCapability.audio), isFalse);
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
    test('targets the messages endpoint with Anthropic headers', () async {
      stubPost();
      final provider = buildProvider(const AIConfig(apiKey: 'sk-ant-test'));
      await provider.chat([Message.user('Hi')]);

      final captured = verify(
        () => client.post(
          captureAny(),
          body: any(named: 'body'),
          headers: captureAny(named: 'headers'),
        ),
      ).captured;

      expect(captured[0], 'https://api.anthropic.com/v1/messages');
      final headers = captured[1] as Map<String, String>;
      expect(headers['x-api-key'], 'sk-ant-test');
      expect(headers['anthropic-version'], AnthropicProvider.apiVersion);
    });

    test('uses default model when none is configured', () async {
      final body = await capturedBody(const AIConfig(apiKey: 'key'));

      expect(body['model'], DefaultModels.anthropic);
    });

    test('uses configured model', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key', model: 'claude-sonnet-5'),
      );

      expect(body['model'], 'claude-sonnet-5');
    });

    test('defaults max_tokens to 4096 (required by Anthropic)', () async {
      final body = await capturedBody(const AIConfig(apiKey: 'key'));

      expect(body['max_tokens'], 4096);
    });

    test('uses configured max_tokens', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key', maxTokens: 1024),
      );

      expect(body['max_tokens'], 1024);
    });

    test('extracts system message from the conversation', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key'),
        messages: [
          Message.system('You are helpful.'),
          Message.user('Hi'),
        ],
      );

      expect(body['system'], 'You are helpful.');
      final messages = body['messages'] as List<dynamic>;
      expect(messages, hasLength(1));
      expect((messages.first as Map<String, dynamic>)['role'], 'user');
    });

    test('uses system prompt from config', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key', systemPrompt: 'Be concise.'),
      );

      expect(body['system'], 'Be concise.');
    });

    test('sends temperature when set', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key', temperature: 0.5),
      );

      expect(body['temperature'], 0.5);
      expect(body.containsKey('top_p'), isFalse);
    });

    test('sends top_p only when temperature is unset', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key', topP: 0.9),
      );

      expect(body['top_p'], 0.9);
      expect(body.containsKey('temperature'), isFalse);
    });

    test('never sends temperature and top_p together (Claude 4+ rejects it)',
        () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key', temperature: 0.5, topP: 0.9),
      );

      expect(body['temperature'], 0.5);
      expect(body.containsKey('top_p'), isFalse);
    });

    test('sends stop sequences', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key', stopSequences: ['END']),
      );

      expect(body['stop_sequences'], ['END']);
    });

    test('formats tools in Anthropic format', () async {
      final tool = Tool(
        name: 'get_weather',
        description: 'Get the weather',
        parameters: ToolParameters(
          properties: {'city': ToolProperty.string(description: 'City name')},
          required: const ['city'],
        ),
      );
      final body = await capturedBody(
        AIConfig(
          apiKey: 'key',
          tools: [tool],
          toolChoice: const ToolChoice.auto(),
        ),
      );

      final tools = body['tools'] as List<dynamic>;
      final first = tools.single as Map<String, dynamic>;
      expect(first['name'], 'get_weather');
      expect(first['description'], 'Get the weather');
      expect(first.containsKey('input_schema'), isTrue);
      expect(body.containsKey('tool_choice'), isTrue);
    });
  });

  group('message formatting', () {
    test('formats tool results as user tool_result blocks', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key'),
        messages: [
          Message.user('Weather in Paris?'),
          Message.toolResult(
            toolCallId: 'call_1',
            name: 'get_weather',
            result: {'temp': 20},
          ),
        ],
      );

      final messages = body['messages'] as List<dynamic>;
      // The user turn and the tool result are merged into one user message
      // because Anthropic requires user/assistant roles to alternate.
      expect(messages, hasLength(1));
      final toolMessage = messages.single as Map<String, dynamic>;
      expect(toolMessage['role'], 'user');
      final blocks = toolMessage['content'] as List<dynamic>;
      final block = blocks.last as Map<String, dynamic>;
      expect(block['type'], 'tool_result');
      expect(block['tool_use_id'], 'call_1');
      expect(block['content'], '{"temp":20}');
    });

    test('keeps alternating roles when tool results follow assistant turns',
        () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key'),
        messages: [
          Message.user('Weather in Paris and Tokyo?'),
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
          Message.toolResult(
            toolCallId: 'call_1',
            name: 'get_weather',
            result: 'sunny',
          ),
          Message.toolResult(
            toolCallId: 'call_2',
            name: 'get_weather',
            result: 'rainy',
          ),
        ],
      );

      final messages = body['messages'] as List<dynamic>;
      final roles =
          messages.map((m) => (m as Map<String, dynamic>)['role']).toList();
      // user / assistant / user (both tool results merged)
      expect(roles, ['user', 'assistant', 'user']);
      final lastBlocks =
          (messages.last as Map<String, dynamic>)['content'] as List<dynamic>;
      expect(lastBlocks, hasLength(2));
    });

    test('marks tool result errors with is_error', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key'),
        messages: [
          Message.toolResult(
            toolCallId: 'call_1',
            name: 'get_weather',
            result: 'city not found',
            isError: true,
          ),
        ],
      );

      final messages = body['messages'] as List<dynamic>;
      final message = messages.single as Map<String, dynamic>;
      final blocks = message['content'] as List<dynamic>;
      expect((blocks.single as Map<String, dynamic>)['is_error'], isTrue);
    });

    test('adds tool_use blocks for assistant tool calls', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key'),
        messages: [
          Message.user('Weather?'),
          Message.assistant(
            'Let me check.',
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
      final assistant = messages.last as Map<String, dynamic>;
      final blocks = assistant['content'] as List<dynamic>;
      final toolUse = blocks.last as Map<String, dynamic>;
      expect(toolUse['type'], 'tool_use');
      expect(toolUse['id'], 'call_1');
      expect(toolUse['name'], 'get_weather');
      expect(toolUse['input'], {'city': 'Paris'});
    });

    test('formats URL images as url sources', () async {
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
      final message = messages.single as Map<String, dynamic>;
      final blocks = message['content'] as List<dynamic>;
      final image = blocks.last as Map<String, dynamic>;
      expect(image['type'], 'image');
      expect(image['source'], {
        'type': 'url',
        'url': 'https://example.com/a.png',
      });
    });

    test('formats base64 images with media type', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key'),
        messages: [
          Message(
            role: MessageRole.user,
            content: const [
              ImageContent.fromBase64('aGVsbG8=', mimeType: 'image/jpeg'),
            ],
          ),
        ],
      );

      final messages = body['messages'] as List<dynamic>;
      final message = messages.single as Map<String, dynamic>;
      final blocks = message['content'] as List<dynamic>;
      final block = blocks.single as Map<String, dynamic>;
      final source = block['source'] as Map<String, dynamic>;
      expect(source['type'], 'base64');
      expect(source['media_type'], 'image/jpeg');
      expect(source['data'], 'aGVsbG8=');
    });
  });

  group('response parsing', () {
    test('parses text content, usage and metadata', () async {
      stubPost();
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      final response = await provider.chat([Message.user('Hi')]);

      expect(response.id, 'msg_123');
      expect(response.text, 'Hello!');
      expect(response.model, 'claude-opus-4-8');
      expect(response.provider, AIProvider.anthropic);
      expect(response.finishReason, FinishReason.stop);
      expect(response.usage?.promptTokens, 10);
      expect(response.usage?.completionTokens, 5);
    });

    test('parses tool_use blocks into tool calls', () async {
      stubPost(
        anthropicResponse(
          content: [
            {'type': 'text', 'text': 'Checking...'},
            {
              'type': 'tool_use',
              'id': 'call_1',
              'name': 'get_weather',
              'input': {'city': 'Paris'},
            },
          ],
          stopReason: 'tool_use',
        ),
      );
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      final response = await provider.chat([Message.user('Weather?')]);

      expect(response.hasToolCalls, isTrue);
      expect(response.finishReason, FinishReason.toolCalls);
      final call = response.toolCalls!.single;
      expect(call.id, 'call_1');
      expect(call.name, 'get_weather');
      expect(call.arguments, {'city': 'Paris'});
    });

    for (final (reason, expected) in [
      ('end_turn', FinishReason.stop),
      ('stop_sequence', FinishReason.stop),
      ('max_tokens', FinishReason.maxTokens),
      ('model_context_window_exceeded', FinishReason.maxTokens),
      ('tool_use', FinishReason.toolCalls),
      ('refusal', FinishReason.contentFilter),
      ('something_new', FinishReason.unknown),
    ]) {
      test('maps stop reason $reason to $expected', () async {
        stubPost(anthropicResponse(stopReason: reason));
        final provider = buildProvider(const AIConfig(apiKey: 'key'));
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

    test('emits start, deltas and a final done chunk', () async {
      stubStream([
        sse({
          'type': 'content_block_delta',
          'delta': {'type': 'text_delta', 'text': 'Hel'},
        }),
        sse({
          'type': 'content_block_delta',
          'delta': {'type': 'text_delta', 'text': 'lo'},
        }),
        sse({
          'type': 'message_delta',
          'delta': {'stop_reason': 'end_turn'},
          'usage': {'input_tokens': 3, 'output_tokens': 2},
        }),
        sse({'type': 'message_stop'}),
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
      expect(last.usage?.completionTokens, 2);
    });

    test('emits tool call deltas for input_json_delta events', () async {
      stubStream([
        r'data: {"type":"content_block_delta","delta":{"type":"input_json_delta","partial_json":"{\"city\""}}',
        'data: {"type":"message_stop"}',
      ]);
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      final chunks = await provider.streamChat([Message.user('Hi')]).toList();

      final toolChunk =
          chunks.firstWhere((c) => c.type == StreamEventType.toolCallDelta);
      expect(toolChunk.metadata?['partial_json'], '{"city"');
    });

    test('emits an error chunk on malformed JSON', () async {
      stubStream(['data: {not json}']);
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      final chunks = await provider.streamChat([Message.user('Hi')]).toList();

      expect(chunks.any((c) => c.isError), isTrue);
    });

    test('ignores non-data SSE lines', () async {
      stubStream([
        'event: message_start',
        sse({
          'type': 'content_block_delta',
          'delta': {'type': 'text_delta', 'text': 'Hi'},
        }),
      ]);
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      final chunks = await provider.streamChat([Message.user('Hi')]).toList();

      expect(chunks.where((c) => c.isDelta), hasLength(1));
    });
  });

  test('dispose releases the HTTP client', () {
    buildProvider(const AIConfig(apiKey: 'key')).dispose();

    verify(() => client.dispose()).called(1);
  });
}
