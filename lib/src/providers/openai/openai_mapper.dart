import 'dart:convert';

import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/errors/errors.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';

/// Maps SDK models to and from the OpenAI wire format.
///
/// Stateless translation layer used by `OpenAIProvider`:
/// request building, response parsing and stream chunk decoding.
class OpenAIMapper {
  /// Creates an [OpenAIMapper].
  const OpenAIMapper();

  /// Builds the request body for the OpenAI chat completions API.
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

    if (stream) {
      body['stream_options'] = {'include_usage': true};
    }

    if (config.maxTokens != null) {
      body['max_tokens'] = config.maxTokens;
    }
    if (config.temperature != null) {
      body['temperature'] = config.temperature;
    }
    if (config.topP != null) {
      body['top_p'] = config.topP;
    }
    if (config.frequencyPenalty != null) {
      body['frequency_penalty'] = config.frequencyPenalty;
    }
    if (config.presencePenalty != null) {
      body['presence_penalty'] = config.presencePenalty;
    }
    if (config.stopSequences != null) {
      body['stop'] = config.stopSequences;
    }
    if (config.tools != null && config.tools!.isNotEmpty) {
      body['tools'] = config.tools!.map((t) => t.toOpenAIFormat()).toList();
      if (config.toolChoice != null) {
        body['tool_choice'] =
            config.toolChoice!.toProviderFormat(AIProviderType.openai);
      }
    }
    if (config.responseFormat != null) {
      body['response_format'] = formatResponseFormat(config.responseFormat!);
    }

