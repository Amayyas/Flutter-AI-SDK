/// Enumerations used throughout the Flutter AI SDK.

/// Supported AI providers.
///
/// Example:
/// ```dart
/// final ai = FlutterAI(
///   provider: AIProvider.openai,
///   config: AIConfig(apiKey: 'your-key'),
/// );
/// ```
enum AIProvider {
  /// OpenAI provider (GPT-4, GPT-3.5, etc.)
  openai,

  /// Anthropic provider (Claude 3 Opus, Sonnet, Haiku)
  anthropic,

  /// Google AI provider (Gemini Pro, Gemini Pro Vision)
  googleAI,
}

/// Role of a message in a conversation.
///
/// Defines who sent the message in the conversation.
enum MessageRole {
  /// Message from the system (instructions).
  system,

  /// Message from the user.
  user,

  /// Message from the AI assistant.
  assistant,

  /// Message containing tool/function results.
  tool,
}

/// Type of content in a message.
///
/// Messages can contain different types of content.
enum ContentType {
  /// Plain text content.
  text,

  /// Image content (URL or base64).
  image,

  /// Audio content.
  audio,

  /// Video content.
  video,

  /// Document/file content.
  document,

  /// Tool/function call.
  toolCall,

  /// Tool/function result.
  toolResult,
}

/// Image detail level for vision models.
///
/// Controls how much detail the model should use when analyzing images.
enum ImageDetail {
  /// Low detail - faster and cheaper.
  low,

  /// High detail - more accurate.
  high,

  /// Let the model decide.
  auto,
}

/// Reason why the model stopped generating.
///
/// This indicates why the model finished its response.
enum FinishReason {
  /// Normal completion.
  stop,

  /// Maximum token limit reached.
  maxTokens,

  /// Content filtered by safety systems.
  contentFilter,

  /// Model called a tool/function.
  toolCalls,

  /// Unknown or unexpected reason.
  unknown,
}

/// Streaming event types.
///
/// Types of events that can occur during streaming.
enum StreamEventType {
  /// Stream started.
  start,

  /// Content delta received.
  delta,

  /// Tool call started.
  toolCallStart,

  /// Tool call delta.
  toolCallDelta,

  /// Stream completed.
  done,

  /// Error occurred.
  error,
}

/// Model capability flags.
///
/// Indicates what capabilities a model supports.
enum ModelCapability {
  /// Text generation.
  text,

  /// Image understanding (vision).
  vision,

  /// Audio understanding.
  audio,

  /// Tool/function calling.
  tools,

  /// JSON mode output.
  jsonMode,

  /// Streaming responses.
  streaming,

  /// System prompts.
  systemPrompt,
}
