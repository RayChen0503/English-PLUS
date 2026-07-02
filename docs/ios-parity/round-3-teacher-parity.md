# Round 3 Teacher parity

This round keeps the teacher workspace aligned with the current English+ product flow.

## Product reference

The teacher side should not feel like a raw question-bank browser. It should help a teacher answer three questions quickly:

- 今日: who needs help first?
- 學生: what is each student's current breakpoint, mood, and mission state?
- 接力: which help requests need a human response?
- 報告: what happened this week and what evidence can be shared?
- 班級: which student should receive a small, targeted practice set?

## iOS changes

- `TeacherShellView` uses five tabs: 今日, 學生, 接力, 報告, 班級.
- The old standalone `題庫` tab is intentionally removed.
- `TeacherClassAssignmentView` replaces the raw question-bank center with a class assignment workspace.
- Teachers first choose a student, review risk/progress context, then assign a small practice set.
- Practice sets are grouped by type, level, and skill, with each set capped to a short task size.
- `TeacherRequestCard` shows the exact question snapshot when a student asks for help, so teacher replies are tied to the student's answer and the correct explanation.
- `LearningRepositoryStore` exposes dashboard metrics, class report data, question-bank summaries, and assignment lookup APIs.

## Current boundary

This is product-flow parity inside the prototype. Runtime Firebase and cross-device sync remain behind the existing Firebase-ready service boundary until `GoogleService-Info.plist`, Firebase SDK products, deployed rules/functions, and real class membership data are active.
