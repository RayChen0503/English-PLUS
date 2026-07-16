# Private support moderation and user safety

English+ support messages are class-scoped, asynchronous learning records rather
than a public feed. They still contain user-generated text, so the release must
ship a complete safety loop instead of relying only on classroom membership.

## Student controls

- A student can report an individual teacher or volunteer reply.
- A student can block the reply author. The selected reply disappears
  immediately, and later replies from that author are filtered for that student.
- Reports retain the thread, question and reply identifiers needed for review;
  the client cannot forge a different student or edit moderation fields.

## Administrator workflow

1. An authenticated administrator opens the private `內容檢舉` workspace.
2. The queue can be searched and filtered by `open`, `reviewing`, `resolved` or
   `dismissed` status.
3. Starting, resolving or dismissing a case requires a moderation note.
4. Each transition checks the current document version to prevent overwriting a
   second administrator's decision.
5. The report receives moderator UID, email, timestamp and note; a separate
   `moderationEvents` document preserves the decision trail.

The administrator queue never exposes reports to students, teachers or
volunteers. Blocking is student-specific and does not automatically suspend a
staff account; account-level action remains a deliberate administrator decision.

## Release evidence

- `scripts/validate_app_store_ugc_safety.py`
- `workers/englishplus-ai-proxy/test/admin-review.test.js`
- `firebase-tests/test/fix-a-support-sync.test.js`
- administrator portal API and production build tests
- final real-device report, block and moderation smoke test
