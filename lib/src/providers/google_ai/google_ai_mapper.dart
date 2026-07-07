import 'dart:convert';

import 'package:flutter_ai_sdk/src/config/config.dart';
import 'package:flutter_ai_sdk/src/errors/errors.dart';
import 'package:flutter_ai_sdk/src/models/models.dart';

/// Maps SDK models to and from the Google AI (Gemini) wire format.
///
/// Stateless translation layer used by `GoogleAIProvider`:
/// request building, response parsing and stream chunk decoding.
class GoogleAIMapper {
  /// Creates a [GoogleAIMapper].
  const GoogleAIMapper();

  /// Builds the request body for the Google AI generateContent API.
  Map<String, dynamic> buildRequestBody(
    List<Message> messages, {
    required AIConfig config,
  }) {
    // Separate system message from conversation
    var systemPrompt = config.systemPrompt;
    final conversationMessages = <Message>[];

    for (final message in messages) {
      if (message.role == MessageRole.system) {
        systemPrompt = message.text;
      } else {
        conversationMessages.add(message);
      }
    }

    final body = <String, dynamic>{
      'contents': conversationMessages.map(formatMessage).toList(),
    };

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemPrompt},
        ],
      };
    }

    // Generation config
    final generationConfig = <String, dynamic>{};
    if (config.maxTokens != null) {
      generationConfig['maxOutputTokens'] = config.maxTokens;
    }
    if (config.temperature != null) {
      generationConfig['temperature'] = config.temperature;
    }
    if (config.topP != null) {
      generationConfig['topP'] = config.topP;
    }
    if (config.stopSequences != null) {
      generationConfig['stopSequences'] = config.stopSequences;
    }
    if (config.responseFormat is JsonResponseFormat) {
      generationConfig['responseMimeType'] = 'application/json';
    }
    if (generationConfig.isNotEmpty) {
      body['generationConfig'] = generationConfig;
    }

    // Tools
    if (config.tools != null && config.tools!.isNotEmpty) {
      body['tools'] = [
        {
          'functionDeclarations':
              config.tools!.map((t) => t.toGoogleAIFormat()).toList(),
        },
      ];
      if (config.toolChoice != null) {
        body['toolConfig'] = {
          'functionCallingConfig': {
            'mode':
                config.toolChoice!.toProviderFormat(AIProviderType.googleAI),
          },
        };
      }
    }

    return body;
  }

  /// Formats a message for the Google AI API.
  Map<String, dynamic> formatMessage(Message message) {
    final role = switch (message.role) {
      MessageRole.user => 'user',
      MessageRole.assistant => 'model',
      MessageRole.tool => 'function',
      MessageRole.system => 'user', // Should be filtered out
    };

    // Handle tool results
    if (message.role == MessageRole.tool) {
      final toolResults =
          message.content.whereType<ToolResultContent>().toList();
      return {
        'role': role,
        'parts': toolResults
            .map(
              (tr) => {
                'functionResponse': {
                  'name': tr.name,
                  'response':
                      tr.result is Map ? tr.result : {'result': tr.result},
                },
              },
            )
            .toList(),
      };
    }

    // Handle content
    final parts = <Map<String, dynamic>>[];

    for (final content in message.content) {
      switch (content) {
        case TextContent(:final text):
          parts.add({'text': text});
        case ImageContent(:final url, :final data, :final mimeType):
          if (url != null) {
            parts.add({
              'fileData': {
                'fileUri': url,
                'mimeType': mimeType ?? 'image/png',
              },
            });
          } else if (data != null) {
            parts.add({
              'inlineData': {
                'mimeType': mimeType ?? 'image/png',
                'data': data,
              },
            });
          }
        case AudioContent(:final url, :final data, :final mimeType):
          if (url != null) {
            parts.add({
              'fileData': {
                'fileUri': url,
                'mimeType': mimeType,
              },
            });
          } else if (data != null) {
            parts.add({
              'inlineData': {
                'mimeType': mimeType,
                'data': data,
              },
            });
          }
        case DocumentContent(:final url, :final data, :final mimeType):
          if (url != null) {
            parts.add({
              'fileData': {
                'fileUri': url,
                'mimeType': mimeType,
              },
            });
          } else if (data != null) {
            parts.add({
              'inlineData': {
                'mimeType': mimeType,
                'data': data,
              },
            });
          }
        default:
          parts.add({'text': content.toString()});
      }
    }

    // Add function calls for assistant messages with tool calls
    if (message.role == MessageRole.assistant && message.hasToolCalls) {
      for (final toolCall in message.toolCalls!) {
        parts.add({
          'functionCall': {
            'name': toolCall.name,
            'args': toolCall.arguments,
          },
        });
      }
    }

    return {
      'role': role,
      'parts': parts,
    };
  }

  /// Parses a response body from the Google AI API.
  ///
  /// [model] is echoed into the response since the API does not return it.
  AIResponse parseResponse(Map<String, dynamic> data, {required String model}) {
    final candidates = data['candidates'] as List<dynamic>?;

    if (candidates == null || candidates.isEmpty) {
      // Check for safety blocking
      final promptFeedback = data['promptFeedback'] as Map<String, dynamic>?;
      final blockReason = promptFeedback?['blockReason'] as String?;
      if (blockReason != null) {
        throw AIContentFilterError(
          message: 'Content blocked: $blockReason',
          code: blockReason,
        );
      }
      throw const AIModelError(
        message: 'No candidates returned from Google AI',
        code: 'no_candidates',
      );
    }

    final candidate = candidates.first as Map<String, dynamic>;
    final candidateContent = candidate['content'] as Map<String, dynamic>?;
    final finishReasonStr = candidate['finishReason'] as String?;

    final content = <Content>[];
    final toolCalls = <ToolCallContent>[];

    if (candidateContent != null) {
      final parts = candidateContent['parts'] as List<dynamic>?;
      if (parts != null) {
        for (final part in parts) {
          final partMap = part as Map<String, dynamic>;
          if (partMap.containsKey('text')) {
            content.add(TextContent(partMap['text'] as String));
          } else if (partMap.containsKey('functionCall')) {
            final fc = partMap['functionCall'] as Map<String, dynamic>;
            toolCalls.add(
              ToolCallContent(
                id: '${fc['name']}_${DateTime.now().millisecondsSinceEpoch}',
                name: fc['name'] as String,
                arguments: (fc['args'] as Map<String, dynamic>?) ?? {},
              ),
            );
          }
        }
      }
    }

    // Parse usage
    Usage? usage;
    final usageData = data['usageMetadata'] as Map<String, dynamic>?;
    if (usageData != null) {
      usage = Usage(
        promptTokens: usageData['promptTokenCount'] as int? ?? 0,
        completionTokens: usageData['candidatesTokenCount'] as int? ?? 0,
        cachedTokens: usageData['cachedContentTokenCount'] as int?,
      );
    }

    return AIResponse(
      id: 'google-${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      finishReason: parseFinishReason(finishReasonStr),
      toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
      usage: usage,
      model: model,
      provider: AIProvider.googleAI,
      createdAt: DateTime.now(),
      metadata: {'raw': data},
    );
  }

  /// Parses a streaming SSE chunk from the Google AI API.
  StreamChunk? parseStreamChunk(String chunk) {
    // Handle SSE format
    if (!chunk.startsWith('data: ')) return null;

    final dataStr = chunk.substring(6).trim();
    if (dataStr.isEmpty) return null;

    try {
      final data = jsonDecode(dataStr) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;

      if (candidates == null || candidates.isEmpty) return null;

      final candidate = candidates.first as Map<String, dynamic>;
      final content = candidate['content'] as Map<String, dynamic>?;
      final finishReasonStr = candidate['finishReason'] as String?;

      // Check for finish
      if (finishReasonStr != null && finishReasonStr != 'STOP') {
        final usageData = data['usageMetadata'] as Map<String, dynamic>?;
        Usage? usage;
        if (usageData != null) {
          usage = Usage(
            promptTokens: usageData['promptTokenCount'] as int? ?? 0,
            completionTokens: usageData['candidatesTokenCount'] as int? ?? 0,
          );
        }
        return StreamChunk.done(
          finishReason: parseFinishReason(finishReasonStr),
          usage: usage,
        );
      }

      if (content == null) return null;

      final parts = content['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return null;

      final firstPart = parts.first as Map<String, dynamic>;

      // Text delta
      if (firstPart.containsKey('text')) {
        return StreamChunk.delta(firstPart['text'] as String);
      }

      // Function call
      if (firstPart.containsKey('functionCall')) {
        final fc = firstPart['functionCall'] as Map<String, dynamic>;
        return StreamChunk.toolCall(
          ToolCallContent(
            id: '${fc['name']}_${DateTime.now().millisecondsSinceEpoch}',
            name: fc['name'] as String,
            arguments: (fc['args'] as Map<String, dynamic>?) ?? {},
          ),
        );
      }

      return null;
    } catch (e) {
      return StreamChunk.error(e);
    }
  }

  /// Parses a finish reason string.
  FinishReason parseFinishReason(String? reason) => switch (reason) {
        'STOP' => FinishReason.stop,
        'MAX_TOKENS' => FinishReason.maxTokens,
        'SAFETY' => FinishReason.contentFilter,
        'RECITATION' => FinishReason.contentFilter,
        'FUNCTION_CALL' => FinishReason.toolCalls,
        _ => FinishReason.unknown,
      };
}
