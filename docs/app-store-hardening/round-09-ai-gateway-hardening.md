# Round 9 - authenticated AI gateway, quota and monitoring

Status: Source and production gateway complete; isolated macOS compile pending.

## Decision A

Internal testing stays deliberately generous while the public policy is ready
to be enabled by changing one server-side variable. Internal mode permits 180
weighted AI units per Firebase user per Taipei day and 30 requests per minute.
Public mode permits 60 weighted units and 8 requests per minute. Both policies
are enforced on the Worker; the iOS client cannot select or bypass them.

## Defects found and corrected

1. A valid Firebase user could previously request an AI task belonging to a
   different role. The gateway now has a least-privilege student, teacher and
   volunteer task matrix.
2. The client previously supplied `studentUid`, `classId` and `qualityMode`
   without a server-owned authorization decision. The Worker now verifies the
   active profile, class membership, target student and support thread, and it
   chooses model quality on the server.
3. AI calls had no per-user budget. A SQLite Durable Object now performs an
   atomic, retry-safe daily reservation before Groq is called; Cloudflare Rate
   Limiting bindings provide a separate burst boundary.
4. Daily quota initially reset at UTC midnight. It now resets at Taipei midnight,
   which matches the product's current users.
5. Provider timeouts and quota failures were flattened into generic HTTP
   errors on iOS. The transport now retains the Worker error category, Retry-
   After value and correlated request ID, while role-facing UI shows clear
   non-technical fallback guidance.
6. Operational logs were not structured for incident triage. AI outcomes now
   record a request ID, hashed actor, role, task, quota outcome, provider status,
   token totals and latency without logging prompts, answers, names, class IDs
   or raw Firebase UIDs.

## Authorization contract

Every AI request starts with verified Firebase identity and an active account
profile before role, class and target-resource authorization is evaluated.

| Role | Allowed AI tasks |
| --- | --- |
| Student | Daily mission, wrong-answer explanation, emotional support, practice recommendation |
| Teacher | Teacher feedback draft for a visible support thread in the selected class |
| Volunteer | Volunteer reply coaching for an assigned, visible support thread |

Personal AI scope is available only to the authenticated student who owns that
scope. Class AI requires an active membership. Staff tasks require an active
target student and a real, visible support thread; withdrawn or archived
threads are rejected.

## Quota contract

- Daily mission: 4 units.
- Wrong-answer explanation: 2 units.
- Emotional support: 2 units.
- Practice recommendation: 3 units.
- Teacher or volunteer quality assistance: 6 units.
- Duplicate request IDs do not consume a second reservation.
- Replayed request IDs are rejected before Groq is called, so idempotency
  cannot be abused to bypass the daily provider budget.
- The local fallback remains available after a limit or provider failure, so a
  student is never blocked from continuing the learning flow.

## Verification evidence

- Cloudflare Workers runtime: 15/15 Vitest checks passed, including real
  Durable Object persistence and both Rate Limiting bindings.
- Wrangler syntax and deployment dry-run passed with every expected binding.
- Production Worker version:
  `cf6dfb11-0644-4680-9fb9-f66e86e26996`.
- Authenticated production smoke suite: 34/34 passed using the real Firebase
  student, teacher and volunteer test accounts.
- Groq returned real non-fallback responses in both class and personal mode.
- Role forgery, student identity forgery, cross-role AI tasks, unauthenticated
  quota reads and client-side quality escalation were rejected.
- Request IDs matched between the response header and response body.
- No Xcode Cloud or TestFlight release was triggered in Round 9. The work stays
  on `codex/app-store-hardening-c` until the Block C checkpoint after Round 12.

## Remaining gate

The isolated GitHub macOS Simulator compile will verify the iOS transport and
user-facing fallback changes. Round 9 is complete only after that gate passes
and this report records the run.
