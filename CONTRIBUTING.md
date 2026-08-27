# Contributing

Thank you for improving MLX AI.

1. Fork the repository and create a focused branch from `main`.
2. Build with `make build` and run `make test`.
3. Keep lifecycle logic in `MLXAIKit` so the app and CLI remain consistent.
4. Add tests for behavior changes, especially process operations and state transitions.
5. Open a pull request using the repository template.

Never commit certificates, Apple credentials, models, Python environments, or user configuration. Check UI changes in light/dark mode and increased contrast. Process changes must never kill a PID not verified as belonging to MLX AI.

Contributions are licensed under the MIT License.
