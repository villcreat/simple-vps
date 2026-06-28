# Codex Implementation Notes

This repository was scaffolded from `VPS_SIMPLE_CODEX_FULL_PROMPT.md`.

Implementation rules:

1. Build modules incrementally.
2. Keep Linux and Windows Server scenarios separate.
3. Do not store secrets in plain text.
4. Do not run dangerous commands without confirmation.
5. Provide dry-run for every scenario.
6. Add security events for dangerous actions.
7. Document limitations while features are stubbed.
