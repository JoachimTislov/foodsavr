#!/usr/bin/env bash
# Install only the harnesses with configured Actions credentials.
set -euo pipefail

providers=()
if [[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
    npm install --global @anthropic-ai/claude-code@2.1.326
    providers+=(claude)
fi
if [[ -n "${CODEX_AUTH_JSON_B64:-}" ]]; then
    npm install --global @openai/codex@0.169.0
    install -d -m 700 "$HOME/.codex"
    (umask 077; printf '%s' "$CODEX_AUTH_JSON_B64" | base64 -d > "$HOME/.codex/auth.json")
    providers+=(codex)
fi
if [[ -n "${ANTIGRAVITY_OAUTH_TOKEN_B64:-}" || -n "${GEMINI_API_KEY:-}" ]]; then
    curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- --skip-aliases --skip-path
    echo "$HOME/.local/bin" >> "$GITHUB_PATH"
    install -d -m 700 "$HOME/.gemini/antigravity-cli"
    (
        umask 077
        settings="$HOME/.gemini/antigravity-cli/settings.json"
        if [[ -n "${ANTIGRAVITY_OAUTH_TOKEN_B64:-}" ]]; then
            printf '%s' "$ANTIGRAVITY_OAUTH_TOKEN_B64" | base64 -d > "$HOME/.gemini/antigravity-cli/antigravity-oauth-token"
            printf '{"agentMode":"auto","toolPermission":"proceed-in-sandbox","enableTerminalSandbox":true}\n' > "$settings"
        else
            printf '{"modelProvider":"gemini","agentMode":"auto","toolPermission":"proceed-in-sandbox","enableTerminalSandbox":true}\n' > "$settings"
        fi
    )
    providers+=(antigravity)
fi
echo "providers=${providers[*]}" >> "$GITHUB_OUTPUT"
