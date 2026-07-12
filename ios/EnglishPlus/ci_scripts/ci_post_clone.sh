#!/bin/sh
set -eu

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-${CI_WORKSPACE:-$(pwd)}}"
PLIST_PATH="$REPO_ROOT/ios/EnglishPlus/EnglishPlus/GoogleService-Info.plist"
INFO_PLIST_PATH="$REPO_ROOT/ios/EnglishPlus/EnglishPlus/Info.plist"

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

REVERSED_CLIENT_ID=$(/usr/libexec/PlistBuddy -c "Print :REVERSED_CLIENT_ID" "$PLIST_PATH" 2>/dev/null || true)
if [ -z "$REVERSED_CLIENT_ID" ]; then
  echo "error: Google Sign-In is enabled in code but REVERSED_CLIENT_ID is missing."
  echo "error: Enable Google in Firebase Authentication and refresh GOOGLE_SERVICE_INFO_PLIST_BASE64."
  exit 1
fi

/usr/libexec/PlistBuddy -c "Delete :CFBundleURLTypes" "$INFO_PLIST_PATH" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$INFO_PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$INFO_PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleTypeRole string Editor" "$INFO_PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$INFO_PLIST_PATH"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $REVERSED_CLIENT_ID" "$INFO_PLIST_PATH"
echo "Google Sign-In URL scheme configured for this build."
