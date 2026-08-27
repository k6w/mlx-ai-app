#!/bin/zsh
set -euo pipefail

APP="$HOME/Applications/MLX AI.app"
CLI="$HOME/.local/bin/mlx-ai"
STAMP=$(/bin/date +%Y%m%d%H%M%S)
TRASH="$HOME/.Trash"

if [[ -x "$CLI" ]]; then "$CLI" stop 2>/dev/null || true; fi
/bin/launchctl bootout "gui/$UID/com.drwn.mlxai.server" 2>/dev/null || true
/bin/launchctl bootout "gui/$UID/com.drwn.mlxai" 2>/dev/null || true

[[ -d "$APP" ]] && /bin/mv "$APP" "$TRASH/MLX AI-$STAMP.app"
[[ -f "$CLI" ]] && /bin/mv "$CLI" "$TRASH/mlx-ai-$STAMP"
[[ -f "$HOME/Library/LaunchAgents/com.drwn.mlxai.server.plist" ]] && /bin/mv "$HOME/Library/LaunchAgents/com.drwn.mlxai.server.plist" "$TRASH/com.drwn.mlxai.server-$STAMP.plist"

LEGACY_BACKUPS=("$HOME/.local/bin"/mlx-ai.legacy-backup*(N.om))
if (( ${#LEGACY_BACKUPS} )); then
  /bin/cp "$LEGACY_BACKUPS[1]" "$CLI"
  /bin/chmod 755 "$CLI"
  echo "Restored the legacy CLI from $LEGACY_BACKUPS[1]."
fi

echo "MLX AI, its CLI, and launch agent were moved to Trash."
echo "Configuration and logs were retained in Library/Application Support/MLX AI and Library/Logs/MLX AI."
