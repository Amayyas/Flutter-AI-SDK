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

Map<String, dynamic> googleAIResponse({
  List<Map<String, dynamic>>? parts,
  String finishReason = 'STOP',
  Map<String, dynamic>? usageMetadata,
}) =>
    {
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': parts ??
                [
                  {'text': 'Hello!'},
                ],
          },
          'finishReason': finishReason,
        },
      ],
      'usageMetadata':
          usageMetadata ?? {'promptTokenCount': 10, 'candidatesTokenCount': 5},
    };

void main() {
  late MockAIHttpClient client;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    client = MockAIHttpClient();
  });

  GoogleAIProvider buildProvider(AIConfig config) =>
      GoogleAIProvider(config, client: client);

  void stubPost([Map<String, dynamic>? data]) {
    when(
      () => client.post(
        any(),
        body: any(named: 'body'),
        headers: any(named: 'headers'),
      ),
    ).thenAnswer((_) async => jsonResponse(data ?? googleAIResponse()));
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

  group('GoogleAIProvider metadata', () {
    test('exposes provider type, default model and capabilities', () {
      final provider = buildProvider(const AIConfig(apiKey: 'key'));

      expect(provider.providerType, AIProvider.googleAI);
      expect(provider.defaultModel, DefaultModels.googleAI);
      expect(provider.hasCapability(ModelCapability.audio), isTrue);
      expect(provider.hasCapability(ModelCapability.vision), isTrue);
      expect(provider.hasCapability(ModelCapability.tools), isTrue);
    });
  });

  group('request building', () {
    test('targets the generateContent endpoint with model and key', () async {
      stubPost();
      final provider = buildProvider(
        const AIConfig(apiKey: 'g-key', model: 'gemini-3.5-flash'),
      );
      await provider.chat([Message.user('Hi')]);

      final url = verify(
        () => client.post(
          captureAny(),
          body: any(named: 'body'),
          headers: any(named: 'headers'),
        ),
      ).captured.single as String;
      expect(
        url,
        'https://generativelanguage.googleapis.com/v1beta'
        '/models/gemini-3.5-flash:generateContent?key=g-key',
      );
    });

    test('maps roles to user/model and system to systemInstruction', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key'),
        messages: [
          Message.system('Be helpful.'),
          Message.user('Hi'),
          Message.assistant('Hello!'),
        ],
      );

      final system = body['systemInstruction'] as Map<String, dynamic>;
      final systemParts = system['parts'] as List<dynamic>;
      expect(
        (systemParts.single as Map<String, dynamic>)['text'],
        'Be helpful.',
      );

      final contents = body['contents'] as List<dynamic>;
      expect(contents, hasLength(2));
      expect((contents[0] as Map<String, dynamic>)['role'], 'user');
      expect((contents[1] as Map<String, dynamic>)['role'], 'model');
    });

    test('builds generationConfig from config', () async {
      final body = await capturedBody(
        const AIConfig(
          apiKey: 'key',
          maxTokens: 512,
          temperature: 0.7,
          topP: 0.9,
          stopSequences: ['END'],
          responseFormat: JsonResponseFormat(),
        ),
      );

      final config = body['generationConfig'] as Map<String, dynamic>;
      expect(config['maxOutputTokens'], 512);
      expect(config['temperature'], 0.7);
      expect(config['topP'], 0.9);
      expect(config['stopSequences'], ['END']);
      expect(config['responseMimeType'], 'application/json');
    });

    test('sends responseJsonSchema when a schema is given', () async {
      const schema = {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
        },
        'required': ['name'],
      };
      final body = await capturedBody(
        const AIConfig(
          apiKey: 'key',
          responseFormat: JsonResponseFormat(schema: schema),
        ),
      );

      final config = body['generationConfig'] as Map<String, dynamic>;
      expect(config['responseMimeType'], 'application/json');
      expect(config['responseJsonSchema'], schema);
    });

    test('omits generationConfig when nothing is configured', () async {
      final body = await capturedBody(const AIConfig(apiKey: 'key'));

      expect(body.containsKey('generationConfig'), isFalse);
    });

    test('formats tools as functionDeclarations', () async {
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
      final declarations = (tools.single
          as Map<String, dynamic>)['functionDeclarations'] as List<dynamic>;
      expect(
        (declarations.single as Map<String, dynamic>)['name'],
        'get_weather',
      );
    });
  });

  group('message formatting', () {
    test('formats tool results as functionResponse parts', () async {
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

      final contents = body['contents'] as List<dynamic>;
      final message = contents.single as Map<String, dynamic>;
      expect(message['role'], 'function');
      final parts = message['parts'] as List<dynamic>;
      final response = (parts.single
          as Map<String, dynamic>)['functionResponse'] as Map<String, dynamic>;
      expect(response['name'], 'get_weather');
      expect(response['response'], {'temp': 20});
    });

    test('wraps non-map tool results in a result object', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key'),
        messages: [
          Message.toolResult(
            toolCallId: 'call_1',
            name: 'get_weather',
            result: 'sunny',
          ),
        ],
      );

      final contents = body['contents'] as List<dynamic>;
      final parts =
          (contents.single as Map<String, dynamic>)['parts'] as List<dynamic>;
      final response = (parts.single
          as Map<String, dynamic>)['functionResponse'] as Map<String, dynamic>;
      expect(response['response'], {'result': 'sunny'});
    });

    test('formats base64 images as inlineData', () async {
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

      final contents = body['contents'] as List<dynamic>;
      final parts =
          (contents.single as Map<String, dynamic>)['parts'] as List<dynamic>;
      final inline = (parts.single as Map<String, dynamic>)['inlineData']
          as Map<String, dynamic>;
      expect(inline['mimeType'], 'image/jpeg');
      expect(inline['data'], 'aGVsbG8=');
    });

    test('formats URL images as fileData', () async {
      final body = await capturedBody(
        const AIConfig(apiKey: 'key'),
        messages: [
          Message(
            role: MessageRole.user,
            content: const [
              ImageContent.fromUrl('https://example.com/a.png'),
            ],
          ),
        ],
      );

      final contents = body['contents'] as List<dynamic>;
      final parts =
          (contents.single as Map<String, dynamic>)['parts'] as List<dynamic>;
      final fileData = (parts.single as Map<String, dynamic>)['fileData']
          as Map<String, dynamic>;
      expect(fileData['fileUri'], 'https://example.com/a.png');
    });

    test('adds functionCall parts for assistant tool calls', () async {
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

      final contents = body['contents'] as List<dynamic>;
      final parts =
          (contents.single as Map<String, dynamic>)['parts'] as List<dynamic>;
      final call = (parts.last as Map<String, dynamic>)['functionCall']
          as Map<String, dynamic>;
      expect(call['name'], 'get_weather');
      expect(call['args'], {'city': 'Paris'});
    });
  });

  group('response parsing', () {
    test('parses text content and usage', () async {
      stubPost();
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      final response = await provider.chat([Message.user('Hi')]);

      expect(response.text, 'Hello!');
      expect(response.provider, AIProvider.googleAI);
      expect(response.finishReason, FinishReason.stop);
      expect(response.usage?.promptTokens, 10);
      expect(response.usage?.completionTokens, 5);
    });

    test('parses functionCall parts into tool calls', () async {
      stubPost(
        googleAIResponse(
          parts: [
            {
              'functionCall': {
                'name': 'get_weather',
                'args': {'city': 'Paris'},
              },
            },
          ],
        ),
      );
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      final response = await provider.chat([Message.user('Weather?')]);

      expect(response.hasToolCalls, isTrue);
      final call = response.toolCalls!.single;
      expect(call.name, 'get_weather');
      expect(call.arguments, {'city': 'Paris'});
    });

    test('throws AIContentFilterError when the prompt is blocked', () async {
      stubPost({
        'promptFeedback': {'blockReason': 'SAFETY'},
      });
      final provider = buildProvider(const AIConfig(apiKey: 'key'));

      expect(
        () => provider.chat([Message.user('Hi')]),
        throwsA(isA<AIContentFilterError>()),
      );
    });

    test('throws AIModelError when no candidates are returned', () async {
      stubPost({'candidates': <dynamic>[]});
      final provider = buildProvider(const AIConfig(apiKey: 'key'));

      expect(
        () => provider.chat([Message.user('Hi')]),
        throwsA(isA<AIModelError>()),
      );
    });

    for (final (reason, expected) in [
      ('STOP', FinishReason.stop),
      ('MAX_TOKENS', FinishReason.maxTokens),
      ('SAFETY', FinishReason.contentFilter),
      ('RECITATION', FinishReason.contentFilter),
      ('FUNCTION_CALL', FinishReason.toolCalls),
      ('SOMETHING_NEW', FinishReason.unknown),
    ]) {
      test('maps finish reason $reason to $expected', () async {
        stubPost(googleAIResponse(finishReason: reason));
        final provider = buildProvider(const AIConfig(apiKey: 'key'));
        final response = await provider.chat([Message.user('Hi')]);

        expect(response.finishReason, expected);
      });
    }
  });

  group('countTokens', () {
    test('calls the countTokens endpoint with a generateContentRequest',
        () async {
      when(() => client.post(
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
          ),).thenAnswer((_) async => jsonResponse({'totalTokens': 42}));
      final provider = buildProvider(
        const AIConfig(apiKey: 'g-key', maxTokens: 1024),
      );

      final tokens = await provider.countTokens([Message.user('Hi')]);

      expect(tokens, 42);
      final captured = verify(() => client.post(
            captureAny(),
            body: captureAny(named: 'body'),
            headers: any(named: 'headers'),
          ),).captured;
      expect(captured[0] as String, contains(':countTokens'));
      final body = captured[1] as Map<String, dynamic>;
      final request = body['generateContentRequest'] as Map<String, dynamic>;
      expect(request['model'], 'models/${DefaultModels.googleAI}');
      expect(request.containsKey('contents'), isTrue);
      expect(request.containsKey('generationConfig'), isFalse);
    });
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

    test('targets the streamGenerateContent SSE endpoint', () async {
      stubStream([]);
      final provider = buildProvider(
        const AIConfig(apiKey: 'g-key', model: 'gemini-3.5-flash'),
      );
      await provider.streamChat([Message.user('Hi')]).drain<void>();

      final url = verify(
        () => client.postStream(
          captureAny(),
          body: any(named: 'body'),
          headers: any(named: 'headers'),
        ),
      ).captured.single as String;
      expect(url, contains(':streamGenerateContent'));
      expect(url, contains('alt=sse'));
    });

    test('emits start, deltas and a final done chunk', () async {
      stubStream([
        sse({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Hel'},
                ],
              },
            },
          ],
        }),
        sse({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'lo'},
                ],
              },
            },
          ],
        }),
        sse({
          'candidates': [
            {'finishReason': 'MAX_TOKENS'},
          ],
          'usageMetadata': {'promptTokenCount': 3, 'candidatesTokenCount': 2},
        }),
      ]);
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      final chunks = await provider.streamChat([Message.user('Hi')]).toList();

      expect(chunks.first.isStart, isTrue);
      final text = chunks.where((c) => c.isDelta).map((c) => c.delta).join();
      expect(text, 'Hello');
      final last = chunks.last;
      expect(last.isDone, isTrue);
      expect(last.finishReason, FinishReason.maxTokens);
      expect(last.usage?.promptTokens, 3);
    });

    test('emits tool call chunks for functionCall parts', () async {
      stubStream([
        sse({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'functionCall': {
                      'name': 'get_weather',
                      'args': {'city': 'Paris'},
                    },
                  },
                ],
              },
            },
          ],
        }),
      ]);
      final provider = buildProvider(const AIConfig(apiKey: 'key'));
      final chunks = await provider.streamChat([Message.user('Hi')]).toList();

      final toolChunk =
          chunks.firstWhere((c) => c.type == StreamEventType.toolCallDelta);
      expect(toolChunk.toolCallDelta?.name, 'get_weather');
      expect(toolChunk.toolCallDelta?.arguments, {'city': 'Paris'});
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
