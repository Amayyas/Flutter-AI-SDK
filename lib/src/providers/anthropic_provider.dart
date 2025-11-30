import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:flutter_ai_sdk/src/config/ai_config.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';
import 'package:flutter_ai_sdk/src/providers/base_provider.dart';
import 'package:flutter_ai_sdk/src/utils/http_client.dart';

/// Anthropic (Claude) API provider implementation.
///
/// Supports Claude 3 models (Opus, Sonnet, Haiku) with full
/// support for streaming, vision, and tool use.
///
/// Example:
/// ```dart
/// final provider = AnthropicProvider(
///   AIConfig(
///     apiKey: 'sk-ant-...',
///     model: 'claude-3-5-sonnet-latest',
///   ),
/// );
///
/// final response = await provider.chat([
///   Message.user('Hello!'),
/// ]);
/// ```
class AnthropicProvider extends BaseProvider {
  /// Creates an [AnthropicProvider].
  AnthropicProvider(super.config) : _client = AIHttpClient(config);

  final AIHttpClient _client;

  /// Current Anthropic API version.
  static const String apiVersion = '2023-06-01';

  @override
  AIProvider get providerType => AIProvider.anthropic;

  @override
  String get defaultModel => DefaultModels.anthropic;

  @override
  Set<ModelCapability> get capabilities => {
        ModelCapability.text,
        ModelCapability.vision,
        ModelCapability.tools,
        ModelCapability.streaming,
        ModelCapability.systemPrompt,
      };

  /// Anthropic API endpoint for messages.
  String get _messagesEndpoint {
    final base = config.baseUrl ?? APIEndpoints.anthropic;
    return '$base/messages';
  }

  /// Custom headers for Anthropic API.
  Map<String, String> get _headers => {
        'x-api-key': config.apiKey,
        'anthropic-version': apiVersion,
        'content-type': 'application/json',
        ...?config.headers,
      };

