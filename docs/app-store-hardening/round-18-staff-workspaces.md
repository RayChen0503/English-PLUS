# Round 18 - Teacher and volunteer workspaces

Status: Passed locally

Date: 2026-07-14

Branch: `codex/app-store-hardening-e`

Release boundary: this round remains isolated from `main`. It does not trigger
Xcode Cloud. Rounds 17 through 20 merge only after the complete Block E audit
passes.

## Goal

Make teacher and volunteer work feel like a focused queue of real actions,
instead of a long dashboard containing repeated question cards, reply fields
and explanatory copy. Both roles must share the same support interaction so
their behavior cannot drift apart again.

## Implementation

- Replaced inline response composers on teacher and volunteer home and handoff
  pages with compact, scannable queue rows.
- Added one shared request-detail flow for both roles. It reloads the current
  request from the repository, displays the complete question or human-support
  context, keeps shared reply history, and preserves role-specific reply and AI
  drafting commands.
- A successful response now has a visible synchronized confirmation. Archiving
  returns to the queue only after the repository operation succeeds.
- Kept high-priority, waiting and handled counts in the queue header, while
  removing duplicate summary panels from the main handoff path.
- Collapsed low-frequency teacher class controls under `班級設定與邀請`, while
  retaining the active class selector and daily student/assignment work in the
  main hierarchy.
- Limited the teacher home roster preview to four students so the home remains
  a prioritization surface rather than a second class-management screen.
- Collapsed full report text and volunteer record details until explicitly
  requested.
- Added stable accessibility identifiers for staff request detail, reply input,
  teacher class settings and report preview.
- Added a teacher UI regression journey and a dedicated Round 18 contract
  validator. The validator is part of the macOS hardening workflow.

## Behavioral acceptance

- A teacher or volunteer can scan the queue without scrolling past several
  full response forms.
- Selecting one request opens exactly one question and response workspace.
- Teacher and volunteer replies still call their correct repository methods,
  and both AI draft paths remain role-specific.
- Live repository updates are reflected while the detail page is open.
- Teacher class settings do not obscure student selection and assignment work.
- Report and record pages expose detail on demand instead of showing all text
  at once.

## Verification evidence

- `validate_app_store_hardening_round18.py` passes.
- The current Block D gate and Round 17 regression pass.
- FIX-E volunteer service-scope and the updated shared handoff regression pass.
- The full historical sweep was inspected. Remaining failures belong to legacy
  scripts that assert UI and transport contracts superseded by later signed-off
  rounds; no new failure remains in an affected current contract.
- `git diff --check` passes.
- iOS compilation and UI execution require the macOS CI runner and will be
  performed before Block E is merged.
