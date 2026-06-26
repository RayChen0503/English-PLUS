# Round 5 - local persistence and sync boundary

## Purpose

Round 5 closes the gap between an in-memory prototype and a real app-ready data flow.
The iOS app now keeps the important learning state in a local persistence snapshot while
still preserving the Firestore-ready repository boundary.

This means the app can keep working before Firebase is fully connected, and the same
state shape can later be mirrored to Firestore.

## What is persisted locally

- check-in: the latest mood and learning preference check-in.
- daily mission: the generated daily mission, track, target correct count, and assigned questions.
- mission attempts: every answer attempt, including correctness, accepted answer, explanation, and repair hint.
- support requests: student help requests, teacher replies, volunteer replies, priority, and thread status.

## Implementation

- `LocalLearningSnapshot` is a Codable snapshot of the repository state.
- `UserDefaultsLearningPersistence` stores the snapshot under `englishplus.learning.snapshot.v1`.
- `MockLearningRepository` restores the snapshot on startup when it exists.
- Every state-changing path calls `persistSnapshot()` after mutation.
- The Firestore-ready path is preserved through `LearningRepositoryBackend`,
  `LearningRepositoryStore`, and `FirebaseLearningRepository`.

## User impact

- Students do not lose the current check-in, daily mission, mission progress, or support thread just because the app restarts.
- Teachers and volunteers keep seeing the current support queue in the local prototype.
- No user-facing screen exposes mock, Firebase, OpenRouter, or other technical state.

## Boundary

This is local persistence, not cross-device sync.
Cross-device sync still requires:

- `GoogleService-Info.plist`
- Firebase SDK products in Xcode
- deployed Firestore rules and indexes
- Firebase Auth sessions
- Cloud Functions deployment for AI proxy

The app is now safer to migrate because the local repository and the Firestore-ready repository share the same snapshot shape.