  @override
  Future<AIResponse> chat(List<Message> messages) async {
    validateConfig();

    final body = _buildRequestBody(messages, stream: false);
    final response = await _client.post(
      _messagesEndpoint,
      body: body,
      headers: _headers,
    );

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

    await for (final chunk in _client.postStream(
      _messagesEndpoint,
      body: body,
      headers: _headers,
    )) {
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

  /// Builds the request body for the Anthropic API.
  Map<String, dynamic> _buildRequestBody(
    List<Message> messages, {
    required bool stream,
  }) {
    // Separate system message from conversation
    String? systemPrompt = config.systemPrompt;
    final conversationMessages = <Message>[];

    for (final message in messages) {
      if (message.role == MessageRole.system) {
        systemPrompt = message.text;
      } else {
        conversationMessages.add(message);
      }
    }

    final body = <String, dynamic>{
      'model': model,
      'messages': conversationMessages.map(_formatMessage).toList(),
      'stream': stream,
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['system'] = systemPrompt;
    }

    if (config.maxTokens != null) {
      body['max_tokens'] = config.maxTokens;
    } else {
      // Anthropic requires max_tokens
      body['max_tokens'] = 4096;
    }

    if (config.temperature != null) {
      body['temperature'] = config.temperature;
    }
    if (config.topP != null) {
      body['top_p'] = config.topP;
    }
    if (config.stopSequences != null) {
      body['stop_sequences'] = config.stopSequences;
    }
    if (config.tools != null && config.tools!.isNotEmpty) {
      body['tools'] = config.tools!.map((t) => t.toAnthropicFormat()).toList();
      if (config.toolChoice != null) {
        body['tool_choice'] =
            config.toolChoice!.toProviderFormat(AIProviderType.anthropic);
      }
    }

    return body;
  }

  /// Formats a message for the Anthropic API.
  Map<String, dynamic> _formatMessage(Message message) {
    final role = switch (message.role) {
      MessageRole.user => 'user',
      MessageRole.assistant => 'assistant',
      MessageRole.tool => 'user', // Tool results are sent as user messages
      MessageRole.system => 'user', // Should be filtered out
    };

    // Handle tool results
    if (message.role == MessageRole.tool) {
      final toolResults =
          message.content.whereType<ToolResultContent>().toList();
      return {
        'role': role,
        'content': toolResults
            .map((tr) => {
                  'type': 'tool_result',
                  'tool_use_id': tr.toolCallId,
                  'content':
                      tr.result is String ? tr.result : jsonEncode(tr.result),
                  if (tr.isError) 'is_error': true,
                })
            .toList(),
      };
    }

    // Handle content
    final content = message.content.map(_formatContent).toList();

    // Add tool use blocks for assistant messages with tool calls
    if (message.role == MessageRole.assistant && message.hasToolCalls) {
      for (final toolCall in message.toolCalls!) {
        content.add({
          'type': 'tool_use',
          'id': toolCall.id,
          'name': toolCall.name,
          'input': toolCall.arguments,
        });
      }
    }

    return {
      'role': role,
      'content': content,
    };
  }

  /// Formats content for the Anthropic API.
  Map<String, dynamic> _formatContent(Content content) {
    switch (content) {
      case TextContent(:final text):
        return {'type': 'text', 'text': text};
      case ImageContent(:final url, :final data, :final mimeType):
        if (url != null) {
          return {
            'type': 'image',
            'source': {
              'type': 'url',
              'url': url,
            },
          };
        }
        return {
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': mimeType ?? 'image/png',
            'data': data,
          },
        };
      case DocumentContent(:final data, :final mimeType, :final name):
        return {
          'type': 'document',
          'source': {
            'type': 'base64',
            'media_type': mimeType,
            'data': data,
          },
          if (name != null) 'name': name,
        };
      default:
        return {'type': 'text', 'text': content.toString()};
    }
  }

  /// Parses a response from the Anthropic API.
  AIResponse _parseResponse(Response<dynamic> response) {
    final data = response.data as Map<String, dynamic>;

    final contentList = data['content'] as List<dynamic>;
    final content = <Content>[];
    final toolCalls = <ToolCallContent>[];

    for (final item in contentList) {
      final itemMap = item as Map<String, dynamic>;
      final type = itemMap['type'] as String;

      switch (type) {
        case 'text':
          content.add(TextContent(itemMap['text'] as String));
        case 'tool_use':
          toolCalls.add(ToolCallContent(
            id: itemMap['id'] as String,
            name: itemMap['name'] as String,
            arguments: itemMap['input'] as Map<String, dynamic>,
          ));
      }
    }

    final stopReasonStr = data['stop_reason'] as String?;
    final usageData = data['usage'] as Map<String, dynamic>?;

    Usage? usage;
    if (usageData != null) {
      usage = Usage(
        promptTokens: usageData['input_tokens'] as int? ?? 0,
        completionTokens: usageData['output_tokens'] as int? ?? 0,
      );
    }

    return AIResponse(
      id: data['id'] as String,
      content: content,
      finishReason: _parseStopReason(stopReasonStr),
      toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
      usage: usage,
      model: data['model'] as String?,
      provider: providerType,
      createdAt: DateTime.now(),
      metadata: {'raw': data},
    );
  }

  /// Parses a streaming chunk from the Anthropic API.
  StreamChunk? _parseStreamChunk(String chunk) {
    // Handle SSE format
    if (!chunk.startsWith('data: ')) return null;

    final dataStr = chunk.substring(6).trim();
    if (dataStr.isEmpty) return null;

    try {
      final data = jsonDecode(dataStr) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'content_block_delta':
          final delta = data['delta'] as Map<String, dynamic>?;
          if (delta != null) {
            final deltaType = delta['type'] as String?;
            if (deltaType == 'text_delta') {
              return StreamChunk.delta(delta['text'] as String);
            }
            if (deltaType == 'input_json_delta') {
              return StreamChunk(
                type: StreamEventType.toolCallDelta,
                metadata: {'partial_json': delta['partial_json']},
              );
            }
          }

        case 'message_delta':
          final delta = data['delta'] as Map<String, dynamic>?;
          final stopReason = delta?['stop_reason'] as String?;
          final usageData = data['usage'] as Map<String, dynamic>?;

          if (stopReason != null || usageData != null) {
            Usage? usage;
            if (usageData != null) {
              usage = Usage(
                promptTokens: usageData['input_tokens'] as int? ?? 0,
                completionTokens: usageData['output_tokens'] as int? ?? 0,
              );
            }
            return StreamChunk.done(
              finishReason: _parseStopReason(stopReason),
              usage: usage,
            );
          }

        case 'message_stop':
          return const StreamChunk.done();
      }

      return null;
    } catch (e) {
      return StreamChunk.error(e);
    }
  }

  /// Parses a stop reason string.
  FinishReason _parseStopReason(String? reason) => switch (reason) {
        'end_turn' => FinishReason.stop,
        'stop_sequence' => FinishReason.stop,
        'max_tokens' => FinishReason.maxTokens,
        'tool_use' => FinishReason.toolCalls,
        _ => FinishReason.unknown,
      };

  @override
  void dispose() {
    _client.dispose();
  }
}
