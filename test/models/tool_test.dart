import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('Tool', () {
    test('creates with required parameters', () {
      final tool = Tool(
        name: 'get_weather',
        description: 'Gets the current weather for a location',
        parameters: ToolParameters(
          properties: {
            'location': ToolProperty.string(description: 'The city name'),
          },
          required: ['location'],
        ),
      );

      expect(tool.name, 'get_weather');
      expect(tool.description, 'Gets the current weather for a location');
      expect(tool.parameters.properties, hasLength(1));
      expect(tool.parameters.required, contains('location'));
    });

    test('creates with all property types', () {
      final tool = Tool(
        name: 'complex_tool',
        description: 'A tool with various property types',
        parameters: ToolParameters(
          properties: {
            'text_field': ToolProperty.string(description: 'A text field'),
            'number_field': ToolProperty.number(description: 'A number'),
            'integer_field': ToolProperty.integer(description: 'An integer'),
            'bool_field': ToolProperty.boolean(description: 'A boolean'),
            'enum_field': ToolProperty.enumeration(
              description: 'An enum',
              values: ['option1', 'option2'],
            ),
            'array_field': ToolProperty.array(
              description: 'An array',
              items: ToolProperty.string(description: 'Item'),
            ),
            'object_field': ToolProperty.object(
              description: 'An object',
              properties: {
                'nested': ToolProperty.string(description: 'Nested field'),
              },
            ),
          },
        ),
      );

      expect(tool.parameters.properties, hasLength(7));
    });

    test('toJson generates correct format', () {
      final tool = Tool(
        name: 'calculator',
        description: 'Performs calculations',
        parameters: ToolParameters(
          properties: {
            'expression': ToolProperty.string(
              description: 'Math expression',
            ),
            'precision': ToolProperty.integer(
              description: 'Decimal places',
            ),
          },
          required: ['expression'],
        ),
      );

      final json = tool.toJson();

      expect(json['name'], 'calculator');
      expect(json['description'], 'Performs calculations');
      expect(json['parameters'], isNotNull);
      expect(json['parameters']['type'], 'object');
      expect(json['parameters']['properties'], hasLength(2));
      expect(json['parameters']['required'], ['expression']);
    });

    test('toOpenAIFormat generates correct structure', () {
      final tool = Tool(
        name: 'search',
        description: 'Search the web',
        parameters: ToolParameters(
          properties: {
            'query': ToolProperty.string(description: 'Search query'),
          },
          required: ['query'],
        ),
      );

      final format = tool.toOpenAIFormat();

      expect(format['type'], 'function');
      expect(format['function']['name'], 'search');
      expect(format['function']['description'], 'Search the web');
    });

    test('toAnthropicFormat generates correct structure', () {
      final tool = Tool(
        name: 'search',
        description: 'Search the web',
        parameters: ToolParameters(
          properties: {
            'query': ToolProperty.string(description: 'Search query'),
          },
          required: ['query'],
        ),
      );

      final format = tool.toAnthropicFormat();

      expect(format['name'], 'search');
      expect(format['description'], 'Search the web');
      expect(format['input_schema'], isNotNull);
    });

    test('equality', () {
      final tool1 = Tool(
        name: 'same',
        description: 'Same tool',
        parameters: const ToolParameters(properties: {}),
      );
      final tool2 = Tool(
        name: 'same',
        description: 'Same tool',
        parameters: const ToolParameters(properties: {}),
      );
      final tool3 = Tool(
        name: 'different',
        description: 'Different tool',
        parameters: const ToolParameters(properties: {}),
      );

      expect(tool1, equals(tool2));
      expect(tool1, isNot(equals(tool3)));
    });
  });

  group('ToolCallContent', () {
    test('creates with all fields', () {
      const call = ToolCallContent(
        id: 'call_abc123',
        name: 'get_weather',
        arguments: {'location': 'Paris'},
      );

      expect(call.id, 'call_abc123');
      expect(call.name, 'get_weather');
      expect(call.arguments['location'], 'Paris');
    });

    test('toJson generates correct format', () {
      const call = ToolCallContent(
        id: 'call_123',
        name: 'calculator',
        arguments: {'expression': '2+2'},
      );

      final json = call.toJson();

      expect(json['id'], 'call_123');
      expect(json['name'], 'calculator');
      expect(json['arguments'], {'expression': '2+2'});
    });
  });

  group('ToolProperty', () {
    group('string', () {
      test('creates string property', () {
        final prop = ToolProperty.string(description: 'A string');

        expect(prop.type, 'string');
        expect(prop.description, 'A string');
      });

      test('toJson generates correct format', () {
        final prop = ToolProperty.string(description: 'Text input');
        final json = prop.toJson();

        expect(json['type'], 'string');
        expect(json['description'], 'Text input');
      });
    });

    group('number', () {
      test('creates number property', () {
        final prop = ToolProperty.number(description: 'A number');

        expect(prop.type, 'number');
        expect(prop.description, 'A number');
      });
    });

    group('integer', () {
      test('creates integer property', () {
        final prop = ToolProperty.integer(description: 'An integer');

        expect(prop.type, 'integer');
        expect(prop.description, 'An integer');
      });
    });

    group('boolean', () {
      test('creates boolean property', () {
        final prop = ToolProperty.boolean(description: 'A boolean');

        expect(prop.type, 'boolean');
        expect(prop.description, 'A boolean');
      });
    });

    group('enumeration', () {
      test('creates enum property', () {
        final prop = ToolProperty.enumeration(
          description: 'Choose one',
          values: ['a', 'b', 'c'],
        );

        expect(prop.type, 'string');
      });

      test('toJson includes enum values', () {
        final prop = ToolProperty.enumeration(
          description: 'Options',
          values: ['x', 'y'],
        );
        final json = prop.toJson();

        expect(json['enum'], ['x', 'y']);
      });
    });

    group('array', () {
      test('creates array property', () {
        final prop = ToolProperty.array(
          description: 'A list',
          items: ToolProperty.string(description: 'Item'),
        );

        expect(prop.type, 'array');
      });

      test('toJson includes items schema', () {
        final prop = ToolProperty.array(
          description: 'Numbers list',
          items: ToolProperty.number(description: 'Number'),
        );
        final json = prop.toJson();

        expect(json['items'], isNotNull);
        expect(json['items']['type'], 'number');
      });
    });

    group('object', () {
      test('creates object property', () {
        final prop = ToolProperty.object(
          description: 'An object',
          properties: {
            'name': ToolProperty.string(description: 'Name'),
            'age': ToolProperty.integer(description: 'Age'),
          },
        );

        expect(prop.type, 'object');
      });

      test('toJson includes properties schema', () {
        final prop = ToolProperty.object(
          description: 'Person',
          properties: {
            'name': ToolProperty.string(description: 'Name'),
          },
          required: ['name'],
        );
        final json = prop.toJson();

        expect(json['properties'], isNotNull);
        expect(json['properties']['name']['type'], 'string');
        expect(json['required'], ['name']);
      });
    });
  });

  group('ToolChoice', () {
    test('auto() creates auto choice', () {
      final choice = ToolChoice.auto();
      expect(choice, isA<AutoToolChoice>());
    });

    test('none() creates none choice', () {
      final choice = ToolChoice.none();
      expect(choice, isA<NoneToolChoice>());
    });

    test('required() creates required choice', () {
      final choice = ToolChoice.required();
      expect(choice, isA<RequiredToolChoice>());
    });

    test('tool() creates specific tool choice', () {
      final choice = ToolChoice.tool('get_weather');
      expect(choice, isA<SpecificToolChoice>());
      expect((choice as SpecificToolChoice).name, 'get_weather');
    });
  });
}
