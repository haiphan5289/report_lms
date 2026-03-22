#!/bin/bash
#
# Firebase dSYM Upload Helper Script
# Usage: ./scripts/upload-dsyms.sh
#

set -e

echo "🔍 Firebase dSYM Upload Helper"
echo "================================"

# Configuration
FIREBASE_APP_ID="YOUR_FIREBASE_APP_ID" # Replace with your Firebase App ID
ARCHIVE_PATH="${1}"

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found"
    echo "Install with: npm install -g firebase-tools"
    echo "Then login: firebase login"
    exit 1
fi

# Find latest archive if not specified
if [ -z "$ARCHIVE_PATH" ]; then
    echo "📦 Finding latest archive..."
    ARCHIVES_DIR="$HOME/Library/Developer/Xcode/Archives"
    LATEST_ARCHIVE=$(find "$ARCHIVES_DIR" -name "*.xcarchive" -type d -print0 | xargs -0 ls -td | head -1)
    
    if [ -z "$LATEST_ARCHIVE" ]; then
        echo "❌ No archives found in: $ARCHIVES_DIR"
        exit 1
    fi
    
    ARCHIVE_PATH="$LATEST_ARCHIVE"
fi

echo "📂 Archive: $ARCHIVE_PATH"

# Check if archive exists
if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "❌ Archive not found: $ARCHIVE_PATH"
    exit 1
fi

# Find dSYMs
DSYM_PATH="${ARCHIVE_PATH}/dSYMs"

if [ ! -d "$DSYM_PATH" ]; then
    echo "❌ dSYMs folder not found: $DSYM_PATH"
    echo "💡 Ensure 'Debug Information Format' is set to 'DWARF with dSYM File' in Build Settings"
    exit 1
fi

# List dSYMs
echo "📋 Found dSYMs:"
ls -lh "$DSYM_PATH"

# Upload to Firebase
echo "🚀 Uploading dSYMs to Firebase..."
if [ "$FIREBASE_APP_ID" == "YOUR_FIREBASE_APP_ID" ]; then
    echo "⚠️  Please update FIREBASE_APP_ID in this script"
    echo "Find it in Firebase Console → Project Settings → Your iOS app"
    exit 1
fi

firebase crashlytics:symbols:upload \
  --app="${FIREBASE_APP_ID}" \
  "${DSYM_PATH}"

if [ $? -eq 0 ]; then
    echo "✅ Upload successful!"
else
    echo "❌ Upload failed"
    exit 1
fi
