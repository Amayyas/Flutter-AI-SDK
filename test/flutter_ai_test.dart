import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockProvider extends Mock implements BaseProvider {}

AIResponse response(String text) => AIResponse(
      id: 'resp_1',
      content: [TextContent(text)],
      finishReason: FinishReason.stop,
    );

void main() {
  late MockProvider provider;
  late FlutterAI ai;

  setUpAll(() {
    registerFallbackValue(<Message>[]);
  });

  setUp(() {
    provider = MockProvider();
    ai = FlutterAI(
      provider: AIProvider.openai,
      config: const AIConfig(apiKey: 'key'),
      customProvider: provider,
    );
  });

  group('chat', () {
    test('sends context messages and records the exchange', () async {
      when(() => provider.chat(any()))
          .thenAnswer((_) async => response('Pong'));

      final result = await ai.chat('Ping');

      expect(result.text, 'Pong');
      expect(ai.history, hasLength(2));
      expect(ai.history.first.role, MessageRole.user);
      expect(ai.history.first.text, 'Ping');
      expect(ai.history.last.role, MessageRole.assistant);
      expect(ai.history.last.text, 'Pong');
    });

    test('leaves context untouched when addToContext is false', () async {
      when(() => provider.chat(any()))
          .thenAnswer((_) async => response('Pong'));

      await ai.chat('Ping', addToContext: false);

      expect(ai.history, isEmpty);
    });

    test('accumulates history across turns', () async {
      when(() => provider.chat(any()))
          .thenAnswer((_) async => response('Pong'));

      await ai.chat('One');
      await ai.chat('Two');

      final sent = verify(() => provider.chat(captureAny())).captured;
      final secondCall = sent.last as List<Message>;
      // Second request carries the full history.
      expect(
        secondCall.map((m) => m.text),
        containsAll(['One', 'Pong', 'Two']),
      );
    });
  });

  group('chatWithContent', () {
    test('wraps content in a user message', () async {
      when(() => provider.chat(any()))
          .thenAnswer((_) async => response('A cat.'));

      await ai.chatWithContent(const [
        TextContent('Describe this'),
        ImageContent.fromUrl('https://example.com/a.png'),
      ]);

      final sent = verify(() => provider.chat(captureAny())).captured.single
          as List<Message>;
      final userMessage = sent.single;
      expect(userMessage.role, MessageRole.user);
      expect(userMessage.content, hasLength(2));
    });
  });

  group('streamChat', () {
    test('yields chunks and records accumulated text', () async {
      when(() => provider.streamChat(any())).thenAnswer(
        (_) => Stream.fromIterable(const [
          StreamChunk.start(),
          StreamChunk.delta('Hel'),
          StreamChunk.delta('lo'),
          StreamChunk.done(finishReason: FinishReason.stop),
        ]),
      );

      final chunks = await ai.streamChat('Hi').toList();

      expect(chunks, hasLength(4));
      expect(ai.history.last.role, MessageRole.assistant);
      expect(ai.history.last.text, 'Hello');
    });
  });

  group('submitToolResult', () {
    test('adds the tool result to context before calling the provider',
        () async {
      when(() => provider.chat(any()))
          .thenAnswer((_) async => response('It is sunny.'));

      await ai.submitToolResult(
        toolCallId: 'call_1',
        name: 'get_weather',
        result: {'condition': 'sunny'},
      );

      final sent = verify(() => provider.chat(captureAny())).captured.single
          as List<Message>;
      expect(sent.any((m) => m.role == MessageRole.tool), isTrue);
    });
  });

  group('context management', () {
    test('clearContext empties the history', () async {
      when(() => provider.chat(any()))
          .thenAnswer((_) async => response('Pong'));
      await ai.chat('Ping');

      ai.clearContext();

      expect(ai.history, isEmpty);
    });

    test('exposes provider type and config', () {
      expect(ai.provider, AIProvider.openai);
      expect(ai.config.apiKey, 'key');
    });
  });

  group('capabilities', () {
    test('hasCapability delegates to the provider', () {
      when(() => provider.hasCapability(ModelCapability.vision))
          .thenReturn(true);

      expect(ai.hasCapability(ModelCapability.vision), isTrue);
      verify(() => provider.hasCapability(ModelCapability.vision)).called(1);
    });
  });

  test('dispose releases the provider', () {
    when(() => provider.dispose()).thenReturn(null);

    ai.dispose();

    verify(() => provider.dispose()).called(1);
  });

  test('creates built-in providers when no custom provider is given', () {
    final instance = FlutterAI(
      provider: AIProvider.anthropic,
      config: const AIConfig(apiKey: 'key'),
    );

    expect(instance.provider, AIProvider.anthropic);
    instance.dispose();
  });
}
