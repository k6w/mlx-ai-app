#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
BUILD_DIR="$PROJECT_DIR/.build"
APP_PATH="$BUILD_DIR/MLX AI.app"
ICONSET="$BUILD_DIR/AppIcon.iconset"
VERSION=${VERSION:-1.0.0}
BUILD_NUMBER=${BUILD_NUMBER:-1}
SIGN_IDENTITY=${MACOS_SIGN_IDENTITY:--}

if [[ -d /Applications/Xcode-beta.app ]]; then
  export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}
fi
export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/module-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

cd "$PROJECT_DIR"
xcrun swift build -c release --disable-sandbox -debug-info-format none

rm -rf "$APP_PATH" "$ICONSET"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$ICONSET"
cp "$BUILD_DIR/release/MLXAI" "$APP_PATH/Contents/MacOS/MLXAI"
cp "$BUILD_DIR/release/mlx-ai" "$APP_PATH/Contents/Resources/mlx-ai"
chmod 755 "$APP_PATH/Contents/Resources/mlx-ai"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_PATH/Contents/Info.plist"

UV_SOURCE=${UV_BINARY:-}
if [[ -z "$UV_SOURCE" ]]; then UV_SOURCE=$(command -v uv 2>/dev/null || true); fi
if [[ -n "$UV_SOURCE" && -x "$UV_SOURCE" ]]; then
  cp "$UV_SOURCE" "$APP_PATH/Contents/Resources/uv"
  chmod 755 "$APP_PATH/Contents/Resources/uv"
fi

MASTER="$PROJECT_DIR/Resources/AppIcon-master.png"
for spec in "16 icon_16x16.png" "32 icon_16x16@2x.png" "32 icon_32x32.png" "64 icon_32x32@2x.png" "128 icon_128x128.png" "256 icon_128x128@2x.png" "256 icon_256x256.png" "512 icon_256x256@2x.png" "512 icon_512x512.png" "1024 icon_512x512@2x.png"; do
  size=${spec%% *}
  name=${spec#* }
  /usr/bin/sips -z "$size" "$size" "$MASTER" --out "$ICONSET/$name" >/dev/null
done
/usr/bin/iconutil -c icns "$ICONSET" -o "$APP_PATH/Contents/Resources/AppIcon.icns" 2>/dev/null || true
if [[ ! -s "$APP_PATH/Contents/Resources/AppIcon.icns" ]]; then
  TIFF_DIR="$BUILD_DIR/AppIcon-tiffs"
  MULTI_TIFF="$BUILD_DIR/AppIcon-multi.tiff"
  rm -rf "$TIFF_DIR"
  mkdir -p "$TIFF_DIR"
  for size in 16 32 128 256 512 1024; do
    /usr/bin/sips -z "$size" "$size" -s format tiff "$MASTER" --out "$TIFF_DIR/icon_$size.tiff" >/dev/null
  done
  /usr/bin/tiffutil -cat "$TIFF_DIR"/*.tiff -out "$MULTI_TIFF" >/dev/null 2>&1
  /usr/bin/tiff2icns "$MULTI_TIFF" "$APP_PATH/Contents/Resources/AppIcon.icns"
fi
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  /usr/bin/codesign --force --deep --sign - "$APP_PATH"
else
  /usr/bin/codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_PATH"
fi

echo "$APP_PATH"
