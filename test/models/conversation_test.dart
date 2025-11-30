import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('Conversation', () {
    test('creates empty conversation', () {
      final conversation = Conversation();

      expect(conversation.id, isNotEmpty);
      expect(conversation.messages, isEmpty);
      expect(conversation.isEmpty, isTrue);
      expect(conversation.length, 0);
    });

    test('creates with initial messages', () {
      final messages = [
        Message.user('Hello'),
        Message.assistant('Hi there!'),
      ];

      final conversation = Conversation(messages: messages);

      expect(conversation.messages, hasLength(2));
      expect(conversation.isEmpty, isFalse);
      expect(conversation.length, 2);
    });

    test('adds messages', () {
      final conversation = Conversation();

      conversation.addMessage(Message.user('Hello'));
      conversation.addMessage(Message.assistant('Hi!'));

      expect(conversation.length, 2);
      expect(conversation.messages.first.text, 'Hello');
      expect(conversation.messages.last.text, 'Hi!');
    });

    test('addUserMessage adds user message', () {
      final conversation = Conversation();

      conversation.addUserMessage('Hello');

      expect(conversation.length, 1);
      expect(conversation.messages.first.role, MessageRole.user);
    });

    test('addAssistantMessage adds assistant message', () {
      final conversation = Conversation();

      conversation.addAssistantMessage('Hi!');

      expect(conversation.length, 1);
      expect(conversation.messages.first.role, MessageRole.assistant);
    });

    test('lastMessage returns last message', () {
      final conversation = Conversation();

      expect(conversation.lastMessage, isNull);

      conversation.addUserMessage('Hello');
      conversation.addAssistantMessage('Hi!');

      expect(conversation.lastMessage?.text, 'Hi!');
    });

    test('clear removes all messages', () {
      final conversation = Conversation(messages: [
        Message.user('Hello'),
        Message.assistant('Hi!'),
      ]);

      conversation.clear();

      expect(conversation.isEmpty, isTrue);
      expect(conversation.length, 0);
    });

    test('removeMessage removes by ID', () {
      final msg1 = Message.user('Keep');
      final msg2 = Message.assistant('Remove');

      final conversation = Conversation(messages: [msg1, msg2]);

      final removed = conversation.removeMessage(msg2.id);

      expect(removed, isTrue);
      expect(conversation.length, 1);
      expect(conversation.messages.first.text, 'Keep');
    });

    test('truncate keeps only last n messages', () {
      final conversation = Conversation(messages: [
        Message.user('1'),
        Message.assistant('2'),
        Message.user('3'),
        Message.assistant('4'),
        Message.user('5'),
      ]);

      conversation.truncate(3);

      expect(conversation.length, 3);
      expect(conversation.messages.first.text, '3');
      expect(conversation.messages.last.text, '5');
    });

    test('truncate does nothing if fewer messages', () {
      final conversation = Conversation(messages: [
        Message.user('1'),
        Message.assistant('2'),
      ]);

      conversation.truncate(10);

      expect(conversation.length, 2);
    });

    test('getLastMessages returns last n messages', () {
      final conversation = Conversation(messages: [
        Message.user('1'),
        Message.assistant('2'),
        Message.user('3'),
        Message.assistant('4'),
      ]);

      final last2 = conversation.getLastMessages(2);

      expect(last2, hasLength(2));
      expect(last2.first.text, '3');
      expect(last2.last.text, '4');
    });

    test('copyWith creates a copy', () {
      final original = Conversation(
        title: 'Test Conversation',
        messages: [Message.user('Hello')],
      );

      final copy = original.copyWith(title: 'New Title');

      expect(copy.id, original.id);
      expect(copy.title, 'New Title');
      expect(copy.messages, hasLength(1));
    });

    test('toJson and fromJson roundtrip', () {
      final original = Conversation(
        title: 'Test Conversation',
        messages: [
          Message.user('Hello'),
          Message.assistant('Hi there!'),
        ],
        metadata: {'key': 'value'},
      );

      final json = original.toJson();
      final restored = Conversation.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.messages, hasLength(2));
      expect(restored.metadata?['key'], 'value');
    });

    test('equality based on id', () {
      final c1 = Conversation();
      final c2 = Conversation();

      // Different IDs
      expect(c1, isNot(equals(c2)));

      // Same instance
      expect(c1, equals(c1));
    });

    group('metadata', () {
      test('stores and retrieves metadata', () {
        final conversation = Conversation(
          metadata: {
            'category': 'support',
            'priority': 'high',
          },
        );

        expect(conversation.metadata?['category'], 'support');
        expect(conversation.metadata?['priority'], 'high');
      });

      test('preserves metadata through serialization', () {
        final original = Conversation(
          metadata: {'complex': 'data'},
        );

        final json = original.toJson();
        final restored = Conversation.fromJson(json);

        expect(restored.metadata?['complex'], 'data');
      });
    });

    group('timestamps', () {
      test('createdAt is set on creation', () {
        final conversation = Conversation();

        expect(conversation.createdAt, isNotNull);
        expect(
          conversation.createdAt.difference(DateTime.now()).inSeconds.abs(),
          lessThan(2),
        );
      });

      test('updatedAt is updated when messages are added', () async {
        final conversation = Conversation();
        final initialUpdatedAt = conversation.updatedAt;

        // Small delay to ensure different timestamps
        await Future<void>.delayed(const Duration(milliseconds: 10));

        conversation.addUserMessage('Hello');

        expect(conversation.updatedAt.isAfter(initialUpdatedAt), isTrue);
      });
    });
  });
}
