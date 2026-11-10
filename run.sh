#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$PROJECT_DIR/Capri Companion.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP_PATH="$INSTALL_DIR/Capri Companion.app"
CONTENTS="$APP_PATH/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
mkdir -p "$MACOS" "$RESOURCES"

SOURCE_FILES=("$PROJECT_DIR"/Sources/*.swift)
ASSET_FILES=("$PROJECT_DIR"/Assets/*.png)
EXECUTABLE="$MACOS/CapriCompanion"
NEEDS_BUILD=0
if [[ ! -x "$EXECUTABLE" ]]; then NEEDS_BUILD=1; fi
for source in "${SOURCE_FILES[@]}" "${ASSET_FILES[@]}" "$PROJECT_DIR/Info.plist"; do
  if [[ "$source" -nt "$EXECUTABLE" ]]; then NEEDS_BUILD=1; fi
done

if [[ "$NEEDS_BUILD" == 1 ]]; then
  SDK_PATH="$(xcrun --show-sdk-path)"
  # Some CLT installations bundle a newer compiler than the newest SDK interface. Prefer
  # the compatible macOS 15 SDK when it is present; it still supports the macOS 13 target.
  if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
  fi
  mkdir -p "$PROJECT_DIR/.build/ModuleCache"
  export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/ModuleCache"
  SWIFT_FLAGS=(-swift-version 5 -O -sdk "$SDK_PATH" -module-cache-path "$PROJECT_DIR/.build/ModuleCache")
  LINK_FLAGS=(-framework SwiftUI -framework AppKit -framework Combine -framework AVFoundation -framework Speech -framework Vision)

  swiftc "${SWIFT_FLAGS[@]}" -target x86_64-apple-macosx13.0 "${SOURCE_FILES[@]}" "${LINK_FLAGS[@]}" -o "$MACOS/CapriCompanion-x86_64"
  swiftc "${SWIFT_FLAGS[@]}" -target arm64-apple-macosx13.0 "${SOURCE_FILES[@]}" "${LINK_FLAGS[@]}" -o "$MACOS/CapriCompanion-arm64"
  lipo -create "$MACOS/CapriCompanion-x86_64" "$MACOS/CapriCompanion-arm64" -output "$EXECUTABLE"
  rm "$MACOS/CapriCompanion-x86_64" "$MACOS/CapriCompanion-arm64"
  cp "$PROJECT_DIR/Info.plist" "$CONTENTS/Info.plist"
  rm -rf "$RESOURCES"
  mkdir -p "$RESOURCES"
  cp "${ASSET_FILES[@]}" "$RESOURCES/"
  printf 'APPL????' > "$CONTENTS/PkgInfo"
  codesign --force --deep --sign - "$APP_PATH" >/dev/null
fi

mkdir -p "$INSTALL_DIR"
/usr/bin/ditto "$APP_PATH" "$INSTALLED_APP_PATH"
codesign --verify --deep --strict "$INSTALLED_APP_PATH"

if ! open -n "$INSTALLED_APP_PATH" >/dev/null 2>&1; then
  # Some managed macOS desktops refuse Launch Services registration for unsigned
  # workspace bundles. Run the already-built local executable as a fallback.
  printf 'Launch Services did not open the installed app; starting Capri directly.\n'
  nohup "$INSTALLED_APP_PATH/Contents/MacOS/CapriCompanion" >/dev/null 2>&1 </dev/null &
fi
printf 'Installed and started %s\n' "$INSTALLED_APP_PATH"
