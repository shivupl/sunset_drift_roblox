#!/usr/bin/env bash
# Runs luau-lsp strict analysis over src using Roblox global types.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.rokit/bin:$PATH"
if ! command -v luau-lsp >/dev/null; then echo "luau-lsp not installed (rokit add JohnnyMorganz/luau-lsp)"; exit 0; fi
if [ ! -f globalTypes.d.luau ]; then
  curl -fsSL -o globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --base-luaurc=.luaurc --sourcemap=sourcemap.json src
