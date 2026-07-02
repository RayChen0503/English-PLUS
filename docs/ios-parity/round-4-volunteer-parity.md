# Round 4 Volunteer parity

This round keeps the volunteer workspace focused on one job: help a student pass one small breakpoint without exposing teacher-only management tools.

## Product reference

The volunteer side should be narrower than the teacher side:

- 今日: show the next student who needs human support.
- 接力: choose a waiting request, read the exact question context, generate or write a student-facing reply, then send it.
- 紀錄: keep previous volunteer replies visible for continuity.

The separated old tabs for 學生, 同步, and 腳本 were removed because they made the flow feel like a dashboard instead of a guided handoff.

## iOS changes

- `VolunteerShellView` now has three tabs: 今日, 接力, 紀錄.
- `VolunteerHandoffWorkspaceView` guides the volunteer through selection, breakpoint context, question snapshot, script, and reply composer.
- `VolunteerQuestionContextCard` shows `SupportQuestionSnapshotCard`, including the student's answer, correct answer, and explanation.
- `VolunteerReplyComposerCard` can ask AI for a draft, but the volunteer sends the final student-visible reply.
- `VolunteerRecordView` stores sent volunteer replies for continuity.
- `LearningRepositoryStore` exposes `volunteerDashboardMetrics` and `visibleVolunteerReplies` for the current volunteer queue.

## Current boundary

This is product-flow parity inside the prototype. True cross-device handoff depends on Firebase runtime configuration, deployed Firestore listeners, and real class membership data. The iOS app does not expose Firebase/Groq/debug setup text to end users.
