import 'dart:convert';

import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';

/// Maps SDK models to and from the Ollama native wire format.
///
/// Stateless translation layer used by `OllamaProvider`:
/// request building, response parsing and stream chunk decoding.
///
/// Ollama streams NDJSON (one JSON object per line) rather than SSE,
/// and its tool schema follows the OpenAI function format.
class OllamaMapper {
  /// Creates an [OllamaMapper].
  const OllamaMapper();

  /// Builds the request body for the Ollama chat API.
  Map<String, dynamic> buildRequestBody(
    List<Message> messages, {
    required AIConfig config,
    required String model,
    required bool stream,
  }) {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages.map(formatMessage).toList(),
      'stream': stream,
    };

    // Sampling and generation parameters live under `options`.
    final options = <String, dynamic>{};
    if (config.maxTokens != null) {
      options['num_predict'] = config.maxTokens;
    }
    if (config.temperature != null) {
      options['temperature'] = config.temperature;
    }
    if (config.topP != null) {
      options['top_p'] = config.topP;
    }
    if (config.stopSequences != null) {
      options['stop'] = config.stopSequences;
    }
    if (options.isNotEmpty) {
      body['options'] = options;
    }

    if (config.responseFormat is JsonResponseFormat) {
      body['format'] = 'json';
    }

    // Ollama uses the OpenAI function schema for tools.
    if (config.tools != null && config.tools!.isNotEmpty) {
      body['tools'] = config.tools!.map((t) => t.toOpenAIFormat()).toList();
    }

    return body;
  }

  /// Formats a message for the Ollama API.
  Map<String, dynamic> formatMessage(Message message) {
    // Handle tool results
    if (message.role == MessageRole.tool) {
      final toolResult = message.content.whereType<ToolResultContent>().first;
      return {
        'role': 'tool',
        'tool_name': toolResult.name,
        'content': toolResult.result is String
            ? toolResult.result
            : jsonEncode(toolResult.result),
      };
    }

    final formatted = <String, dynamic>{
      'role': message.role.name,
      'content': message.content
          .whereType<TextContent>()
          .map((c) => c.text)
          .join('\n'),
    };

    // Ollama accepts images as base64 payloads only.
    final images = message.content
        .whereType<ImageContent>()
        .map((image) => image.data)
        .whereType<String>()
        .toList();
    if (images.isNotEmpty) {
      formatted['images'] = images;
    }

    // Handle tool calls made by the assistant
    if (message.hasToolCalls) {
      formatted['tool_calls'] = message.toolCalls!
          .map(
            (tc) => {
              'function': {
                'name': tc.name,
                'arguments': tc.arguments,
              },
            },
          )
          .toList();
    }

    return formatted;
  }

  /// Parses a response body from the Ollama API.
  AIResponse parseResponse(Map<String, dynamic> data) {
    final message = data['message'] as Map<String, dynamic>?;

    final content = <Content>[];
    final messageContent = message?['content'] as String?;
    if (messageContent != null && messageContent.isNotEmpty) {
      content.add(TextContent(messageContent));
    }

    final toolCalls = parseToolCalls(message?['tool_calls'] as List<dynamic>?);

    final doneReason = data['done_reason'] as String?;
    final finishReason = toolCalls != null
        ? FinishReason.toolCalls
        : parseDoneReason(doneReason);

    return AIResponse(
      id: 'ollama-${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      finishReason: finishReason,
      toolCalls: toolCalls,
      usage: parseUsage(data),
      model: data['model'] as String?,
      provider: AIProvider.ollama,
      createdAt:
          DateTime.tryParse(data['created_at'] as String? ?? '') ??
              DateTime.now(),
      metadata: {'raw': data},
    );
  }

  /// Parses a streaming NDJSON line from the Ollama API.
  StreamChunk? parseStreamChunk(String chunk) {
    final line = chunk.trim();
    if (line.isEmpty) return null;

    try {
      final data = jsonDecode(line) as Map<String, dynamic>;

      if (data['done'] == true) {
        return StreamChunk.done(
          finishReason: parseDoneReason(data['done_reason'] as String?),
          usage: parseUsage(data),
        );
      }

      final message = data['message'] as Map<String, dynamic>?;
      if (message == null) return null;

      final toolCalls = parseToolCalls(message['tool_calls'] as List<dynamic>?);
      if (toolCalls != null) {
        return StreamChunk.toolCall(toolCalls.first);
      }

      final content = message['content'] as String?;
      if (content != null && content.isNotEmpty) {
        return StreamChunk.delta(content);
      }

      return null;
    } catch (e) {
      return StreamChunk.error(e);
    }
  }

  /// Parses tool calls from an Ollama message.
  ///
  /// Ollama does not assign call IDs, so one is generated per call.
  List<ToolCallContent>? parseToolCalls(List<dynamic>? toolCallsData) {
    if (toolCallsData == null || toolCallsData.isEmpty) return null;

    return toolCallsData.map((tc) {
      final function =
          (tc as Map<String, dynamic>)['function'] as Map<String, dynamic>;
      final name = function['name'] as String;
      return ToolCallContent(
        id: '${name}_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        arguments: (function['arguments'] as Map<String, dynamic>?) ?? {},
      );
    }).toList();
  }

  /// Parses token usage counters when present.
  Usage? parseUsage(Map<String, dynamic> data) {
    final promptTokens = data['prompt_eval_count'] as int?;
    final completionTokens = data['eval_count'] as int?;
    if (promptTokens == null && completionTokens == null) return null;

    return Usage(
      promptTokens: promptTokens ?? 0,
      completionTokens: completionTokens ?? 0,
    );
  }

  /// Parses a done reason string.
  FinishReason parseDoneReason(String? reason) => switch (reason) {
        'stop' => FinishReason.stop,
        'length' => FinishReason.maxTokens,
        _ => FinishReason.unknown,
      };
}
