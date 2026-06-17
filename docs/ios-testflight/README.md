# English+ iOS / TestFlight Migration

This folder is the handoff bridge from the current Android prototype to the future native iOS / TestFlight prototype.

The Android app remains the working classroom prototype. The iOS work should start from these documents when the project moves to a Mac with Xcode.

## Current Direction

- Target platform: native iOS with SwiftUI.
- Distribution target: TestFlight first, not public App Store release yet.
- Product scope: student, teacher, and volunteer tracks.
- Login and data backend: Firebase Auth and Firestore.
- AI route: OpenRouter through a backend proxy. The iOS app must not hold the production API key.
- Question bank: reuse the current English+ Android question bank and convert it into an iOS-readable seed/data format.
- Brand: keep the current English+ identity and learning-support direction.

## Round Documents

1. `round-1-migration-master-spec.md`  
   Overall migration goal, fixed decisions, target scope, risk boundaries, and Mac handoff direction.
2. `round-2-swiftui-screen-map.md`
   SwiftUI screen map, role-separated user flows, proposed view files, navigation rules, and UX quality gates.
3. `round-3-ios-data-format-spec.md`
   Android-to-iOS data contracts for roles, accounts, question bank, check-in, daily missions, support threads, staff assignments, and sync.
4. `round-3-ios-seed-implementation-check.md`
   Mac/Xcode implementation check for bundled iOS seed JSON, Swift Codable models, seed validation, and simulator build/run verification.
5. `round-4-firebase-auth-firestore-schema.md`
   Firebase Auth strategy, confirmed Firebase/iOS identifiers, Firestore collection schema, role permissions, backend proxy boundary, and setup order.
6. `round-4-ios-backend-implementation-check.md`
   iOS implementation check for Firebase constants, Firestore path builders, Swift document models, seed-to-Firestore mapping, config safety, and simulator build/run verification.
7. `firebase/firestore.rules.draft`
   Draft Firestore security rules for student, teacher, and volunteer access control.
8. `firebase/firestore.indexes.draft.json`
   Draft Firestore composite indexes for support, assignment, student, question-bank, and answer-event queries.
9. `round-5-openrouter-cloud-functions-proxy.md`
   OpenRouter AI proxy contract using Firebase Cloud Functions, including model strategy, privacy boundaries, rate limits, and Mac setup order.
10. `round-5-ai-proxy-implementation-check.md`
   Implementation check for the Firebase Functions scaffold, iOS AI proxy models, local fallback service, GitHub question-bank boundary, secret safety, and build verification.
11. `firebase/openrouter-ai-proxy.example.ts`
   TypeScript reference implementation for the future callable AI proxy.
12. `firebase/openrouter-ai-proxy.schema.json`
   Request contract schema for iOS-to-backend AI calls.
13. `firebase/openrouter-ai-proxy.secret.local.example`
   Local emulator secret example for the OpenRouter API key.
14. `round-6-privacy-real-student-data-checklist.md`
   Privacy and real-student-data checklist covering names, class/school/grade, mood visibility, consent, retention, deletion, role visibility, AI minimization, and TestFlight privacy risk.
15. `round-6-firebase-auth-privacy-implementation-check.md`
   Implementation check for AuthService, FirestoreService, replaceable Firebase boundary, consent flow, privacy paths, rules coverage, and simulator verification.
16. `windows-handoff-rounds-1-6-completion-audit.md`
   Audit against the Windows handoff log's Round 1-6 definitions, including student flow, staff support, seed data, local repository, Firebase boundary, and validation status.
17. `round-7-ai-service-implementation-check.md`
   Implementation check for the high-level AIService boundary, MockAIService, RemoteAIService, Cloud Functions proxy route, AI use cases, and OpenRouter key safety.
18. `round-8-testflight-preparation-check.md`
   Implementation check for TestFlight signing/team/bundle preparation, archive/upload boundary, tester information, tester email flow, and internal beta notes.
19. `windows-handoff-rounds-1-8-final-audit.md`
   Final audit against the Windows handoff log's Round 1-8 definitions, including known external Apple account blockers.
20. `privacy/consent-copy-draft.md`
   Student, teacher, and volunteer consent copy drafts for the future iOS app.
21. `privacy/data-retention-deletion-playbook.md`
   Retention, deletion, de-identification, and privacy audit workflow draft.
22. `privacy/app-privacy-label-draft.md`
   App Store Connect / TestFlight privacy label preparation draft.
23. `round-8-xcode-development-handoff.md`
   Detailed Mac/Xcode handoff guide for the teammate building the SwiftUI iOS prototype with GitHub Desktop, main branch workflow, Firebase setup path, and first local prototype scope.
24. `testflight/app-store-connect-test-info.md`
   App Store Connect setup notes, internal test groups, tester email collection fields, and beta review notes.
25. `testflight/tester-email-template.md`
   Traditional Chinese email template for inviting internal TestFlight testers and collecting useful feedback.
26. `testflight/internal-build-release-notes.md`
   Internal beta build notes for `1.0 (1)`, including test focus and known mock/backend boundaries.
27. `xcode-handoff/github-desktop-main-workflow.md`
   Step-by-step GitHub Desktop workflow for cloning, committing, pushing, and avoiding fork/conflict mistakes on `main`.
28. `xcode-handoff/firebase-ios-setup-for-teammate.md`
   Firebase iOS setup guide for `tw.edu.englishplus`, including `GoogleService-Info.plist` and Swift Package Manager steps.
29. `xcode-handoff/swiftui-starter-map.md`
   Compact SwiftUI file/screen/component map for the first iOS build.
30. `handoff/EnglishPlus_iOS_Mac_Teammate_Handoff.pdf`
   Polished PDF handoff manual for the Mac teammate, covering current status, how to read the migration docs, Xcode steps, GitHub Desktop workflow, Firebase setup path, and TestFlight timing.
31. `handoff/EnglishPlus_iOS_Mac_Teammate_Handoff.docx`
   Editable source version of the teammate handoff manual.

The Windows handoff log's eight rounds are now represented in this repo.

## How To Continue On Mac

After these migration documents are pushed to GitHub, continue on the Mac by cloning or pulling the repository:

```bash
git clone https://github.com/RayChen0503/English-PLUS.git
```

If the repository already exists on the Mac:

```bash
git pull
```

Then start from this folder and follow the Xcode handoff and TestFlight preparation documents.