    return body;
  }

  /// Formats a response format for the OpenAI API.
  ///
  /// A [JsonResponseFormat] with a schema uses the structured outputs
  /// `json_schema` type (guaranteed schema); without a schema it falls
  /// back to the legacy `json_object` JSON mode.
  Map<String, dynamic> formatResponseFormat(ResponseFormat format) =>
      switch (format) {
        JsonResponseFormat(:final schema, :final strict) when schema != null =>
          {
            'type': 'json_schema',
            'json_schema': {
              'name': 'response',
              if (strict) 'strict': true,
              'schema': schema,
            },
          },
        JsonResponseFormat() => {'type': 'json_object'},
        TextResponseFormat() => {'type': 'text'},
      };

  /// Formats a message for the OpenAI API.
  Map<String, dynamic> formatMessage(Message message) {
    final formatted = <String, dynamic>{
      'role': message.role.name,
    };

    // Handle different content types
    if (message.isTextOnly) {
      formatted['content'] = message.text;
    } else {
      formatted['content'] = message.content.map(formatContent).toList();
    }

    if (message.name != null) {
      formatted['name'] = message.name;
    }

    // Handle tool calls
    if (message.hasToolCalls) {
      formatted['tool_calls'] = message.toolCalls!
          .map(
            (tc) => {
              'id': tc.id,
              'type': 'function',
              'function': {
                'name': tc.name,
                'arguments': jsonEncode(tc.arguments),
              },
            },
          )
          .toList();
    }

    // Handle tool results
    if (message.role == MessageRole.tool) {
      final toolResult = message.content.whereType<ToolResultContent>().first;
      formatted['tool_call_id'] = toolResult.toolCallId;
      formatted['content'] = jsonEncode(toolResult.result);
    }

    return formatted;
  }

  /// Formats content for the OpenAI API.
  Map<String, dynamic> formatContent(Content content) {
    switch (content) {
      case TextContent(:final text):
        return {'type': 'text', 'text': text};
      case ImageContent():
        return content.toJson();
      case AudioContent():
        return content.toJson();
      case DocumentContent(
          :final url,
          :final data,
          :final mimeType,
          :final name
        ):
        // OpenAI chat completions accept documents as base64 data URLs.
        // URL-only documents are passed as a text reference (no native
        // support) — see the document support table in the README.
        if (data != null) {
          return {
            'type': 'file',
            'file': {
              'filename': name ?? 'document',
              'file_data': 'data:$mimeType;base64,$data',
            },
          };
        }
        return {'type': 'text', 'text': 'Document: $url'};
      default:
        return {'type': 'text', 'text': content.toString()};
    }
  }

  /// Parses a response body from the OpenAI API.
  AIResponse parseResponse(Map<String, dynamic> data) {
    final choices = data['choices'] as List<dynamic>;

    if (choices.isEmpty) {
      throw const AIModelError(
        message: 'No choices returned from OpenAI',
        code: 'no_choices',
      );
    }

    final choice = choices.first as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>;
    final finishReasonStr = choice['finish_reason'] as String?;

    // Parse content
    final content = <Content>[];
    final messageContent = message['content'];
    if (messageContent is String) {
      content.add(TextContent(messageContent));
    }

    // Parse tool calls
    List<ToolCallContent>? toolCalls;
    final toolCallsData = message['tool_calls'] as List<dynamic>?;
    if (toolCallsData != null) {
      toolCalls = toolCallsData.map((tc) {
        final tcMap = tc as Map<String, dynamic>;
        final function = tcMap['function'] as Map<String, dynamic>;
        return ToolCallContent(
          id: tcMap['id'] as String,
          name: function['name'] as String,
          arguments: jsonDecode(function['arguments'] as String)
              as Map<String, dynamic>,
        );
      }).toList();
    }

    // Parse usage
    final usage = parseUsage(data['usage'] as Map<String, dynamic>?);

    return AIResponse(
      id: data['id'] as String,
      content: content,
      finishReason: parseFinishReason(finishReasonStr),
      toolCalls: toolCalls,
      usage: usage,
      model: data['model'] as String?,
      provider: AIProvider.openai,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (data['created'] as int) * 1000,
      ),
      metadata: {'raw': data},
    );
  }

  /// Parses a streaming SSE chunk from the OpenAI API.
  StreamChunk? parseStreamChunk(String chunk) {
    // Handle SSE format
    if (!chunk.startsWith('data: ')) return null;

    final dataStr = chunk.substring(6).trim();
    if (dataStr == '[DONE]') return null;

    try {
      final data = jsonDecode(dataStr) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;

      if (choices == null || choices.isEmpty) {
        // Check for usage data
        final usage = parseUsage(data['usage'] as Map<String, dynamic>?);
        if (usage != null) {
          return StreamChunk.done(usage: usage);
        }
        return null;
      }

      final choice = choices.first as Map<String, dynamic>;
      final delta = choice['delta'] as Map<String, dynamic>?;
      final finishReasonStr = choice['finish_reason'] as String?;

      if (finishReasonStr != null) {
        return StreamChunk.done(
          finishReason: parseFinishReason(finishReasonStr),
          usage: parseUsage(data['usage'] as Map<String, dynamic>?),
        );
      }

      if (delta == null) return null;

      final content = delta['content'] as String?;
      if (content != null) {
        return StreamChunk.delta(content);
      }

      // Handle tool calls in stream
      final toolCalls = delta['tool_calls'] as List<dynamic>?;
      if (toolCalls != null && toolCalls.isNotEmpty) {
        final tc = toolCalls.first as Map<String, dynamic>;
        final function = tc['function'] as Map<String, dynamic>?;
        if (function != null) {
          final args = function['arguments'] as String?;
          if (args != null) {
            // For streaming, we get partial arguments
            return StreamChunk(
              type: StreamEventType.toolCallDelta,
              metadata: {'partial_args': args},
            );
          }
        }
      }

      return null;
    } catch (e) {
      return StreamChunk.error(e);
    }
  }

  /// Parses usage counters, including automatic prompt cache hits.
  Usage? parseUsage(Map<String, dynamic>? usageData) {
    if (usageData == null) return null;
    final details = usageData['prompt_tokens_details'] as Map<String, dynamic>?;
    var usage = Usage.fromJson(usageData);
    final cached = details?['cached_tokens'] as int?;
    if (cached != null) {
      usage = usage.copyWith(cachedTokens: cached);
    }
    return usage;
  }

  /// Parses a finish reason string.
  FinishReason parseFinishReason(String? reason) => switch (reason) {
        'stop' => FinishReason.stop,
        'length' => FinishReason.maxTokens,
        'content_filter' => FinishReason.contentFilter,
        'tool_calls' => FinishReason.toolCalls,
        _ => FinishReason.unknown,
      };
}
