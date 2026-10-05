#!/bin/sh
set -e
cd "$(dirname "$0")"

APP="NoSleep.app"
swiftc -O -framework Cocoa -o NoSleep main.swift
mkdir -p "$APP/Contents/MacOS"
mv NoSleep "$APP/Contents/MacOS/NoSleep"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" 2>/dev/null || true
echo "Built $APP"
