# Round 11 - account deletion, retention and explicit human help

Status: Implementation and live user-path verification complete. The scheduled
crash-recovery path still needs one Firebase IAM role before final sign-off.

## Product contract

Round 11 implements decisions D-19 and D-20 as user-visible behavior rather
than policy-only text:

1. A signed-in user can inspect the impact of account deletion, type a clear
   destructive confirmation, confirm once more, and permanently remove the
   account.
2. Identifiable profile, learning, mood, assignment, support, evidence and
   authentication data are removed. Only monthly counters that contain no UID
   or recoverable personal dimension remain.
3. Authentication is removed last. A retryable, backend-only job records the
   minimum state required to resume interrupted cleanup.
4. A low mood does not silently notify teachers or volunteers. The student
   chooses whether to send an explicit human-help request, and the app clearly
   identifies 1925, 113 and 119 without claiming that English+ monitors an
   emergency channel.

## Account deletion workflow

- `GET /account/deletion-preview` returns counts and policy effects, never raw
  Firestore paths.
- `DELETE /account` requires a current policy version, the literal server-side
  confirmation and a Firebase session authenticated within ten minutes.
- Cleanup is staged across bounded requests: legacy support messages, classes
  owned by a deleting teacher, the deleting student's class-scoped records,
  then the final personal-data pass. This design stays below the Cloudflare
  free-plan external-subrequest limit for real multi-class accounts.
- Teacher-owned classes are archived, open work is stopped, other members lose
  that class membership and historical class reporting remains available.
- Staff messages and assignment authorship that must remain meaningful to
  another user are redacted to a deleted-account identity rather than leaving
  the former person's UID or name behind.
- Volunteer evidence objects are removed from private R2 before Firebase Auth
  is deleted.
- The iOS client polls bounded cleanup responses, respects `Retry-After`, blocks
  accidental sheet dismissal while deletion is running, clears every local
  UID scope, then signs out only after a completed receipt.

## Human-help workflow

- Mood check-in still adapts the student's mission, but is never converted into
  an automatic teacher or volunteer alert.
- A student who selects a low mood sees one calm human-help card. Sending is an
  explicit, confirmed action and duplicate open requests are prevented.
- Teacher and volunteer queues include only a complete question snapshot or a
  student-authored emotional-support request. Empty or inferred alerts do not
  create a badge.
- Staff dashboards use `優先回覆`, not medical or crisis-risk labels. The AI
  contract forces `staffEscalationNeeded` to `false` and cannot claim that a
  person was notified.
- Immediate-danger copy directs the student to a nearby trusted adult or 119;
  1925 and 113 are available as direct links. English+ is explicitly not
  presented as an emergency service.

## Security and data boundaries

- `accountDeletionJobs` and `anonymousProductMetrics` deny all client reads and
  writes in Firestore Rules.
- Job writes use document preconditions, so concurrent retries cannot silently
  overwrite each other.
- New support-message documents carry class, student and context-version fields
  so deletion can use indexed collection-group queries. Legacy threads are
  upgraded while their nested messages are removed.
- The normal authenticated deletion path uses the deleting user's Firebase ID
  token and never sends a Firebase API key from iOS. The API key remains a
  Cloudflare secret.
- The scheduled recovery fallback uses the Worker service account only when a
  client disappears after cleanup has begun. It requires the Firebase
  Authentication Admin permission before final sign-off.

## Verification evidence

- Worker syntax check and Node-compatible Vitest suite pass `22/22`, including
  destructive confirmation, recent authentication, anonymous-only metrics,
  job preconditions, staged large-account queues and forced no-auto-escalation.
- Firestore Rules and indexes are deployed. The isolated Emulator suite passes
  `18/18`, including a staged teacher deletion with an owned class, another
  class member, nested learning data, legacy support messages and an authored
  assignment.
- Production Firebase smoke testing has verified student, teacher and volunteer
  deletion previews and a complete temporary-user deletion: the profile was
  removed, re-login failed, and only the anonymous receipt contract remained.
- Deployed Worker version `c4cf2872-26ca-4829-90a2-66102a055eb4` passes the
  production suite `46/46`; the real deletion completed in two bounded requests.
- The complete repository validator sweep passes `71/71`, and Functions
  TypeScript compilation succeeds.
- A branch-only macOS compile gate validates the new Swift source and Xcode
  project without merging `main`.
- No Xcode Cloud or TestFlight release is triggered in Round 11. Block C ships
  only after Round 12 and the four-round checkpoint audit.

## Remaining sign-off action

Grant the Cloudflare Firebase service account permission to delete Firebase
Authentication users during scheduled recovery, then verify the pending-job
retry and remove the two diagnostic accounts left by earlier intentionally
failed tests. The everyday in-app deletion path already passes end to end; this
last action closes the crash-after-cleanup recovery case.
