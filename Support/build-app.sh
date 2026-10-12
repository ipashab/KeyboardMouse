#!/bin/bash
# Сборка приложения KeyboardMouse.app из SPM-проекта (Xcode не требуется).
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"

APP="build/KeyboardMouse.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/$CONFIG/KeyboardMouse" "$APP/Contents/MacOS/KeyboardMouse"
cp Support/Info.plist "$APP/Contents/Info.plist"

# Иконка приложения.
swift Support/generate-icon.swift "$APP/Contents/Resources/AppIcon.iconset"
iconutil -c icns "$APP/Contents/Resources/AppIcon.iconset" \
    -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$APP/Contents/Resources/AppIcon.iconset"

# Ad-hoc подпись: без неё система может отказать в доступе Accessibility.
codesign --force --sign - "$APP"

# Второй аргумент --install: установка в /Applications (чистая замена).
if [ "${2:-}" = "--install" ]; then
    killall KeyboardMouse 2>/dev/null || true
    rm -rf /Applications/KeyboardMouse.app
    cp -R "$APP" /Applications/
    codesign --force --sign - /Applications/KeyboardMouse.app
    open /Applications/KeyboardMouse.app
    echo "Установлено в /Applications и запущено."
    echo "ВНИМАНИЕ: пересборка меняет CDHash — разрешение Accessibility нужно включать заново."
    exit 0
fi

echo "Готово: $(cd build && pwd)/KeyboardMouse.app"
echo "Установка: $0 $CONFIG --install"
