#!/usr/bin/env python3
"""Validate the final first-session sync, account UI, notice, and App Icon bundle."""

from __future__ import annotations

import json
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require_contains(path: str, markers: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [marker for marker in markers if marker not in text]
    if missing:
        raise AssertionError(f"{path} is missing: {missing}")


def png_metadata(path: Path) -> tuple[int, int, int]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise AssertionError(f"{path.name} is not a valid PNG")
    width, height, _bit_depth, color_type = struct.unpack(">IIBB", data[16:26])
    return width, height, color_type


def validate_app_icons() -> None:
    icon_dir = ROOT / "ios/EnglishPlus/EnglishPlus/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((icon_dir / "Contents.json").read_text(encoding="utf-8"))
    entries = [entry for entry in contents["images"] if entry.get("filename")]
    if len(entries) != 18:
        raise AssertionError(f"Expected 18 iOS icon entries, found {len(entries)}")

    for entry in entries:
        points = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        expected_pixels = round(points * scale)
        icon_path = icon_dir / entry["filename"]
        if not icon_path.exists():
            raise AssertionError(f"Missing App Icon: {entry['filename']}")
        width, height, color_type = png_metadata(icon_path)
        if (width, height) != (expected_pixels, expected_pixels):
            raise AssertionError(
                f"{entry['filename']} is {width}x{height}; expected {expected_pixels}x{expected_pixels}"
            )
        if color_type != 2:
            raise AssertionError(
                f"{entry['filename']} must be opaque RGB (PNG color type 2), found {color_type}"
            )


def main() -> None:
    require_contains(
        "ios/EnglishPlus/EnglishPlus/Services/LearningRepositoryStore.swift",
        [
            "restartRealtimeSyncAfterCreatingSupportThread",
            "if succeeded {",
            "beginRealtimeListening(context: context, isRetry: false)",
        ],
    )
    require_contains(
        "ios/EnglishPlus/EnglishPlus/App/RootView.swift",
        [
            ".onChange(of: appState.currentUser?.id)",
            ".onChange(of: appState.currentProfile?.id)",
        ],
    )
    require_contains(
        "ios/EnglishPlus/EnglishPlus/Services/FirebaseLearningRepository.swift",
        [
            "userUid: activeUserUid",
            "role: activeUserRole",
            "whereField(\"studentUid\", isEqualTo: userUid ?? \"\")",
        ],
    )
    require_contains(
        "ios/EnglishPlus/EnglishPlus/Features/Volunteer/VolunteerHomeView.swift",
        [
            "VolunteerReviewNoticeStore",
            "volunteer.review.notice.dismiss",
            "這則通知不會再於登入時顯示",
        ],
    )
    require_contains(
        "ios/EnglishPlus/EnglishPlus/Features/RoleSelection/DemoLoginView.swift",
        [
            "scheme: .light",
            ".whiteOutline",
            ".frame(height: 52)",
            "providerButtonShape",
        ],
    )
    require_contains(
        "ios/EnglishPlus/EnglishPlusTests/AuthenticationFlowAcceptanceTests.swift",
        [
            "testCreatingFirstSupportRequestRestartsListenerForThreadMessages",
            "VolunteerReviewNoticeStoreTests",
        ],
    )
    validate_app_icons()
    print("Release polish bundle validation passed.")


if __name__ == "__main__":
    main()
