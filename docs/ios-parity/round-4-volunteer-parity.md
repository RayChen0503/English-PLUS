# Round 4 Volunteer parity

This round ports the Android volunteer handoff workspace into the iOS SwiftUI prototype.

## Android reference

Android volunteer flow separates the role from teacher management tools:

- 今日: assigned handoff work and the next student to support.
- 接力: students waiting for human support.
- 學生: only the necessary student context for accompaniment.
- 同步: saved collaboration and handoff records.
- 腳本: mentor scripts for low-pressure support.

## iOS changes

- `VolunteerShellView` now has five tabs: 今日, 接力, 學生, 同步, 腳本.
- `VolunteerHandoffView` focuses on the queue and the rule "只做下一小步".
- `VolunteerStudentBriefsView` shows only support-needed student context, not teacher-only management controls.
- `VolunteerSyncView` shows local handoff/reply records and the Firestore-ready sync boundary.
- `VolunteerScriptView` adds reusable support scripts through `VolunteerScriptTemplate`.
- `LearningRepositoryStore` now exposes `volunteerDashboardMetrics` and `visibleVolunteerReplies` for the volunteer dashboard.

## Current boundary

This is product-flow parity inside the prototype. True cross-device handoff still depends on Firebase runtime configuration and deployed Firestore listeners. The iOS app does not expose Firebase/OpenRouter/debug setup text to end users.
