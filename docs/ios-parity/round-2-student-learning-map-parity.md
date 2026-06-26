# English+ iOS Parity Round 2 Student Learning Map

## Goal

Replace the iOS placeholder learning map with a real student-facing route screen. The Android product used the map as a place to understand today's route, progress, mistake repair, available practice, and support timeline.

## Implementation

- Added `ios/EnglishPlus/EnglishPlus/Features/Student/StudentLearningMapView.swift`.
- Updated `StudentShellView` so the map tab opens `StudentLearningMapView()`.
- Added the new Swift file to `EnglishPlus.xcodeproj` Sources.

## User Experience

The map now gives the student a sequence instead of a wall of unrelated information:

1. Today's route and mission progress.
2. Route nodes for mood check-in, daily mission, repair/steady/challenge track, free practice, and support replies.
3. Question-bank breadth by type.
4. Student-visible support timeline.

The map clearly separates daily mission progress from free practice. It uses mission state, check-in state, support requests, and question-bank data already present in the repository.

## Verification

- `scripts/validate_ios_parity_rounds_0_to_2.py`

