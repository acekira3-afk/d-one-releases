#!/bin/zsh
set -euo pipefail

cd "${0:A:h}"

APP_NAME="D-one"
DMG_NAME="D-one-2nd-EDITION-ver2.32-preview.dmg"
STAGING_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

./build-app.sh

cp -R "${APP_NAME}.app" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

mkdir -p releases
rm -f "releases/$DMG_NAME"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "releases/$DMG_NAME"

hdiutil verify "releases/$DMG_NAME"
shasum -a 256 "releases/$DMG_NAME"
