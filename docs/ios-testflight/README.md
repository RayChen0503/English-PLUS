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

Future rounds will add:

- Firebase Auth / Firestore schema and security-rule draft.
- OpenRouter backend proxy contract.
- Android question bank and support-flow export format.
- TestFlight preparation checklist.
- Privacy and real-student-data checklist.
- Xcode build and upload handoff steps.

## How To Continue On Mac

After these migration documents are pushed to GitHub, continue on the Mac by cloning or pulling the repository:

```bash
git clone https://github.com/RayChen0503/English-PLUS.git
```

If the repository already exists on the Mac:

```bash
git pull
```

Then start from this folder and follow the Xcode handoff document once it exists.
