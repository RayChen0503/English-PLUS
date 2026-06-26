# Round 3 Teacher parity

This round ports the Android teacher workspace shape into the iOS SwiftUI prototype.

## Android reference

Android teacher flow exposes five primary work areas:

- 今日: class risk, priority student, and next action.
- 學生: student records, current breakpoint, mood, and mission status.
- 接力: handoff priority and student help queue.
- 報告: weekly class support summary and evidence.
- 題庫: question bank level/type overview.

## iOS changes

- `TeacherShellView` now has five tabs: 今日, 學生, 接力, 報告, 題庫.
- `TeacherHandoffView` replaces the narrower request-only view with a handoff-priority screen.
- `TeacherReportView` adds a class weekly report surface with support evidence and teacher-facing summary.
- `TeacherQuestionBankView` adds a question-bank center grouped by type and level.
- `LearningRepositoryStore` now exposes `staffDashboardMetrics` and `questionBankOverview`, so teacher UI uses repository state instead of hard-coded display counts.

## Current boundary

This is parity for the in-app product prototype. Runtime Firebase and cross-device sync remain behind the existing Firebase-ready service boundary until `GoogleService-Info.plist`, Firebase SDK products, deployed rules/functions, and real class membership data are added.
