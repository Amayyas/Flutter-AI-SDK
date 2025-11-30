import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:flutter_ai_sdk/src/config/ai_config.dart';
import 'package:flutter_ai_sdk/src/errors/errors.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/providers/base_provider.dart';
import 'package:flutter_ai_sdk/src/utils/http_client.dart';

/// OpenAI API provider implementation.
///
/// Supports GPT-4, GPT-3.5, and other OpenAI models with full
/// support for streaming, vision, and function calling.
///
/// Example:
/// ```dart
/// final provider = OpenAIProvider(
///   AIConfig(
///     apiKey: 'sk-...',
///     model: 'gpt-4-turbo',
///   ),
/// );
///
/// final response = await provider.chat([
///   Message.user('Hello!'),
/// ]);
/// ```
class OpenAIProvider extends BaseProvider {
  /// Creates an [OpenAIProvider].
  OpenAIProvider(super.config) : _client = AIHttpClient(config);

  final AIHttpClient _client;

  @override
  AIProvider get providerType => AIProvider.openai;

  @override
  String get defaultModel => DefaultModels.openai;

  @override
  Set<ModelCapability> get capabilities => {
        ModelCapability.text,
        ModelCapability.vision,
        ModelCapability.tools,
        ModelCapability.jsonMode,
        ModelCapability.streaming,
        ModelCapability.systemPrompt,
      };

  /// OpenAI API endpoint for chat completions.
  String get _chatEndpoint {
    final base = config.baseUrl ?? APIEndpoints.openai;
    return '$base/chat/completions';
  }

  @override
  Future<AIResponse> chat(List<Message> messages) async {
    validateConfig();

    final body = _buildRequestBody(messages, stream: false);
    final response = await _client.post(_chatEndpoint, body: body);

    return _parseResponse(response);
  }

  @override
  Stream<StreamChunk> streamChat(List<Message> messages) async* {
    validateConfig();

    final body = _buildRequestBody(messages, stream: true);

    yield const StreamChunk.start();

    final buffer = StringBuffer();
    FinishReason? finishReason;
    Usage? usage;

    await for (final chunk in _client.postStream(_chatEndpoint, body: body)) {
      final parsed = _parseStreamChunk(chunk);
      if (parsed != null) {
        if (parsed.isDelta && parsed.delta != null) {
          buffer.write(parsed.delta);
        }
        if (parsed.finishReason != null) {
          finishReason = parsed.finishReason;
        }
        if (parsed.usage != null) {
          usage = parsed.usage;
        }
        yield parsed;
      }
    }

    yield StreamChunk.done(
      usage: usage,
      finishReason: finishReason ?? FinishReason.stop,
    );
  }

  /// Builds the request body for the OpenAI API.
  Map<String, dynamic> _buildRequestBody(
    List<Message> messages, {
    required bool stream,
  }) {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages.map(_formatMessage).toList(),
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
      body['response_format'] = config.responseFormat!.toJson();
    }

    return body;
  }

  /// Formats a message for the OpenAI API.
  Map<String, dynamic> _formatMessage(Message message) {
    final formatted = <String, dynamic>{
      'role': message.role.name,
    };

    // Handle different content types
    if (message.isTextOnly) {
      formatted['content'] = message.text;
    } else {
      formatted['content'] = message.content.map(_formatContent).toList();
    }

    if (message.name != null) {
      formatted['name'] = message.name;
    }

    // Handle tool calls
    if (message.hasToolCalls) {
      formatted['tool_calls'] = message.toolCalls!
          .map((tc) => {
                'id': tc.id,
                'type': 'function',
                'function': {
                  'name': tc.name,
                  'arguments': jsonEncode(tc.arguments),
                },
              })
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
  Map<String, dynamic> _formatContent(Content content) {
    switch (content) {
      case TextContent(:final text):
        return {'type': 'text', 'text': text};
      case ImageContent():
        return content.toJson();
      case AudioContent():
        return content.toJson();
      default:
        return {'type': 'text', 'text': content.toString()};
    }
  }

  /// Parses a response from the OpenAI API.
  AIResponse _parseResponse(Response<dynamic> response) {
    final data = response.data as Map<String, dynamic>;
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
    Usage? usage;
    final usageData = data['usage'] as Map<String, dynamic>?;
    if (usageData != null) {
      usage = Usage.fromJson(usageData);
    }

    return AIResponse(
      id: data['id'] as String,
      content: content,
      finishReason: _parseFinishReason(finishReasonStr),
      toolCalls: toolCalls,
      usage: usage,
      model: data['model'] as String?,
      provider: providerType,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (data['created'] as int) * 1000,
      ),
      metadata: {'raw': data},
    );
  }

  /// Parses a streaming chunk from the OpenAI API.
  StreamChunk? _parseStreamChunk(String chunk) {
    // Handle SSE format
    if (!chunk.startsWith('data: ')) return null;

    final dataStr = chunk.substring(6).trim();
    if (dataStr == '[DONE]') return null;

    try {
      final data = jsonDecode(dataStr) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;

      if (choices == null || choices.isEmpty) {
        // Check for usage data
        final usageData = data['usage'] as Map<String, dynamic>?;
        if (usageData != null) {
          return StreamChunk.done(usage: Usage.fromJson(usageData));
        }
        return null;
      }

      final choice = choices.first as Map<String, dynamic>;
      final delta = choice['delta'] as Map<String, dynamic>?;
      final finishReasonStr = choice['finish_reason'] as String?;

      if (finishReasonStr != null) {
        final usageData = data['usage'] as Map<String, dynamic>?;
        return StreamChunk.done(
          finishReason: _parseFinishReason(finishReasonStr),
          usage: usageData != null ? Usage.fromJson(usageData) : null,
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

  /// Parses a finish reason string.
  FinishReason _parseFinishReason(String? reason) => switch (reason) {
        'stop' => FinishReason.stop,
        'length' => FinishReason.maxTokens,
        'content_filter' => FinishReason.contentFilter,
        'tool_calls' => FinishReason.toolCalls,
        _ => FinishReason.unknown,
      };

  @override
  void dispose() {
    _client.dispose();
  }
}
