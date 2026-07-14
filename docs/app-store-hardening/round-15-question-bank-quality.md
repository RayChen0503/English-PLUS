# Round 15 - Question-bank taxonomy and set quality

Status: Complete

Date: 2026-07-14

Branch: `codex/app-store-hardening-d`

Release boundary: branch-only implementation and isolated macOS validation.
No Xcode Cloud release is triggered in this round.

## Objective

Make the question bank behave like a trustworthy learning system instead of a
large list of nominally different ids. The round covers curriculum taxonomy,
difficulty, duplicate protection, answer-value diversity, answer-position
balance and repeatable release gates. The agreed range is junior-high
foundation and CAP preparation through an early high-school bridge.

The taxonomy follows the National Academy for Educational Research English
curriculum emphasis on communication, reading, writing, integrated language
use and logical interpretation. Questions remain original English+ content;
official CAP materials are a difficulty and task-design reference, not copied
question text.

References:

- <https://www.naer.edu.tw/PageSyllabus?fid=177>
- <https://cap.rcpet.edu.tw/>

## Baseline findings

- The seed contained 1,080 stable question ids but only 218 normalized core
  prompts after generated round labels were removed.
- Identical core prompts could carry different A1-B2 labels because difficulty
  was derived from the global item index instead of question content.
- Only seven broad skills were available, so teacher and student set selection
  could not reliably target concepts such as be-verb agreement, relative
  pronouns or main-idea reading.
- Source answer positions were heavily biased: 900 answers were in slot 1,
  90 in slot 2, 90 in slot 3 and none in slot 4.
- Translation generation produced fewer than four distinct choices for 180
  items.
- Runtime grouping de-duplicated ids, not learning prompts. A second id could
  therefore repeat the same question in a main set, repair set or segmented AI
  recommendation.

## Data contract

- Question schema is version 6 while all 1,080 ids and prompt/answer contracts
  remain stable for existing assignments and attempts.
- Difficulty and skill are now derived from question content. Repeated members
  of one semantic family must have one identical level, unit and skill.
- The bank now exposes 36 granular skills across six curriculum units and all
  four difficulty bands.
- B2 contains 110 early high-school bridge items; it is no longer assigned to
  elementary be-verb questions by index rotation.
- Every item has four normalized, distinct choices and its accepted answer is
  present.
- Committed source choices are exactly balanced: 270 correct answers in each
  of the four positions.
- The generator is deterministic and the validator compares its complete
  output with the committed JSON so manual drift cannot pass CI.

## Runtime grouping contract

- `semanticKey` removes generated round labels and normalizes prompt text.
- Every main, fallback, assignment, AI and repair set admits at most one item
  from a semantic family.
- Repair sets exclude the semantic keys of the entire suspended primary set,
  not only its ids.
- Correct-answer values are selected from the currently least-used answer
  bucket before secondary type, skill and level scoring. A be-verb set therefore
  balances `is` and `are` instead of clustering one value.
- A session rotation seed changes the candidate order without weakening any
  quality constraint. Daily missions use student/date/round; teacher assignments
  use student/set/time; voluntary sessions use a fresh local UUID.
- Runtime option ordering uses a seeded starting position followed by strict
  round-robin slots. A 12-question, four-choice session uses every slot exactly
  three times.
- All 46 generated curriculum sets remain reachable after filters; the old
  hidden 18-set cap was removed.

## Acceptance coverage

- `validate_app_store_hardening_round15.py` audits all 1,080 records, generator
  parity, 218 semantic families, taxonomy consistency, option validity, exact
  slot distribution, runtime source markers and CI wiring.
- Six Swift acceptance tests load the real bundled seed and verify taxonomy,
  source data, semantic de-duplication, answer-value balance, runtime option
  slots, repair isolation, rotation and finite set catalog behavior.
- Existing seed, practice fallback, teacher assignment, question grouping and
  runtime complexity validators were migrated to the stronger contract rather
  than retaining obsolete marker expectations.

## Verification evidence

- The complete local validator sweep passed `83/83`.
- Migration safety retained all 1,080 stable ids and changed no prompt,
  answer, accepted-answer, explanation, concept, repair-hint or question-type
  contract. Existing non-translation option sets also remained unchanged.
- The deterministic Round 15 validator confirmed 1,080 ids, 218 semantic
  prompts, 36 skills and exact source slots `{0: 270, 1: 270, 2: 270, 3: 270}`.
- Isolated macOS run `29307724360` compiled the complete test bundle and
  passed Swift `48/48`, including the six new question-quality acceptance
  tests, plus critical-role UI `5/5`.
- The same run passed Worker `34/34`, administrator portal `7/7` plus its
  production build, and Firestore Emulator `27/27`.
- The run completed without annotations and preserved the Xcode result
  artifact as `englishplus-xcresult-29307724360-1`.

Round 16 remains the next Xcode Cloud checkpoint. Round 15 stays on the
isolated hardening branch and must not merge to `main` by itself.
