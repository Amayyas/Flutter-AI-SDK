import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('Message', () {
    group('factory constructors', () {
      test('user() creates a user message with text', () {
        final message = Message.user('Hello');

        expect(message.role, MessageRole.user);
        expect(message.text, 'Hello');
        expect(message.id, isNotEmpty);
        expect(message.createdAt, isNotNull);
      });

      test('user() creates a user message with name', () {
        final message = Message.user('Hello', name: 'John');

        expect(message.name, 'John');
      });

      test('assistant() creates an assistant message', () {
        final message = Message.assistant('Hi there!');

        expect(message.role, MessageRole.assistant);
        expect(message.text, 'Hi there!');
      });

      test('system() creates a system message', () {
        final message = Message.system('You are a helpful assistant.');

        expect(message.role, MessageRole.system);
        expect(message.text, 'You are a helpful assistant.');
      });

      test('toolResult() creates a tool result message', () {
        final message = Message.toolResult(
          toolCallId: 'call_123',
          name: 'get_weather',
          result: '{"temperature": 22}',
        );

        expect(message.role, MessageRole.tool);
        expect(message.content.first, isA<ToolResultContent>());
        final toolResult = message.content.first as ToolResultContent;
        expect(toolResult.toolCallId, 'call_123');
        expect(toolResult.name, 'get_weather');
      });

      test('user() with multimodal content', () {
        final content = [
          const TextContent('Describe this image'),
          const ImageContent.fromUrl('https://example.com/image.jpg'),
        ];

        final message = Message.user(content);

        expect(message.role, MessageRole.user);
        expect(message.content, hasLength(2));
        expect(message.content[0], isA<TextContent>());
        expect(message.content[1], isA<ImageContent>());
      });
    });

    group('properties', () {
      test('text returns combined text content', () {
        final message = Message.user('Hello');
        expect(message.text, 'Hello');
      });

      test('text joins multiple text contents with newline', () {
        final message = Message.user([
          const TextContent('Hello'),
          const TextContent('World'),
        ]);
        expect(message.text, 'Hello\nWorld');
      });

      test('isTextOnly returns true for text-only messages', () {
        final message = Message.user('Hello');
        expect(message.isTextOnly, isTrue);
      });

      test('isTextOnly returns false for multimodal messages', () {
        final message = Message.user([
          const TextContent('Hello'),
          const ImageContent.fromUrl('https://example.com/img.jpg'),
        ]);
        expect(message.isTextOnly, isFalse);
      });

      test('hasImages returns true when content contains images', () {
        final message = Message.user([
          const TextContent('Describe this'),
          const ImageContent.fromUrl('https://example.com/img.jpg'),
        ]);
        expect(message.hasImages, isTrue);
      });

      test('hasImages returns false for text-only messages', () {
        final message = Message.user('Hello');
        expect(message.hasImages, isFalse);
      });

      test('hasToolCalls returns true when toolCalls is not empty', () {
        final call = ToolCallContent(
          id: '1',
          name: 'test',
          arguments: {},
        );
        final message = Message.assistant('', toolCalls: [call]);

        expect(message.hasToolCalls, isTrue);
      });

      test('hasToolCalls returns false when no tool calls', () {
        final message = Message.assistant('Hello');
        expect(message.hasToolCalls, isFalse);
      });
    });

    group('copyWith', () {
      test('creates a copy with updated content', () {
        final original = Message.user('Hello');
        final copy = original.copyWith(content: [const TextContent('Updated')]);

        expect(copy.text, 'Updated');
        expect(copy.role, original.role);
        expect(copy.id, original.id);
      });

      test('preserves original values when not specified', () {
        final original = Message.user('Hi', name: 'Bot');
        final copy = original.copyWith(
          content: [const TextContent('Updated')],
        );

        expect(copy.name, 'Bot');
        expect(copy.role, MessageRole.user);
      });

      test('can update role', () {
        final original = Message.user('Hello');
        final copy = original.copyWith(role: MessageRole.assistant);

        expect(copy.role, MessageRole.assistant);
      });

      test('can update metadata', () {
        final original = Message.user('Hello');
        final copy = original.copyWith(metadata: {'key': 'value'});

        expect(copy.metadata, {'key': 'value'});
      });
    });

    group('serialization', () {
      test('toJson creates correct structure', () {
        final message = Message.user('Hello');
        final json = message.toJson();

        expect(json['role'], 'user');
        expect(json['content'], isA<List<dynamic>>());
        expect(json['id'], isNotNull);
        expect(json['created_at'], isNotNull);
      });

      test('toJson and fromJson roundtrip', () {
        final original = Message.user('Hello');
        final json = original.toJson();
        final restored = Message.fromJson(json);

        expect(restored.role, original.role);
        expect(restored.text, original.text);
        expect(restored.id, original.id);
      });

      test('handles multimodal content serialization', () {
        final original = Message.user([
          const TextContent('Describe this'),
          const ImageContent.fromUrl('https://example.com/img.jpg'),
        ]);

        final json = original.toJson();
        final restored = Message.fromJson(json);

        expect(restored.content, hasLength(2));
        expect(restored.content[0], isA<TextContent>());
        expect(restored.content[1], isA<ImageContent>());
      });

      test('handles tool calls serialization', () {
        final original = Message.assistant(
          'Let me check that.',
          toolCalls: [
            ToolCallContent(
              id: '1',
              name: 'weather',
              arguments: {'city': 'Paris'},
            ),
          ],
        );

        final json = original.toJson();

        expect(json['tool_calls'], isNotNull);
        expect(json['tool_calls'], hasLength(1));
      });
    });

    group('equality', () {
      test('equal messages have same hashCode', () {
        final m1 = Message(
          id: 'test-id',
          role: MessageRole.user,
          content: [const TextContent('Hello')],
          createdAt: DateTime(2024, 1, 1),
        );
        final m2 = Message(
          id: 'test-id',
          role: MessageRole.user,
          content: [const TextContent('Hello')],
          createdAt: DateTime(2024, 1, 1),
        );

        expect(m1, equals(m2));
        expect(m1.hashCode, equals(m2.hashCode));
      });

      test('different content means different messages', () {
        final m1 = Message.user('Hello');
        final m2 = Message.user('World');

        expect(m1, isNot(equals(m2)));
      });

      test('different ids means different messages', () {
        final m1 = Message(
          id: 'id-1',
          role: MessageRole.user,
          content: [const TextContent('Hello')],
        );
        final m2 = Message(
          id: 'id-2',
          role: MessageRole.user,
          content: [const TextContent('Hello')],
        );

        expect(m1, isNot(equals(m2)));
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        final message = Message.user('Hello');
        expect(message.toString(), contains('Message'));
        expect(message.toString(), contains('user'));
        expect(message.toString(), contains('Hello'));
      });

      test('truncates long content', () {
        final longText = 'A' * 100;
        final message = Message.user(longText);
        expect(message.toString(), contains('...'));
        expect(message.toString().length, lessThan(longText.length + 50));
      });
    });
  });
}
