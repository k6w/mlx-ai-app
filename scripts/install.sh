#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
OLD_CLI="$HOME/.local/bin/mlx-ai"
INSTALL_APP="$HOME/Applications/MLX AI.app"
RESTORE_SERVER=0

if [[ -f "$OLD_CLI" ]] && /usr/bin/grep -q 'mlx_lm server' "$OLD_CLI"; then
  if "$OLD_CLI" status 2>/dev/null | /usr/bin/grep -q running; then
    PORT_PID=$(/usr/sbin/lsof -nP -iTCP:8080 -sTCP:LISTEN -t 2>/dev/null | /usr/bin/head -1 || true)
    LEGACY_PID=$(/usr/bin/pgrep -f 'mlx_lm server' 2>/dev/null | /usr/bin/head -1 || true)
    if [[ -z "$PORT_PID" || "$PORT_PID" != "$LEGACY_PID" ]]; then
      echo "Port 8080 is not owned by the legacy MLX process; refusing to stop it." >&2
      exit 1
    fi
    RESTORE_SERVER=1
    "$OLD_CLI" stop
  fi
  BACKUP="$OLD_CLI.legacy-backup"
  if [[ -e "$BACKUP" ]]; then BACKUP="$BACKUP.$(/bin/date +%Y%m%d%H%M%S)"; fi
  /bin/cp "$OLD_CLI" "$BACKUP"
  echo "Backed up the legacy CLI to $BACKUP"
fi

"$SCRIPT_DIR/build-app.sh" >/dev/null
/bin/mkdir -p "$HOME/Applications" "$HOME/.local/bin"
if [[ -d "$INSTALL_APP" ]]; then
  PREVIOUS="$HOME/Applications/MLX AI.previous.app"
  [[ -e "$PREVIOUS" ]] && /bin/rm -rf "$PREVIOUS"
  /bin/mv "$INSTALL_APP" "$PREVIOUS"
fi
/usr/bin/ditto "$PROJECT_DIR/.build/MLX AI.app" "$INSTALL_APP"
/bin/cp "$PROJECT_DIR/.build/release/mlx-ai" "$OLD_CLI"
/bin/chmod 755 "$OLD_CLI"

if (( RESTORE_SERVER )); then "$OLD_CLI" start; fi
/usr/bin/open "$INSTALL_APP"
echo "Installed MLX AI in $INSTALL_APP"
echo "CLI installed at $OLD_CLI"
