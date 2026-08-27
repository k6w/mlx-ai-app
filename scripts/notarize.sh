#!/bin/zsh
set -euo pipefail

DMG=${1:?Usage: scripts/notarize.sh path-to.dmg}
: ${APPLE_ID:?APPLE_ID is required}
: ${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}
: ${APPLE_APP_PASSWORD:?APPLE_APP_PASSWORD is required}

xcrun notarytool submit "$DMG" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
