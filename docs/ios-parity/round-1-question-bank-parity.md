# English+ iOS Parity Round 1 Question Bank

## Goal

Bring the iOS seed question bank closer to the Android product baseline. The previous iOS seed had only 10 questions, which was not enough for daily missions, free practice, challenge routes, or teacher-facing learning evidence.

## Implementation

- Added `scripts/generate_ios_question_bank_seed.py`.
- Regenerated `ios/EnglishPlus/EnglishPlus/Resources/SeedData/question_bank_seed.json`.
- New seed count: 1080 approved questions.
- Covered types:
  - vocabulary: 120
  - grammar: 180
  - fillBlank: 180
  - cloze: 160
  - reading: 140
  - translation: 180
  - dialogue: 120
- Covered levels:
  - A1: 120
  - A2: 360
  - B1: 340
  - B2: 260

## Product Effect

Students should no longer see the same tiny set of questions repeatedly. Daily missions can choose from a much wider bank by preferred type and track, while free practice can show meaningful counts for every type.

## Verification

- `scripts/validate_ios_parity_rounds_0_to_2.py`
- `scripts/validate_ios_seed.py`

