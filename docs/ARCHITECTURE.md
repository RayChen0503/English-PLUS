# Architecture and development

- Product client: `ios/EnglishPlus` (SwiftUI; display name English+; bundle ID `com.englishplus`).
- Runtime services: `workers/englishplus-ai-proxy/` handles AI, classroom lifecycle, volunteer review, evidence and account deletion. `admin-web/` is the administrator client; `firebase-tests/` exercises rules and backend contracts in the emulator. `functions/` is an archived Firebase Functions implementation, not the current iOS AI route.
- Historical prototype: `app/`; do not treat it as current iOS release code unless the task explicitly targets Android.

The client must not contain an AI-provider key. AI goes through `englishplus-ai-proxy` and its server-side secret. Use component-local README files only when working in that component; keep cross-cutting decisions in `docs/`.

## State and persistence conventions

- Capture the session and class generation before asynchronous work. A UID or class ID alone cannot distinguish logout/login with the same account or an A → B → A class switch. Validate the generation before applying results, errors, navigation or cleanup to the current UI.
- `AppState` owns authentication, consent and membership transitions. `LearningRepositoryStore` owns learning presentation and sync status; the backend owns listener cancellation, snapshots and writes. Listener callbacks must be invalidated before they mutate either the live snapshot or its local fallback.
- Keep local learning progress available offline. Display queued writes separately from confirmed writes; preserve failed operations for explicit retry. Changes from one learning operation belong in one Firestore batch. A create-only `users/{uid}/learningWriteReceipts/{operationId}` in that same batch prevents an acknowledged operation from being applied again after a crash. Receipts remain until account deletion; a failed earlier operation must not be replayed after a newer one succeeds.
- Persist the original answer input with a queued mastery projection. After a failed commit, only a successful server read proving the receipt is absent permits rebuilding that projection over newer server mastery. Keep the same operation ID and limit automatic rebase to one attempt; a server-read failure preserves the original pending operation. New missions and answer events use independent UUIDs so two devices do not collide on a date, round or local attempt number.
- Persist private drafts under the owning UID. Account deletion must clear every UID-scoped draft, review notice and pending-write journal, including inactive class scopes.
- Restart date-bound queries when the calendar day changes or the app becomes active on a new day. Preserve the explicit choice to continue an earlier mission.
- Administrator requests belong to a session and a request generation. Store modal input independently of DOM rendering, and bind a review to the captured application/report version.

## Evidence lifecycle

Successful uploads are journaled immediately so a form interruption does not lose their references. Unreferenced completed uploads have a 30-day recovery window. Cleanup claims the Firestore document version and records exact `retiredEvidenceKeys` before deleting objects; rules reject new references to retired keys. Reviewed-file cleanup uses R2 upload timestamps to preserve files added for a later submission. Ownership transfer and each classroom member's exit also use atomic writes with document preconditions.

When releasing these lifecycle changes, deploy the matching Firestore rules before the Worker, then release the client. Local emulator verification does not establish that those services or the installed iOS app have been updated.
