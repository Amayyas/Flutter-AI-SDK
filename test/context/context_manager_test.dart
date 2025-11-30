import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('ContextManager', () {
    late ContextManager contextManager;

    setUp(() {
      contextManager = ContextManager(
        maxTokens: 4000,
        reservedTokens: 500,
        systemPrompt: 'You are a helpful assistant.',
      );
    });

    tearDown(() {
      contextManager.dispose();
    });

    test('creates with default parameters', () {
      final cm = ContextManager();

      expect(cm.maxTokens, 8000);
      expect(cm.reservedTokens, 1000);
      expect(cm.systemPrompt, isNull);

      cm.dispose();
    });

    test('creates with custom parameters', () {
      expect(contextManager.maxTokens, 4000);
      expect(contextManager.reservedTokens, 500);
      expect(contextManager.systemPrompt, 'You are a helpful assistant.');
    });

    test('addMessage adds to conversation', () {
      contextManager.addMessage(Message.user('Hello'));

      expect(contextManager.conversation.length, 1);
      expect(contextManager.conversation.messages.first.text, 'Hello');
    });

    test('addUserMessage and addAssistantMessage work', () {
      contextManager.addUserMessage('Hello');
      contextManager.addAssistantMessage('Hi there!');

      expect(contextManager.conversation.length, 2);
    });

    test('estimatedTokens calculates token estimate', () {
      contextManager.addMessage(Message.user('Hello world'));

      final tokens = contextManager.estimatedTokens;

      // Basic estimation: ~4 characters per token
      expect(tokens, greaterThan(0));
    });

    test('availableTokens returns remaining tokens', () {
      final initial = contextManager.availableTokens;

      contextManager.addMessage(Message.user('Hello world'));

      expect(contextManager.availableTokens, lessThan(initial));
    });

    test('clear clears conversation', () {
      contextManager.addUserMessage('Hello');
      contextManager.addAssistantMessage('Hi!');

      contextManager.clear();

      expect(contextManager.conversation.isEmpty, isTrue);
    });

    test('messages includes system prompt', () {
      contextManager.addMessage(Message.user('Hello'));

      final messages = contextManager.messages;

      expect(messages.first.role, MessageRole.system);
      expect(messages.first.text, 'You are a helpful assistant.');
      expect(messages.length, 2);
    });

    test('messages works without system prompt', () {
      final cm = ContextManager();
      cm.addMessage(Message.user('Hello'));

      final messages = cm.messages;

      expect(messages.length, 1);
      expect(messages.first.role, MessageRole.user);

      cm.dispose();
    });

    group('truncation strategies', () {
      test('slidingWindow keeps recent messages', () {
        final cm = ContextManager(
          maxTokens: 100, // Low limit to force truncation
          reservedTokens: 0,
          windowStrategy: WindowStrategy.slidingWindow,
        );

        // Add many messages
        for (var i = 0; i < 10; i++) {
          cm.addMessage(Message.user('Message $i with some extra content'));
        }

        final messages = cm.messages;

        // Should have fewer messages due to truncation
        expect(messages.length, lessThan(10));

        cm.dispose();
      });

      test('summarize strategy is available', () {
        final cm = ContextManager(
          windowStrategy: WindowStrategy.summarize,
        );

        expect(cm.windowStrategy, WindowStrategy.summarize);

        cm.dispose();
      });

      test('truncateOldest strategy is available', () {
        final cm = ContextManager(
          windowStrategy: WindowStrategy.truncateOldest,
        );

        expect(cm.windowStrategy, WindowStrategy.truncateOldest);

        cm.dispose();
      });
    });

    group('stream updates', () {
      test('emits updates when messages are added', () async {
        final updates = <ContextUpdate>[];

        contextManager.updates.listen(updates.add);

        contextManager.addMessage(Message.user('Hello'));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(updates, isNotEmpty);
        expect(updates.last.type, ContextUpdateType.messageAdded);
      });

      test('emits updates when context is cleared', () async {
        final updates = <ContextUpdate>[];

        contextManager.updates.listen(updates.add);

        contextManager.addMessage(Message.user('Hello'));
        contextManager.clear();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(updates.any((u) => u.type == ContextUpdateType.cleared), isTrue);
      });
    });

    group('conversation management', () {
      test('conversation getter returns the conversation', () {
        contextManager.addUserMessage('Hello');
        contextManager.addAssistantMessage('Hi!');

        expect(contextManager.conversation.length, 2);
      });

      test('toJson returns JSON-serializable data', () {
        contextManager.addUserMessage('Hello');
        contextManager.addAssistantMessage('Hi!');

        final json = contextManager.conversation.toJson();

        expect(json.containsKey('id'), isTrue);
        expect(json.containsKey('messages'), isTrue);
        expect((json['messages'] as List).length, 2);
      });
    });
  });
}
