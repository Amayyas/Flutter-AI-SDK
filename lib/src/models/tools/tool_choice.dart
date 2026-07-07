import 'package:equatable/equatable.dart';

/// Enum for provider types (internal use).
enum AIProviderType { openai, anthropic, googleAI }

/// Configuration for tool choice behavior.
///
/// Controls how the model uses tools.
sealed class ToolChoice with Equatable {
  /// Creates a [ToolChoice].
  const ToolChoice();

  /// Let the model decide whether to use tools.
  const factory ToolChoice.auto() = AutoToolChoice;

  /// Model must not use any tools.
  const factory ToolChoice.none() = NoneToolChoice;

  /// Model must use a specific tool.
  const factory ToolChoice.tool(String name) = SpecificToolChoice;

  /// Model must use any tool.
  const factory ToolChoice.required() = RequiredToolChoice;

  /// Converts to provider-specific format.
  dynamic toProviderFormat(AIProviderType provider);
}

/// Auto tool choice.
final class AutoToolChoice extends ToolChoice {
  /// Creates an [AutoToolChoice].
  const AutoToolChoice();

  @override
  dynamic toProviderFormat(AIProviderType provider) => switch (provider) {
        AIProviderType.openai => 'auto',
        AIProviderType.anthropic => {'type': 'auto'},
        AIProviderType.googleAI => 'AUTO',
      };

  @override
  List<Object?> get props => [];
}

/// None tool choice.
final class NoneToolChoice extends ToolChoice {
  /// Creates a [NoneToolChoice].
  const NoneToolChoice();

  @override
  dynamic toProviderFormat(AIProviderType provider) => switch (provider) {
        AIProviderType.openai => 'none',
        AIProviderType.anthropic => {'type': 'none'},
        AIProviderType.googleAI => 'NONE',
      };

  @override
  List<Object?> get props => [];
}

/// Required tool choice.
final class RequiredToolChoice extends ToolChoice {
  /// Creates a [RequiredToolChoice].
  const RequiredToolChoice();

  @override
  dynamic toProviderFormat(AIProviderType provider) => switch (provider) {
        AIProviderType.openai => 'required',
        AIProviderType.anthropic => {'type': 'any'},
        AIProviderType.googleAI => 'ANY',
      };

  @override
  List<Object?> get props => [];
}

/// Specific tool choice.
final class SpecificToolChoice extends ToolChoice {
  /// Creates a [SpecificToolChoice].
  const SpecificToolChoice(this.name);

  /// The tool name.
  final String name;

  @override
  dynamic toProviderFormat(AIProviderType provider) => switch (provider) {
        AIProviderType.openai => {
            'type': 'function',
            'function': {'name': name},
          },
        AIProviderType.anthropic => {'type': 'tool', 'name': name},
        AIProviderType.googleAI => name,
      };

  @override
  List<Object?> get props => [name];
}
