import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/providers/base_provider.dart';
import 'package:flutter_ai_sdk/src/providers/provider_registry.dart';
import 'package:flutter_ai_sdk/src/runner/executable_tool.dart';

/// Thrown when a [ToolRunner] loop exceeds its iteration budget.
class ToolRunnerException implements Exception {
  /// Creates a [ToolRunnerException].
  const ToolRunnerException(this.message, {this.lastResponse});

  /// Description of the failure.
  final String message;

  /// The last model response before the loop was aborted.
  final AIResponse? lastResponse;

  @override
  String toString() => 'ToolRunnerException: $message';
}

/// The outcome of a [ToolRunner.run] loop.
class ToolRunResult {
  /// Creates a [ToolRunResult].
  const ToolRunResult({
    required this.response,
    required this.messages,
    required this.iterations,
  });

  /// The final model response (without tool calls).
  final AIResponse response;

  /// The full transcript: input history, assistant turns and tool results.
  final List<Message> messages;

  /// How many tool-execution rounds were performed.
  final int iterations;

  /// The text of the final response.
  String get text => response.text;
}

/// Runs the agentic tool-calling loop automatically.
///
/// Sends a prompt to the model, executes every tool call it requests via
/// the matching [ExecutableTool], feeds the results back, and repeats until
/// the model produces a final answer (or [maxIterations] is reached).
///
/// Tool calls within one model turn are executed in parallel; a failing
/// executor is reported to the model as an error result rather than
/// aborting the loop.
///
/// Example:
/// ```dart
/// final runner = ToolRunner.create(
///   provider: AIProvider.anthropic,
///   config: AIConfig(apiKey: 'sk-ant-...'),
///   tools: [weatherTool],
/// );
///
/// final result = await runner.run('What is the weather in Paris?');
/// print(result.text);
/// ```
class ToolRunner {
  /// Creates a [ToolRunner] around an already-built [provider].
  ///
  /// The provider's configuration must already carry the tool definitions
  /// (see [ToolRunner.create] which handles that wiring for you).
  ToolRunner({
    required this.provider,
    required List<ExecutableTool> tools,
    this.maxIterations = 5,
    this.onToolCall,
    this.onToolResult,
  }) : _tools = {for (final tool in tools) tool.name: tool};

  /// Builds the provider from the registry with the tool definitions
  /// injected into [config].
  factory ToolRunner.create({
    required AIProvider provider,
    required AIConfig config,
    required List<ExecutableTool> tools,
    ToolChoice? toolChoice,
    int maxIterations = 5,
    void Function(ToolCallContent call)? onToolCall,
    void Function(
      ToolCallContent call,
      Object? result, {
      required bool isError,
    })? onToolResult,
  }) {
    final toolConfig = config.copyWith(
      tools: [for (final tool in tools) tool.definition],
      toolChoice: toolChoice,
    );
    return ToolRunner(
      provider: ProviderRegistry.create(provider, toolConfig),
      tools: tools,
      maxIterations: maxIterations,
      onToolCall: onToolCall,
      onToolResult: onToolResult,
    );
  }

  /// The provider used for every model turn.
  final BaseProvider provider;

  /// Maximum number of tool-execution rounds before aborting.
  final int maxIterations;

  /// Called before a tool is executed.
  final void Function(ToolCallContent call)? onToolCall;

  /// Called after a tool has executed (successfully or not).
  final void Function(
    ToolCallContent call,
    Object? result, {
    required bool isError,
  })? onToolResult;

  final Map<String, ExecutableTool> _tools;

  /// Runs the loop for [prompt], optionally continuing from [history].
  ///
  /// Returns the final response together with the full transcript.
  /// Throws a [ToolRunnerException] if the model still requests tools
  /// after [maxIterations] rounds.
  Future<ToolRunResult> run(String prompt, {List<Message>? history}) async {
    final messages = <Message>[...?history, Message.user(prompt)];

    var response = await provider.chat(messages);
    var iterations = 0;

    while (response.hasToolCalls) {
      if (iterations >= maxIterations) {
        throw ToolRunnerException(
          'Tool loop did not converge after $maxIterations iterations',
          lastResponse: response,
        );
      }
      iterations++;

      messages.add(
        Message.assistant(response.text, toolCalls: response.toolCalls),
      );

      // Execute every requested tool call in parallel, then send all
      // results back in a single tool message (required by providers
      // that enforce role alternation, like Anthropic).
      final results = await Future.wait(
        response.toolCalls!.map(_executeCall),
      );
      messages.add(Message(role: MessageRole.tool, content: results));

      response = await provider.chat(messages);
    }

    return ToolRunResult(
      response: response,
      messages: messages,
      iterations: iterations,
    );
  }

  Future<ToolResultContent> _executeCall(ToolCallContent call) async {
    onToolCall?.call(call);

    final tool = _tools[call.name];
    if (tool == null) {
      const error = 'Unknown tool';
      onToolResult?.call(call, error, isError: true);
      return ToolResultContent(
        toolCallId: call.id,
        name: call.name,
        result: '$error: ${call.name}',
        isError: true,
      );
    }

    try {
      final result = await Future.sync(() => tool.executor(call.arguments));
      onToolResult?.call(call, result, isError: false);
      return ToolResultContent(
        toolCallId: call.id,
        name: call.name,
        result: result,
      );
    } catch (e) {
      onToolResult?.call(call, e, isError: true);
      return ToolResultContent(
        toolCallId: call.id,
        name: call.name,
        result: 'Tool execution failed: $e',
        isError: true,
      );
    }
  }
}
