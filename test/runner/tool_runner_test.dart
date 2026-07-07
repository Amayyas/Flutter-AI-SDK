import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockProvider extends Mock implements BaseProvider {}

AIResponse textResponse(String text) => AIResponse(
      id: 'resp_final',
      content: [TextContent(text)],
      finishReason: FinishReason.stop,
    );

AIResponse toolCallResponse(List<ToolCallContent> calls) => AIResponse(
      id: 'resp_tool',
      content: const [TextContent('Let me check.')],
      finishReason: FinishReason.toolCalls,
      toolCalls: calls,
    );

ExecutableTool weatherTool({ToolExecutor? executor}) => ExecutableTool(
      definition: Tool(
        name: 'get_weather',
        description: 'Get the weather',
        parameters: ToolParameters(
          properties: {'city': ToolProperty.string(description: 'City')},
          required: const ['city'],
        ),
      ),
      executor: executor ?? (args) => 'sunny in ${args['city']}',
    );

void main() {
  late MockProvider provider;

  setUpAll(() {
    registerFallbackValue(<Message>[]);
  });

  setUp(() {
    provider = MockProvider();
  });

  /// Stubs provider.chat to return [responses] one after the other.
  void stubChatSequence(List<AIResponse> responses) {
    final queue = [...responses];
    when(() => provider.chat(any()))
        .thenAnswer((_) async => queue.removeAt(0));
  }

  group('run', () {
    test('returns directly when the model makes no tool call', () async {
      stubChatSequence([textResponse('Hello!')]);
      final runner = ToolRunner(provider: provider, tools: [weatherTool()]);

      final result = await runner.run('Hi');

      expect(result.text, 'Hello!');
      expect(result.iterations, 0);
      verify(() => provider.chat(any())).called(1);
    });

    test('executes the tool and feeds the result back to the model',
        () async {
      stubChatSequence([
        toolCallResponse(const [
          ToolCallContent(
            id: 'call_1',
            name: 'get_weather',
            arguments: {'city': 'Paris'},
          ),
        ]),
        textResponse('It is sunny in Paris.'),
      ]);
      final runner = ToolRunner(provider: provider, tools: [weatherTool()]);

      final result = await runner.run('Weather in Paris?');

      expect(result.text, 'It is sunny in Paris.');
      expect(result.iterations, 1);

      final calls = verify(() => provider.chat(captureAny())).captured;
      final secondCall = calls.last as List<Message>;
      // Transcript: user, assistant (tool call), tool result
      expect(secondCall, hasLength(3));
      expect(secondCall[1].role, MessageRole.assistant);
      expect(secondCall[1].toolCalls, hasLength(1));
      final toolMessage = secondCall.last;
      expect(toolMessage.role, MessageRole.tool);
      final toolResult =
          toolMessage.content.whereType<ToolResultContent>().single;
      expect(toolResult.toolCallId, 'call_1');
      expect(toolResult.result, 'sunny in Paris');
      expect(toolResult.isError, isFalse);
    });

    test('executes parallel tool calls into a single tool message', () async {
      stubChatSequence([
        toolCallResponse(const [
          ToolCallContent(
            id: 'call_1',
            name: 'get_weather',
            arguments: {'city': 'Paris'},
          ),
          ToolCallContent(
            id: 'call_2',
            name: 'get_weather',
            arguments: {'city': 'Tokyo'},
          ),
        ]),
        textResponse('Done.'),
      ]);
      final runner = ToolRunner(provider: provider, tools: [weatherTool()]);

      await runner.run('Compare weather');

      final calls = verify(() => provider.chat(captureAny())).captured;
      final secondCall = calls.last as List<Message>;
      final toolMessage = secondCall.last;
      final results =
          toolMessage.content.whereType<ToolResultContent>().toList();
      expect(results, hasLength(2));
      expect(results.map((r) => r.toolCallId), ['call_1', 'call_2']);
    });

    test('reports unknown tools to the model as error results', () async {
      stubChatSequence([
        toolCallResponse(const [
          ToolCallContent(id: 'call_1', name: 'missing_tool', arguments: {}),
        ]),
        textResponse('Sorry.'),
      ]);
      final runner = ToolRunner(provider: provider, tools: [weatherTool()]);

      await runner.run('Hi');

      final calls = verify(() => provider.chat(captureAny())).captured;
      final toolResult = (calls.last as List<Message>)
          .last
          .content
          .whereType<ToolResultContent>()
          .single;
      expect(toolResult.isError, isTrue);
      expect(toolResult.result, contains('Unknown tool'));
    });

    test('reports executor failures as error results without aborting',
        () async {
      stubChatSequence([
        toolCallResponse(const [
          ToolCallContent(
            id: 'call_1',
            name: 'get_weather',
            arguments: {'city': 'Paris'},
          ),
        ]),
        textResponse('Could not fetch the weather.'),
      ]);
      final runner = ToolRunner(
        provider: provider,
        tools: [weatherTool(executor: (_) => throw StateError('boom'))],
      );

      final result = await runner.run('Weather?');

      expect(result.text, 'Could not fetch the weather.');
      final calls = verify(() => provider.chat(captureAny())).captured;
      final toolResult = (calls.last as List<Message>)
          .last
          .content
          .whereType<ToolResultContent>()
          .single;
      expect(toolResult.isError, isTrue);
      expect(toolResult.result, contains('boom'));
    });

    test('throws ToolRunnerException when maxIterations is exceeded',
        () async {
      when(() => provider.chat(any())).thenAnswer(
        (_) async => toolCallResponse(const [
          ToolCallContent(
            id: 'call_1',
            name: 'get_weather',
            arguments: {'city': 'Paris'},
          ),
        ]),
      );
      final runner = ToolRunner(
        provider: provider,
        tools: [weatherTool()],
        maxIterations: 2,
      );

      expect(
        () => runner.run('Weather?'),
        throwsA(isA<ToolRunnerException>()),
      );
    });

    test('continues from provided history', () async {
      stubChatSequence([textResponse('Hello again!')]);
      final runner = ToolRunner(provider: provider, tools: [weatherTool()]);

      await runner.run('Hi', history: [Message.system('Be nice.')]);

      final sent = verify(() => provider.chat(captureAny())).captured.single
          as List<Message>;
      expect(sent, hasLength(2));
      expect(sent.first.role, MessageRole.system);
    });

    test('invokes observation callbacks', () async {
      stubChatSequence([
        toolCallResponse(const [
          ToolCallContent(
            id: 'call_1',
            name: 'get_weather',
            arguments: {'city': 'Paris'},
          ),
        ]),
        textResponse('Done.'),
      ]);
      final observedCalls = <String>[];
      final observedResults = <Object?>[];
      final runner = ToolRunner(
        provider: provider,
        tools: [weatherTool()],
        onToolCall: (call) => observedCalls.add(call.name),
        onToolResult: (call, result, {required isError}) =>
            observedResults.add(result),
      );

      await runner.run('Weather?');

      expect(observedCalls, ['get_weather']);
      expect(observedResults, ['sunny in Paris']);
    });
  });

  group('create', () {
    tearDown(() {
      // Restore the built-in factory replaced during the test.
      ProviderRegistry.register(AIProvider.openai, OpenAIProvider.new);
    });

    test('injects tool definitions into the provider config', () async {
      AIConfig? receivedConfig;
      ProviderRegistry.register(AIProvider.openai, (config) {
        receivedConfig = config;
        return provider;
      });
      stubChatSequence([textResponse('OK')]);

      final runner = ToolRunner.create(
        provider: AIProvider.openai,
        config: const AIConfig(apiKey: 'key'),
        tools: [weatherTool()],
      );
      await runner.run('Hi');

      expect(receivedConfig?.tools, hasLength(1));
      expect(receivedConfig?.tools?.single.name, 'get_weather');
    });
  });
}
