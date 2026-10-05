#!/bin/sh
set -e
cd "$(dirname "$0")"

APP="NoSleep.app"
swiftc -O -framework Cocoa -o NoSleep main.swift
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv NoSleep "$APP/Contents/MacOS/NoSleep"
cp Info.plist "$APP/Contents/Info.plist"
for lang in en ja; do
    mkdir -p "$APP/Contents/Resources/$lang.lproj"
    cp "$lang.lproj/Localizable.strings" "$APP/Contents/Resources/$lang.lproj/"
done
codesign --force --sign - "$APP" 2>/dev/null || true
echo "Built $APP"
