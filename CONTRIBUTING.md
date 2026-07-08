# Contributing to Flutter AI SDK

Thank you for your interest in contributing! This document explains how to
get set up, what we expect from contributions, and how the project is
organized.

By participating, you agree to follow our
[Code of Conduct](CODE_OF_CONDUCT.md).

## Getting started

1. **Fork** the repository and clone your fork:

   ```bash
   git clone https://github.com/YOUR_USERNAME/Flutter-AI-SDK.git
   cd Flutter-AI-SDK
   ```

2. **Set up** the development environment:

   ```bash
   flutter pub get
   flutter test   # verify everything passes before you start
   ```

3. **Create a branch** from `main`:

   ```bash
   git checkout -b feat/your-feature-name
   # or fix/your-bug-fix, docs/..., chore/...
   ```

## Project architecture

A quick map to find your way around `lib/src/`:

| Module | Role |
|---|---|
| `config/` | `AIConfig`, response formats, per-provider defaults |
| `models/` | Messages, content types (sealed), tools, responses |
| `providers/` | One folder per provider: a thin provider class + a stateless wire-format **mapper** |
| `providers/provider_registry.dart` | Factory mapping `AIProvider` → implementation |
| `runner/` | `ToolRunner`: automatic tool-calling loop |
| `context/`, `errors/`, `utils/` | Conversation history, typed errors, HTTP/tokens |

Key conventions:

- **One class per file.** Sealed hierarchies use `part` files.
- **Wire formats live in mappers.** If you change how a request is built or
  a response is parsed, the change belongs in the provider's `*_mapper.dart`.
- **Adding a provider?** Create a folder under `providers/` with a provider +
  mapper pair, add the enum value, defaults (`model_defaults.dart`), register
  it in `ProviderRegistry`, and mirror the test structure of an existing
  provider (e.g. `test/providers/ollama_provider_test.dart`).

## Quality bar

Before submitting, make sure all four pass locally (CI enforces them):

```bash
dart format .                        # formatting
flutter analyze                      # no new warnings or errors
flutter test                         # all tests green
dart pub publish --dry-run           # package still publishable
```

- Write tests for any new behavior (providers are tested with a mocked
  HTTP client — see `test/providers/` for the pattern).
- Add dartdoc comments on all public APIs.
- Update `CHANGELOG.md` under an `## Unreleased` heading if your change is
  user-visible.

## Commit messages

We use bracketed tags, present tense:

```
[ADD] Ollama provider for locally hosted models
[UPDATE] Refresh default models to current generations
[FIX] Merge consecutive same-role messages in the Anthropic mapper
[STYLE] Apply dart format across the package
```

Common tags: `[ADD]`, `[UPDATE]`, `[FIX]`, `[STYLE]`, `[DELETE]`.

## Submitting a pull request

1. Push your branch to your fork and open a PR against `main`.
2. Fill in the PR template (summary, changes, verification).
3. Make sure CI is green.
4. A maintainer will review it — please be patient and responsive to
   feedback.

## Questions?

- 💬 [GitHub Discussions](https://github.com/Amayyas/Flutter-AI-SDK/discussions) — questions and ideas
- 🐛 [Issues](https://github.com/Amayyas/Flutter-AI-SDK/issues) — bugs and feature requests
- 🔒 Security vulnerability? **Do not open a public issue** — see [SECURITY.md](SECURITY.md)
