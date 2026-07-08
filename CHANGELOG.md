# Changelog

All notable changes to Flutter AI SDK are documented here.

## 1.4.0 - 2026-07-08

### Prompt caching & universal document input

- **Prompt caching**: new `AIConfig.promptCaching` (`PromptCaching`, 5 min or
  1 h TTL) — explicit `cache_control` on Anthropic; cache hit counters parsed
  on every provider (`Usage.cachedTokens`, new `Usage.cacheWriteTokens`).
- **Documents**: `DocumentContent` now works on every cloud provider —
  URL sources added on Anthropic, base64 `file` blocks added on OpenAI
  (URL passed as a text reference), Google AI unchanged. Support table in
  the README.

## 1.3.0 - 2026-07-08

### Structured outputs & token counting

- **Structured outputs**: `ResponseFormat.json(schema: ...)` now uses each
  provider's native guaranteed-schema mechanism — OpenAI `json_schema`
  (with opt-in `strict` mode), Anthropic `output_config.format`, Gemini
  `responseJsonSchema`, Ollama schema format.
- **Token counting**: new `countTokens` on providers and
  `FlutterAI.countTokens({message})` on the facade — exact server-side
  counts on Anthropic (`/messages/count_tokens`) and Google AI
  (`:countTokens`); local estimation elsewhere.

## 1.2.0 - 2026-07-07

### Architecture overhaul & new features

- **Architecture**: full restructuring into one-class-per-file modules —
  `config/`, `models/content/` (sealed hierarchy as part files),
  `models/tools/`; one folder per provider with a dedicated wire-format
  mapper; shared streaming loop in `BaseProvider` (template method);
  new `ProviderRegistry` factory supporting custom provider registration.
  The public API is unchanged.
- **Tool Runner**: automatic agentic tool-calling loop (`ToolRunner`,
  `ExecutableTool`) — parallel tool execution, error feedback to the
  model, iteration budget, observability callbacks.
- **Ollama provider**: run local models (Llama, Qwen, Gemma...) with
  streaming (NDJSON), tools, JSON mode and vision; no API key required.
- **Anthropic**: consecutive same-role messages are merged, as required
  by the API's role alternation (fixes parallel tool results).
- Dependencies upgraded for Flutter 3.44.

## 1.1.0 - 2026-07-06

### Model refresh

- Default models updated to current generations: `gpt-5.5`,
  `claude-opus-4-8`, `gemini-3.5-flash`.
- Model context limits updated (GPT-5.x, Claude 4/5, Gemini 3.x).
- Anthropic provider: never sends `temperature` and `top_p` together
  (rejected by Claude 4+); maps the `refusal` and
  `model_context_window_exceeded` stop reasons.
- Providers can receive an injected HTTP client; `FlutterAI` accepts a
  custom provider. Unit tests for all providers and a CI workflow added.
- Dependencies upgraded (`mime` 2.x, `rxdart` 0.28, `flutter_lints` 6).

## 1.0.0 - 2025-11-30

### Initial release

- Unified API for OpenAI, Anthropic and Google AI.
- Streaming with chunk events, context management and memory.
- Multimodal content (text, images, audio, documents).
- Function calling for all providers, typed error handling,
  token estimation.
