import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('AIConfig', () {
    test('creates with required apiKey', () {
      final config = AIConfig(apiKey: 'test-key');

      expect(config.apiKey, 'test-key');
      expect(config.model, isNull);
      expect(config.temperature, isNull);
      expect(config.maxTokens, isNull);
    });

    test('creates with all parameters', () {
      final config = AIConfig(
        apiKey: 'test-key',
        model: 'gpt-4',
        temperature: 0.7,
        maxTokens: 1000,
        topP: 0.9,
        presencePenalty: 0.1,
        frequencyPenalty: 0.2,
        systemPrompt: 'You are helpful.',
        stopSequences: ['END'],
        timeout: const Duration(seconds: 60),
        baseUrl: 'https://custom.api.com',
      );

      expect(config.apiKey, 'test-key');
      expect(config.model, 'gpt-4');
      expect(config.temperature, 0.7);
      expect(config.maxTokens, 1000);
      expect(config.topP, 0.9);
      expect(config.presencePenalty, 0.1);
      expect(config.frequencyPenalty, 0.2);
      expect(config.systemPrompt, 'You are helpful.');
      expect(config.stopSequences, ['END']);
      expect(config.timeout, const Duration(seconds: 60));
      expect(config.baseUrl, 'https://custom.api.com');
    });

    test('copyWith creates modified copy', () {
      final original = AIConfig(
        apiKey: 'original-key',
        model: 'gpt-3.5',
        temperature: 0.5,
      );

      final modified = original.copyWith(
        model: 'gpt-4',
        maxTokens: 2000,
      );

      expect(modified.apiKey, 'original-key');
      expect(modified.model, 'gpt-4');
      expect(modified.temperature, 0.5);
      expect(modified.maxTokens, 2000);
    });

    test('copyWith preserves original values when not specified', () {
      final original = AIConfig(
        apiKey: 'key',
        model: 'gpt-4',
        temperature: 0.7,
        maxTokens: 1000,
        systemPrompt: 'Hello',
      );

      final modified = original.copyWith(temperature: 0.9);

      expect(modified.apiKey, 'key');
      expect(modified.model, 'gpt-4');
      expect(modified.temperature, 0.9);
      expect(modified.maxTokens, 1000);
      expect(modified.systemPrompt, 'Hello');
    });

    test('equality', () {
      final config1 = AIConfig(apiKey: 'key', model: 'gpt-4');
      final config2 = AIConfig(apiKey: 'key', model: 'gpt-4');
      final config3 = AIConfig(apiKey: 'key', model: 'gpt-3.5');

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
    });

    test('toJson serializes correctly', () {
      final config = AIConfig(
        apiKey: 'test-key',
        model: 'gpt-4',
        temperature: 0.7,
        maxTokens: 1000,
        systemPrompt: 'Be helpful',
        stopSequences: ['END', 'STOP'],
      );

      final json = config.toJson();

      expect(json['model'], 'gpt-4');
      expect(json['temperature'], 0.7);
      expect(json['max_tokens'], 1000);
      expect(json['system_prompt'], 'Be helpful');
      expect(json['stop'], ['END', 'STOP']);
    });

    test('toJson omits null values', () {
      final config = AIConfig(apiKey: 'test-key', model: 'gpt-4');

      final json = config.toJson();

      expect(json['model'], 'gpt-4');
      expect(json.containsKey('temperature'), isFalse);
      expect(json.containsKey('max_tokens'), isFalse);
      expect(json.containsKey('system_prompt'), isFalse);
    });

    test('supports tools configuration', () {
      final tool = Tool(
        name: 'calculator',
        description: 'A calculator',
        parameters: ToolParameters(
          properties: {
            'expression': ToolProperty.string(
              description: 'Math expression to evaluate',
            ),
          },
          required: ['expression'],
        ),
      );

      final config = AIConfig(
        apiKey: 'key',
        tools: [tool],
        toolChoice: ToolChoice.auto(),
      );

      expect(config.tools, hasLength(1));
      expect(config.tools!.first.name, 'calculator');
      expect(config.toolChoice, isA<AutoToolChoice>());
    });

    test('supports metadata', () {
      final config = AIConfig(
        apiKey: 'key',
        metadata: {'user_id': '123', 'session': 'abc'},
      );

      expect(config.metadata, {'user_id': '123', 'session': 'abc'});
    });

    test('supports custom headers', () {
      final config = AIConfig(
        apiKey: 'key',
        headers: {'X-Custom-Header': 'value'},
      );

      expect(config.headers, {'X-Custom-Header': 'value'});
    });
  });

  group('ResponseFormat', () {
    test('text() creates text format', () {
      final format = ResponseFormat.text();
      expect(format, isA<TextResponseFormat>());
    });

    test('text() toJson returns correct format', () {
      final format = ResponseFormat.text();
      expect(format.toJson(), {'type': 'text'});
    });

    test('json() creates JSON format', () {
      final format = ResponseFormat.json();
      expect(format, isA<JsonResponseFormat>());
    });

    test('json() toJson returns correct format', () {
      final format = ResponseFormat.json();
      expect(format.toJson(), {'type': 'json_object'});
    });

    test('json() with schema includes schema in toJson', () {
      final format = ResponseFormat.json(
        schema: {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
          },
        },
      );

      final json = format.toJson();
      expect(json['type'], 'json_object');
      expect(json['schema'], isNotNull);
      expect(json['schema']['type'], 'object');
    });

    test('ResponseFormat equality', () {
      final text1 = ResponseFormat.text();
      final text2 = ResponseFormat.text();
      final json1 = ResponseFormat.json();
      final json2 = ResponseFormat.json();

      expect(text1, equals(text2));
      expect(json1, equals(json2));
      expect(text1, isNot(equals(json1)));
    });
  });

  group('DefaultModels', () {
    test('has OpenAI default model', () {
      expect(DefaultModels.openai, 'gpt-4-turbo');
    });

    test('has Anthropic default model', () {
      expect(DefaultModels.anthropic, 'claude-3-5-sonnet-latest');
    });

    test('has Google AI default model', () {
      expect(DefaultModels.googleAI, 'gemini-1.5-pro');
    });

    test('forProvider returns correct default for OpenAI', () {
      expect(DefaultModels.forProvider(AIProvider.openai), 'gpt-4-turbo');
    });

    test('forProvider returns correct default for Anthropic', () {
      expect(
        DefaultModels.forProvider(AIProvider.anthropic),
        'claude-3-5-sonnet-latest',
      );
    });

    test('forProvider returns correct default for Google AI', () {
      expect(DefaultModels.forProvider(AIProvider.googleAI), 'gemini-1.5-pro');
    });
  });

  group('APIEndpoints', () {
    test('has correct OpenAI endpoint', () {
      expect(APIEndpoints.openai, 'https://api.openai.com/v1');
    });

    test('has correct Anthropic endpoint', () {
      expect(APIEndpoints.anthropic, 'https://api.anthropic.com/v1');
    });

    test('has correct Google AI endpoint', () {
      expect(
        APIEndpoints.googleAI,
        'https://generativelanguage.googleapis.com/v1beta',
      );
    });

    test('forProvider returns correct endpoint for OpenAI', () {
      expect(
        APIEndpoints.forProvider(AIProvider.openai),
        'https://api.openai.com/v1',
      );
    });

    test('forProvider returns correct endpoint for Anthropic', () {
      expect(
        APIEndpoints.forProvider(AIProvider.anthropic),
        'https://api.anthropic.com/v1',
      );
    });

    test('forProvider returns correct endpoint for Google AI', () {
      expect(
        APIEndpoints.forProvider(AIProvider.googleAI),
        'https://generativelanguage.googleapis.com/v1beta',
      );
    });
  });
}
