# Flutter AI SDK

A unified Flutter/Dart wrapper for integrating various AI APIs (OpenAI, Anthropic, Google AI) with streaming, context management, and multimodal support.

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/Amayyas/Flutter-AI-SDK)

## Features

- 🔄 **Unified API** - Single interface for multiple AI providers
- 🌊 **Streaming Support** - Real-time response streaming
- 💬 **Context Management** - Automatic conversation history and memory
- 🖼️ **Multimodal Support** - Text, images, audio, and documents
- 🛠️ **Function Calling** - Tool/function support for all providers
- 🔒 **Type Safety** - Full Dart type safety with null safety
- ⚡ **Error Handling** - Comprehensive error types and retry logic
- 📊 **Token Counting** - Estimate token usage before requests

## Supported Providers

| Provider | Text | Vision | Audio | Tools | Streaming |
|----------|------|--------|-------|-------|-----------|
| OpenAI | ✅ | ✅ | ✅ | ✅ | ✅ |
| Anthropic | ✅ | ✅ | ❌ | ✅ | ✅ |
| Google AI | ✅ | ✅ | ✅ | ✅ | ✅ |

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_ai_sdk: ^1.0.0
```

Or run:

```bash
flutter pub add flutter_ai_sdk
```

## Quick Start

### Basic Chat

```dart
import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';

// Initialize the SDK
final ai = FlutterAI(
  provider: AIProvider.openai,
  config: AIConfig(
    apiKey: 'your-api-key',
    model: 'gpt-4-turbo',
  ),
);

// Simple chat
final response = await ai.chat('Hello, how are you?');
print(response.text);

// Don't forget to dispose when done
ai.dispose();
```

### Streaming Responses

```dart
final ai = FlutterAI(
  provider: AIProvider.anthropic,
  config: AIConfig(
    apiKey: 'your-api-key',
    model: 'claude-3-5-sonnet-latest',
  ),
);

// Stream responses
await for (final chunk in ai.streamChat('Tell me a story')) {
  if (chunk.isDelta) {
    print(chunk.delta); // Print each chunk as it arrives
  }
}
```

### Multi-turn Conversations

```dart
final ai = FlutterAI(
  provider: AIProvider.openai,
  config: AIConfig(
    apiKey: 'your-api-key',
    systemPrompt: 'You are a helpful coding assistant.',
  ),
);

// Context is automatically maintained
await ai.chat('What is Dart?');
await ai.chat('Can you show me an example?');
await ai.chat('How does it compare to JavaScript?');

// Access conversation history
print(ai.history.length);
```

### Vision / Image Analysis

```dart
final ai = FlutterAI(
  provider: AIProvider.openai,
  config: AIConfig(
    apiKey: 'your-api-key',
    model: 'gpt-4-turbo',
  ),
);

// Analyze an image from URL
final response = await ai.chatWithContent([
  TextContent('What is in this image?'),
  ImageContent.fromUrl('https://example.com/image.png'),
]);

// Or from local bytes
final imageBytes = await File('image.png').readAsBytes();
final response = await ai.chatWithContent([
  TextContent('Describe this image'),
  ImageContent.fromBytes(imageBytes, mimeType: 'image/png'),
]);
```

### Function Calling / Tools

```dart
// Define a tool
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

// Use the tool
final response = await ai.chatWithTools(
  'What is the weather in Paris?',
  tools: [weatherTool],
);

// Handle tool calls
if (response.hasToolCalls) {
  for (final call in response.toolCalls!) {
    // Execute the tool
    final result = await executeWeatherCall(call.arguments);
    
    // Submit result back to the AI
    final finalResponse = await ai.submitToolResult(
      toolCallId: call.id,
      name: call.name,
      result: result,
    );
    print(finalResponse.text);
  }
}
```

### Error Handling

```dart
try {
  final response = await ai.chat('Hello');
} on AIAuthenticationError catch (e) {
  print('Invalid API key: ${e.message}');
} on AIRateLimitError catch (e) {
  print('Rate limited. Retry after: ${e.retryAfter}');
  await Future.delayed(e.retryAfter ?? Duration(seconds: 60));
  // Retry the request
} on AIContextLengthError catch (e) {
  print('Context too long: ${e.message}');
  ai.clearContext(); // Clear and retry
} on AIError catch (e) {
  print('AI error: ${e.message}');
}
```

## Configuration Options

```dart
final config = AIConfig(
  // Required
  apiKey: 'your-api-key',
  
  // Model selection
  model: 'gpt-4-turbo', // Provider-specific model name
  
  // Generation parameters
  maxTokens: 4096,
  temperature: 0.7,      // 0.0 - 2.0, higher = more random
  topP: 0.9,             // Alternative to temperature
  frequencyPenalty: 0.0, // -2.0 to 2.0
  presencePenalty: 0.0,  // -2.0 to 2.0
  stopSequences: ['END'], // Stop generation at these sequences
  
  // System behavior
  systemPrompt: 'You are a helpful assistant.',
  
  // Response format
  responseFormat: ResponseFormat.json(), // Force JSON output
  
  // Tools/Functions
  tools: [myTool],
  toolChoice: ToolChoice.auto(),
  
  // Network settings
  baseUrl: 'https://custom-endpoint.com', // Custom API endpoint
  timeout: Duration(seconds: 30),
  headers: {'X-Custom-Header': 'value'},
);
```

## Context Management

The SDK includes built-in context management to handle conversation history:

```dart
final ai = FlutterAI(
  provider: AIProvider.openai,
  config: AIConfig(apiKey: 'your-key'),
);

