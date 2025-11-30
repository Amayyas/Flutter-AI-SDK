// ignore_for_file: avoid_print, unused_local_variable

import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';

/// Example demonstrating the basic usage of Flutter AI SDK.
///
/// This example shows how to:
/// - Initialize the SDK with different providers
/// - Send simple chat messages
/// - Stream responses
/// - Use multimodal content
/// - Handle errors
void main() async {
  // Example 1: Basic OpenAI usage
  await basicOpenAIExample();

  // Example 2: Anthropic with streaming
  await anthropicStreamingExample();

  // Example 3: Google AI with vision
  await googleAIVisionExample();

  // Example 4: Function calling
  await functionCallingExample();

  // Example 5: Error handling
  await errorHandlingExample();

  // Example 6: Context management
  await contextManagementExample();
}

/// Example 1: Basic OpenAI usage
Future<void> basicOpenAIExample() async {
  print('\n=== Basic OpenAI Example ===\n');

  final ai = FlutterAI(
    provider: AIProvider.openai,
    config: AIConfig(
      apiKey: 'your-openai-api-key',
      model: 'gpt-4-turbo',
      temperature: 0.7,
      maxTokens: 1000,
    ),
  );

  try {
    // Simple chat
    final response = await ai.chat('What is Flutter?');
    print('Response: ${response.text}');
    print('Tokens used: ${response.usage?.totalTokens}');

    // Follow-up question (context is maintained)
    final followUp = await ai.chat('Can you give me a code example?');
    print('Follow-up: ${followUp.text}');
  } finally {
    ai.dispose();
  }
}

/// Example 2: Anthropic with streaming
Future<void> anthropicStreamingExample() async {
  print('\n=== Anthropic Streaming Example ===\n');

  final ai = FlutterAI(
    provider: AIProvider.anthropic,
    config: AIConfig(
      apiKey: 'your-anthropic-api-key',
      model: 'claude-3-5-sonnet-latest',
      systemPrompt: 'You are a creative storyteller.',
    ),
  );

  try {
    print('Streaming story...\n');

    await for (final chunk in ai
        .streamChat('Tell me a short story about a robot learning to paint')) {
      if (chunk.isDelta && chunk.delta != null) {
        // Print each chunk as it arrives
        print(chunk.delta);
      }
      if (chunk.isDone) {
        print('\n\nFinished! Tokens: ${chunk.usage?.totalTokens}');
      }
    }
  } finally {
    ai.dispose();
  }
}

/// Example 3: Google AI with vision
Future<void> googleAIVisionExample() async {
  print('\n=== Google AI Vision Example ===\n');

  final ai = FlutterAI(
    provider: AIProvider.googleAI,
    config: AIConfig(
      apiKey: 'your-google-ai-api-key',
      model: 'gemini-1.5-pro',
    ),
  );

  try {
    // Analyze an image from URL
    final response = await ai.chatWithContent([
      const TextContent(
          'What can you see in this image? Describe it in detail.'),
      const ImageContent.fromUrl(
        'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Camponotus_flavomarginatus_ant.jpg/1200px-Camponotus_flavomarginatus_ant.jpg',
        detail: ImageDetail.high,
      ),
    ]);

    print('Image analysis: ${response.text}');
  } finally {
    ai.dispose();
  }
}

