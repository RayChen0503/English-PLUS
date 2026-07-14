# Round 17 - Student experience and information hierarchy

Status: Passed

Date: 2026-07-14

Branch: `codex/app-store-hardening-e`

Release boundary: this round is isolated from `main`. It does not trigger
Xcode Cloud. Rounds 17 through 20 will merge only after the complete Block E
audit passes.

## Goal

Make the student experience feel like one coherent learning journey for a new
student, a returning student, a personal-mode learner and a class member. The
screen should always explain the current state and offer one clear next action
without duplicating progress, navigation or support information.

## Implementation

- Rebuilt the home hierarchy around one contextual next action. Returning
  students choose either to continue the existing mission or deliberately
  start a fresh four-question check-in; both flows are no longer shown at the
  same time.
- Removed the duplicate learning-flow status card and the static free-practice
  card. Question progress is now shown only while an active mission or
  practice set is being answered.
- Made mission completion explicit and described free practice as optional.
  Restarting the daily check-in now requires confirmation so an accidental tap
  cannot discard the current route.
- Reordered the classroom experience so assigned work appears before class
  administration. Personal mode has one clear join-class entry point, while
  class mode shows task progress without exposing internal class identifiers.
- Added unread support and class-assignment badges to the persistent student
  tab bar. The support inbox no longer stacks a meaningless all-zero summary
  above its empty state.
- Moved AI practice recommendations ahead of the long manual filter controls,
  while preserving a deliberate manual selection path.
- Added stable accessibility identifiers to the affected home, practice,
  classroom, support and learning-map surfaces.
- Added a sixth critical UI journey that protects the one-primary-action home,
  optional free practice and simplified map contract.

## Behavioral acceptance

- A first-time student sees the four-question check-in and one start action.
- A returning student does not see continue and full check-in forms stacked
  together.
- A personal-mode student can learn normally without joining a class.
- A class member sees pending assignments before class settings and receives a
  badge only when work is actually pending.
- The learning map has no duplicate progress bar. Optional free practice and
  waiting-for-support states do not falsely block daily mission completion.
- Restarting a daily route is explicit and reversible until confirmation.

## Verification evidence

- The Round 17 contract validator, legacy learning-flow regressions and 13
  focused student regressions pass locally.
- The complete configured hardening validator sweep passes, including account,
  privacy, class, support, AI, question-bank and Block D preflight contracts.
- Python syntax compilation and `git diff --check` pass.
- GitHub Actions run `29323656069` validated commit
  `7d3e07d83da551ce053eebc2d1c088b4e3b55af3` on macOS with Xcode 16.4.
- The iOS Simulator test bundle compiled successfully; the complete Swift unit
  and integration step passed; all six critical role and student UI journeys
  passed; and the `.xcresult` diagnostic artifact was preserved.
- Every job step concluded successfully. No merge to `main` and no Xcode Cloud
  release build occurred.