// Messages are automatically tracked
await ai.chat('Hello');
await ai.chat('Tell me more');

// Access the context manager
print(ai.context.estimatedTokens);
print(ai.context.availableTokens);

// Clear context
ai.clearContext();

// Reset with new system prompt
ai.reset(systemPrompt: 'New personality');

// Get conversation for serialization
final json = ai.conversation.toJson();
```

### Custom Context Manager

```dart
final contextManager = ContextManager(
  maxTokens: 8000,
  reservedTokens: 1000, // Reserve for response
  systemPrompt: 'You are helpful.',
  windowStrategy: WindowStrategy.slidingWindow,
);

final ai = FlutterAI(
  provider: AIProvider.openai,
  config: AIConfig(apiKey: 'your-key'),
  contextManager: contextManager,
);

// Listen to context updates
contextManager.updates.listen((update) {
  print('Context updated: ${update.type}');
  print('Messages: ${update.messageCount}');
  print('Tokens: ${update.estimatedTokens}');
});
```

## Provider-Specific Features

### OpenAI

```dart
final ai = FlutterAI(
  provider: AIProvider.openai,
  config: AIConfig(
    apiKey: 'sk-...',
    model: 'gpt-4-turbo', // or gpt-4, gpt-3.5-turbo, etc.
  ),
);
```

Supported models: `gpt-4-turbo`, `gpt-4`, `gpt-3.5-turbo`, `gpt-4o`, `gpt-4o-mini`

### Anthropic (Claude)

```dart
final ai = FlutterAI(
  provider: AIProvider.anthropic,
  config: AIConfig(
    apiKey: 'sk-ant-...',
    model: 'claude-3-5-sonnet-latest',
  ),
);
```

Supported models: `claude-3-opus-20240229`, `claude-3-sonnet-20240229`, `claude-3-haiku-20240307`, `claude-3-5-sonnet-latest`

### Google AI (Gemini)

```dart
final ai = FlutterAI(
  provider: AIProvider.googleAI,
  config: AIConfig(
    apiKey: 'your-google-ai-key',
    model: 'gemini-1.5-pro',
  ),
);
```

Supported models: `gemini-1.5-pro`, `gemini-1.5-flash`, `gemini-1.0-pro`

## Flutter Widget Integration

```dart
class ChatWidget extends StatefulWidget {
  @override
  _ChatWidgetState createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  late FlutterAI _ai;
  final _messages = <Message>[];
  String _streamingContent = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ai = FlutterAI(
      provider: AIProvider.openai,
      config: AIConfig(apiKey: 'your-key'),
    );
  }

  Future<void> _sendMessage(String text) async {
    setState(() {
      _messages.add(Message.user(text));
      _isLoading = true;
      _streamingContent = '';
    });

    await for (final chunk in _ai.streamChat(text)) {
      if (chunk.isDelta) {
        setState(() {
          _streamingContent += chunk.delta ?? '';
        });
      }
      if (chunk.isDone) {
        setState(() {
          _messages.add(Message.assistant(_streamingContent));
          _streamingContent = '';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _ai.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return ListTile(
                title: Text(message.text),
                subtitle: Text(message.role.name),
              );
            },
          ),
        ),
        if (_streamingContent.isNotEmpty)
          Padding(
            padding: EdgeInsets.all(8),
            child: Text(_streamingContent),
          ),
        // Add your message input UI here
      ],
    );
  }
}
```

## API Reference

### FlutterAI

| Method | Description |
|--------|-------------|
| `chat(String message)` | Send a text message |
| `chatWithContent(List<Content> content)` | Send multimodal content |
| `chatWithTools(String message, {required List<Tool> tools})` | Chat with tools |
| `submitToolResult({...})` | Submit tool result |
| `streamChat(String message)` | Stream a response |
| `streamChatWithContent(List<Content> content)` | Stream multimodal |
| `clearContext()` | Clear conversation |
| `reset({String? systemPrompt})` | Reset with new prompt |

### Content Types

| Type | Description |
|------|-------------|
| `TextContent(String text)` | Plain text |
| `ImageContent.fromUrl(String url)` | Image from URL |
| `ImageContent.fromBytes(Uint8List bytes)` | Image from bytes |
| `AudioContent.fromUrl(String url)` | Audio from URL |
| `DocumentContent.fromUrl(String url)` | Document from URL |

### Error Types

| Error | Description |
|-------|-------------|
| `AIAuthenticationError` | Invalid API key |
| `AIRateLimitError` | Rate limit exceeded |
| `AIInvalidRequestError` | Bad request parameters |
| `AIContextLengthError` | Context too long |
| `AIContentFilterError` | Content blocked |
| `AINetworkError` | Network issues |
| `AIServerError` | Server errors |

## Best Practices

1. **Always dispose** - Call `ai.dispose()` when done to release resources
2. **Handle errors** - Use try-catch for all API calls
3. **Monitor tokens** - Check `context.estimatedTokens` before sending large requests
4. **Stream for long responses** - Use `streamChat` for better UX
5. **Secure API keys** - Never hardcode keys, use environment variables or secure storage

## Support

- 📖 [Documentation](https://github.com/Amayyas/Flutter-AI-SDK/wiki)
- 🐛 [Issues](https://github.com/Amayyas/Flutter-AI-SDK/issues)
- 💬 [Discussions](https://github.com/Amayyas/Flutter-AI-SDK/discussions)
