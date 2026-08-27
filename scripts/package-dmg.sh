#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
VERSION=${VERSION:-1.0.0}
BUILD_DIR="$PROJECT_DIR/.build"
STAGING="$BUILD_DIR/dmg-root"
DMG="$BUILD_DIR/MLX-AI-$VERSION.dmg"

"$SCRIPT_DIR/build-app.sh" >/dev/null
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
/usr/bin/ditto "$BUILD_DIR/MLX AI.app" "$STAGING/MLX AI.app"
ln -s /Applications "$STAGING/Applications"
/usr/bin/hdiutil create -volname "MLX AI" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null

if [[ -n ${MACOS_SIGN_IDENTITY:-} ]]; then
  /usr/bin/codesign --force --timestamp --sign "$MACOS_SIGN_IDENTITY" "$DMG"
fi
echo "$DMG"
