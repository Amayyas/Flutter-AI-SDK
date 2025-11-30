/// Flutter AI SDK - A unified wrapper for integrating various AI APIs.
///
/// This library provides a unified interface for interacting with multiple
/// AI providers including OpenAI, Anthropic (Claude), and Google AI (Gemini).
///
/// ## Features
///
/// - **Unified API**: Single interface for all providers
/// - **Streaming Support**: Real-time response streaming
/// - **Context Management**: Conversation history and memory
/// - **Multimodal Support**: Text, images, audio, and documents
/// - **Error Handling**: Comprehensive error types and retry logic
/// - **Type Safety**: Full Dart type safety with null safety
///
/// ## Quick Start
///
/// ```dart
/// import 'package:flutter_ai_sdk/flutter_ai_sdk.dart';
///
/// // Initialize the SDK
/// final ai = FlutterAI(
///   provider: AIProvider.openai,
///   config: AIConfig(
///     apiKey: 'your-api-key',
///     model: 'gpt-4',
///   ),
/// );
///
/// // Send a simple message
/// final response = await ai.chat('Hello, how are you?');
/// print(response.content);
///
/// // Stream responses
/// await for (final chunk in ai.streamChat('Tell me a story')) {
///   print(chunk.content);
/// }
/// ```
///
/// ## Providers
///
/// The SDK supports the following AI providers:
///
/// - **OpenAI**: GPT-4, GPT-3.5-turbo, and other models
/// - **Anthropic**: Claude 3 (Opus, Sonnet, Haiku)
/// - **Google AI**: Gemini Pro, Gemini Pro Vision
///
/// ## Configuration
///
/// Each provider can be configured with specific options:
///
/// ```dart
/// final config = AIConfig(
///   apiKey: 'your-api-key',
///   model: 'gpt-4-turbo',
///   maxTokens: 4096,
///   temperature: 0.7,
///   systemPrompt: 'You are a helpful assistant.',
/// );
/// ```
///
/// ## Error Handling
///
/// The SDK provides comprehensive error handling:
///
/// ```dart
/// try {
///   final response = await ai.chat('Hello');
/// } on AIAuthenticationError catch (e) {
///   print('Invalid API key: ${e.message}');
/// } on AIRateLimitError catch (e) {
///   print('Rate limited, retry after: ${e.retryAfter}');
/// } on AIError catch (e) {
///   print('AI error: ${e.message}');
/// }
/// ```
library flutter_ai_sdk;

// Core exports
export 'src/flutter_ai.dart';
export 'src/config/ai_config.dart';

// Models
export 'src/models/models.dart';

// Providers
export 'src/providers/providers.dart';

// Context Management
export 'src/context/context.dart';

// Errors
export 'src/errors/errors.dart';

// Utils
export 'src/utils/utils.dart';
