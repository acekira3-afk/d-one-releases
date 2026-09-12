#!/bin/zsh
set -e
cd "${0:A:h}"
APP="D-one.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/assets"
clang -fobjc-arc \
  -arch arm64 \
  -arch x86_64 \
  -mmacosx-version-min=14.0 \
  -framework Cocoa \
  -framework Security \
  -framework WebKit \
  native/main.m \
  -o "$APP/Contents/MacOS/DoingOne"
cp web/index.html "$APP/Contents/Resources/index.html"
cp web/subnote.html "$APP/Contents/Resources/subnote.html"
cp web/assistant.css "$APP/Contents/Resources/assistant.css"
cp web/assistant.js "$APP/Contents/Resources/assistant.js"
cp web/assets/miku-avatar-v2.png "$APP/Contents/Resources/assets/miku-avatar-v2.png"
cp web/assets/teto-avatar-v1.png "$APP/Contents/Resources/assets/teto-avatar-v1.png"
cp web/assets/neru-avatar-v1.png "$APP/Contents/Resources/assets/neru-avatar-v1.png"
cp web/assets/miku-sign-v1.png "$APP/Contents/Resources/assets/miku-sign-v1.png"
cp web/assets/teto-sign-v1.png "$APP/Contents/Resources/assets/teto-sign-v1.png"
cp web/assets/neru-sign-v1.png "$APP/Contents/Resources/assets/neru-sign-v1.png"
cp web/assets/mascot-miku.png "$APP/Contents/Resources/assets/mascot-miku.png"
cp web/assets/mascot-teto.png "$APP/Contents/Resources/assets/mascot-teto.png"
cp web/assets/mascot-neru.png "$APP/Contents/Resources/assets/mascot-neru.png"
cp web/assets/DOne.icns "$APP/Contents/Resources/DOne.icns"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "$PWD/$APP"
