# Security Policy

## Supported versions

Only the latest version published on
[pub.dev](https://pub.dev/packages/flutter_ai_sdk) receives security fixes.

## Reporting a vulnerability

**Please do not report security vulnerabilities through public GitHub
issues.**

Instead, use GitHub's private vulnerability reporting for this repository:

1. Go to the [Security tab](https://github.com/Amayyas/Flutter-AI-SDK/security)
2. Click **"Report a vulnerability"**
3. Describe the issue, its impact, and reproduction steps

Your report stays private between you and the maintainer while it is being
investigated and fixed. You will get a response as soon as possible, and a
coordinated disclosure once a fix is released.

## Scope notes

This SDK forwards API keys to the providers configured by the application
(OpenAI, Anthropic, Google AI, or a local Ollama server). Keys are never
sent anywhere else, logged, or persisted by the SDK. Issues in the provider
APIs themselves should be reported to the respective vendors.
