import 'package:equatable/equatable.dart';

/// Time-to-live options for cached prompt prefixes.
enum PromptCacheTtl {
  /// Five minutes (provider default, cheapest cache writes).
  fiveMinutes,

  /// One hour (higher write cost, survives longer idle gaps).
  oneHour,
}

/// Prompt caching configuration.
///
/// Caching stores the repeated prefix of a prompt (system prompt, tools,
/// conversation history) on the provider side so subsequent requests only
/// pay a fraction of the input cost — up to ~90% cheaper on cached tokens.
///
/// Provider behavior:
/// - **Anthropic**: explicit — setting this enables caching of the request
///   prefix (`cache_control`), with the chosen [ttl].
/// - **OpenAI**: automatic for prompts over ~1024 tokens; nothing is sent,
///   but cache hits are reported in `Usage.cachedTokens`.
/// - **Google AI**: implicit caching is automatic; cache hits are reported
///   in `Usage.cachedTokens`.
/// - **Ollama**: local KV-cache, always on.
///
/// Example:
/// ```dart
/// final config = AIConfig(
///   apiKey: 'sk-ant-...',
///   systemPrompt: veryLongSystemPrompt,
///   promptCaching: PromptCaching(),
/// );
/// ```
class PromptCaching with Equatable {
  /// Creates a [PromptCaching] configuration.
  const PromptCaching({this.ttl = PromptCacheTtl.fiveMinutes});

  /// How long the cached prefix stays alive between requests.
  final PromptCacheTtl ttl;

  @override
  List<Object?> get props => [ttl];
}
