#!/bin/bash
# Сборка DMG с приложением (Xcode не нужен, используется hdiutil).
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Support/Info.plist)
DMG="build/KeyboardMouse-${VERSION}.dmg"

# Обновляем бандл.
./Support/build-app.sh release

# Стaging: приложение + symlink на /Applications для перетаскивания.
STAGE="build/dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R build/KeyboardMouse.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create \
    -volname "KeyboardMouse ${VERSION}" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG" > /dev/null

rm -rf "$STAGE"

# Проверяем, что образ читается.
hdiutil verify "$DMG" > /dev/null
echo "Готово: $(cd build && pwd)/KeyboardMouse-${VERSION}.dmg"
