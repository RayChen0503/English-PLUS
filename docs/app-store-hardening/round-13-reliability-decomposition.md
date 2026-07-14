# Round 13 - Reliability and repository decomposition

Status: Implementation complete; isolated macOS gate pending

Date: 2026-07-14

Branch: `codex/app-store-hardening-d`

Release boundary: branch-only implementation and macOS validation. No Xcode Cloud
release is triggered in this round.

## Objective

Make synchronization failure an explicit, recoverable product state while
reducing the responsibility carried by `LearningRepositoryStore.swift`.
Previously a listener error only stored a raw error description, offered no
retry action, and could be overwritten by a later start call. Reporting,
learning state, support actions and synchronization also lived in one file.

## Product behavior

- Student, teacher and volunteer screens continue showing the last local
  snapshot when the network is unavailable.
- A shared top banner distinguishes connecting, retrying and offline states.
- Offline copy describes what the user can do and never exposes Firebase or
  technical error text.
- The banner includes a deliberate Retry action and the last successful sync
  time when one exists.
- Network restoration restarts the active role/class listener automatically.
- Listener failures use bounded automatic backoff. Repeated root rendering for
  the same account and class does not restart a healthy listener.
- Signing out, switching away from Home, erasing local data or stopping sync
  cancels pending retries.

## Architecture

- `LearningRepositoryConnectivity.swift` owns the injectable `NWPathMonitor`
  boundary.
- `LearningRepositoryContracts.swift` owns snapshots, backend protocols and
  synchronization contracts without runtime state.
- `LearningRepositoryStore.swift` owns runtime state, listener lifecycle and
  retry coordination.
- `LearningRepositoryStore+Reporting.swift` owns dashboard, queue and report
  projections. This keeps reporting reads independent from mutation and
  synchronization control.
- `RepositorySyncBanner.swift` is one adaptive SwiftUI recovery component used
  above every role shell.

The retry schedule is capped at 1, 2, 5 and 10 seconds. The final delay may be
reused while a persistent failure remains; Firestore's own listener recovery
continues to work, and the application does not discard the local snapshot.

## Regression coverage

Swift acceptance tests cover:

1. disconnect, local fallback and automatic reconnect;
2. listener failure followed by automatic backoff recovery;
3. cancellation of a pending retry after sync stops;
4. idempotent starts for the same account/class scope.

The Round 13 validator also verifies Xcode source membership, user-safe copy,
the separated reporting boundary and the isolated macOS workflow gate. Prior
Round 5-12 and FIX-A-G contracts remain part of the same gate.

## Acceptance result

- Local Round 13 validator: passed.
- Full Python contract sweep: `81/81` passed.
- Worker Node-compatible tests: `24/24` passed; Functions TypeScript build and
  administrator portal tests `7/7` passed. The Windows Workers-pool runtime and
  Vite production bundle are rechecked by the authoritative Node 22 macOS gate.
- Firestore Emulator permission and lifecycle matrix: `27/27` passed.
- Xcode 16.4 Simulator build and Swift tests: pending isolated macOS gate.

These evidence lines are updated only after the corresponding commands pass.
