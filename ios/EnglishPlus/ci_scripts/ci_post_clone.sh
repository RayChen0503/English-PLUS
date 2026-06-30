#!/bin/sh
set -eu

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$CI_WORKSPACE}"
PLIST_PATH="$REPO_ROOT/ios/EnglishPlus/EnglishPlus/GoogleService-Info.plist"

echo "CI_WORKSPACE=${CI_WORKSPACE:-}"
echo "CI_PRIMARY_REPOSITORY_PATH=${CI_PRIMARY_REPOSITORY_PATH:-}"
echo "Restoring GoogleService-Info.plist to $PLIST_PATH"

if [ -z "${GOOGLE_SERVICE_INFO_PLIST_BASE64:-}" ]; then
  echo "error: GOOGLE_SERVICE_INFO_PLIST_BASE64 is not set in Xcode Cloud environment variables."
  exit 1
fi

mkdir -p "$(dirname "$PLIST_PATH")"
printf "%s" "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 --decode > "$PLIST_PATH" 2>/dev/null || \
printf "%s" "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 -D > "$PLIST_PATH"

if [ ! -s "$PLIST_PATH" ]; then
  echo "error: Failed to create GoogleService-Info.plist."
  exit 1
fi

echo "GoogleService-Info.plist restored for Xcode Cloud build."
