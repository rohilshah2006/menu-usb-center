#!/bin/bash

# Configuration
APP_NAME="MenuUSBCenter"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Clean previous build
rm -rf "$APP_BUNDLE"

# Create App bundle structure
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Compile Swift sources
echo "Compiling swift files..."
swiftc \
    -target arm64-apple-macos12.0 \
    -sdk $(xcrun --show-sdk-path) \
    -O \
    Sources/*.swift \
    -o "$MACOS/$APP_NAME"

# Check if compile succeeded
if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

# Copy Info.plist
cp Info.plist "$CONTENTS/Info.plist"

# Copy resources
if [ -d "Resources" ]; then
    cp -Rv Resources/* "$RESOURCES/" 2>/dev/null || true
fi
cp *.png "$RESOURCES/" 2>/dev/null || true

# Ad-hoc sign the app with entitlements
codesign --force --deep --sign - --entitlements MenuUSBCenter.entitlements "$APP_BUNDLE"

echo "Build succeeded: $APP_BUNDLE"