/// Example 4: Function calling
Future<void> functionCallingExample() async {
  print('\n=== Function Calling Example ===\n');

  final ai = FlutterAI(
    provider: AIProvider.openai,
    config: AIConfig(
      apiKey: 'your-openai-api-key',
      model: 'gpt-4-turbo',
    ),
  );

  // Define tools
  final weatherTool = Tool(
    name: 'get_weather',
    description: 'Get the current weather for a location',
    parameters: ToolParameters(
      properties: {
        'location': ToolProperty.string(
          description: 'The city and country, e.g., "Paris, France"',
        ),
        'unit': ToolProperty.enumeration(
          description: 'Temperature unit',
          values: ['celsius', 'fahrenheit'],
        ),
      },
      required: ['location'],
    ),
  );

  final calculatorTool = Tool(
    name: 'calculate',
    description: 'Perform mathematical calculations',
    parameters: ToolParameters(
      properties: {
        'expression': ToolProperty.string(
          description: 'The mathematical expression to evaluate',
        ),
      },
      required: ['expression'],
    ),
  );

  try {
    // Ask a question that requires tools
    final response = await ai.chatWithTools(
      'What is the weather in Paris and what is 25 * 4?',
      tools: [weatherTool, calculatorTool],
    );

    if (response.hasToolCalls) {
      print('AI wants to call tools:');

      for (final call in response.toolCalls!) {
        print('  Tool: ${call.name}');
        print('  Arguments: ${call.arguments}');

        // Simulate tool execution
        dynamic result;
        if (call.name == 'get_weather') {
          result = {
            'temperature': 22,
            'condition': 'sunny',
            'humidity': 45,
          };
        } else if (call.name == 'calculate') {
          result = {'result': 100};
        }

        // Submit result back to AI
        final finalResponse = await ai.submitToolResult(
          toolCallId: call.id,
          name: call.name,
          result: result,
        );

        print('\nFinal response: ${finalResponse.text}');
      }
    }
  } finally {
    ai.dispose();
  }
}

/// Example 5: Error handling
Future<void> errorHandlingExample() async {
  print('\n=== Error Handling Example ===\n');

  final ai = FlutterAI(
    provider: AIProvider.openai,
    config: AIConfig(
      apiKey: 'invalid-key', // This will cause an auth error
      model: 'gpt-4-turbo',
    ),
  );

  try {
    final response = await ai.chat('Hello');
    print(response.text);
  } on AIAuthenticationError catch (e) {
    print('Authentication failed: ${e.message}');
    print('Please check your API key.');
  } on AIRateLimitError catch (e) {
    print('Rate limited: ${e.message}');
    if (e.retryAfter != null) {
      print('Retry after: ${e.retryAfter!.inSeconds} seconds');
    }
  } on AIContextLengthError catch (e) {
    print('Context too long: ${e.message}');
    print('Max tokens: ${e.maxTokens}');
  } on AIContentFilterError catch (e) {
    print('Content filtered: ${e.message}');
    print('Categories: ${e.categories}');
  } on AINetworkError catch (e) {
    print('Network error: ${e.message}');
    print('Is timeout: ${e.isTimeout}');
  } on AIError catch (e) {
    print('General AI error: ${e.message}');
    print('Error code: ${e.code}');
  } catch (e) {
    print('Unexpected error: $e');
  } finally {
    ai.dispose();
  }
}

/// Example 6: Context management
Future<void> contextManagementExample() async {
  print('\n=== Context Management Example ===\n');

  // Create a custom context manager
  final contextManager = ContextManager(
    maxTokens: 4000,
    reservedTokens: 500,
    systemPrompt:
        'You are a helpful assistant that remembers our conversation.',
    windowStrategy: WindowStrategy.slidingWindow,
  );

  // Listen to context updates
  contextManager.updates.listen((update) {
    print('Context update: ${update.type}');
    print('  Messages: ${update.messageCount}');
    print('  Tokens: ${update.estimatedTokens}');
  });

  final ai = FlutterAI(
    provider: AIProvider.openai,
    config: AIConfig(
      apiKey: 'your-openai-api-key',
      model: 'gpt-3.5-turbo',
    ),
    contextManager: contextManager,
  );

  try {
    // Multi-turn conversation
    await ai.chat('My name is Alice.');
    await ai.chat('I live in New York.');
    await ai.chat('I work as a software engineer.');

    // The AI should remember all the context
    final response = await ai.chat('What do you know about me?');
    print('AI response: ${response.text}');

    // Check context state
    print('\nContext state:');
    print('  Messages: ${ai.context.conversation.length}');
    print('  Estimated tokens: ${ai.context.estimatedTokens}');
    print('  Available tokens: ${ai.context.availableTokens}');

    // Export conversation
    final json = ai.conversation.toJson();
    print('\nConversation exported to JSON');

    // Clear context for new conversation
    ai.clearContext();
    print('\nContext cleared');
  } finally {
    ai.dispose();
    contextManager.dispose();
  }
}
