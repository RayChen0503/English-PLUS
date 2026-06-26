# Round 6 - report/export parity

## Purpose

Round 6 turns the teacher report tab from a static prototype surface into a real
classroom report/export flow.

The goal is not to pretend that the iOS app already has a full school dashboard.
The goal is to give teachers a useful classroom report they can read, preview, and
share during TestFlight or classroom demo sessions.

## What changed

- Added `ClassroomReportExport` as the report data model.
- Added report metric, priority student, and question-bank row models.
- Added `LearningRepositoryStore.classroomReportExport`.
- The report uses current repository data:
  - high-risk student count
  - waiting support request count
  - replied support count
  - average mood text
  - top priority students
  - question-bank type and level coverage
  - recommended next actions
- Replaced the disabled teacher report button with a real `ShareLink`.
- Added a report preview card so teachers can inspect content before sharing.

## User-facing behavior

Teacher report tab now shows:

1. classroom status metrics
2. priority students
3. question-bank status
4. recommended next actions
5. a share action
6. a plain report preview

The wording avoids ranking pressure and focuses on support evidence, task progress,
and what the teacher can do next.

## Export format

The current export is prototype-level:

- `shareText`: plain text / Markdown-style classroom report for iOS sharing.
- `htmlBody`: simple HTML report body for a future print/PDF path.

Formal PDF and Word output should still be handled by a backend or teacher dashboard
when the project moves beyond prototype distribution.

## Boundary

This round does not add:

- official PDF generation inside the iOS app
- official Word generation inside the iOS app
- school backend report archive
- App Store Connect metadata changes

Those are production tasks. This round completes the in-app report/export parity needed
for a credible iOS prototype.
