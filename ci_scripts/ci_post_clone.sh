#!/bin/sh
set -eu

PLIST_PATH="$CI_WORKSPACE/ios/EnglishPlus/EnglishPlus/GoogleService-Info.plist"

if [ -z "${GOOGLE_SERVICE_INFO_PLIST_BASE64:-}" ]; then
  echo "error: GOOGLE_SERVICE_INFO_PLIST_BASE64 is not set in Xcode Cloud environment variables."
  exit 1
fi

mkdir -p "$(dirname "$PLIST_PATH")"
printf "%s" "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 -D > "$PLIST_PATH"

if [ ! -s "$PLIST_PATH" ]; then
  echo "error: Failed to create GoogleService-Info.plist."
  exit 1
fi

echo "GoogleService-Info.plist restored for Xcode Cloud build."
