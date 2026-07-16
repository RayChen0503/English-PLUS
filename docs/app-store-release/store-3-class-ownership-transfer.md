# STORE-3 Teacher Account Deletion and Class Ownership

Decision A is implemented on the App Store release branch.

## Owner experience

- The deletion preview lists every class owned by the signed-in teacher.
- Each class shows only active co-teachers whose account is still an active
  teacher account.
- When eligible co-teachers exist, the owner confirms one successor per class.
- When none exists, the UI explains that the class will be archived while its
  retained history remains available under the deletion policy.
- A stale or removed successor stops deletion and requires a refreshed preview.

## Backend transaction

- The Worker revalidates the selected successor immediately before transfer.
- A transferred class keeps its students, assignments, support history, join
  configuration and active lifecycle state.
- `classes/{classId}.ownerTeacherUid` and
  `classAdmins/{classId}.ownerTeacherUid` change together.
- The deleting teacher's membership and identifying authored fields are still
  removed or redacted by the account-deletion lifecycle.
- A class is archived only when no eligible co-teacher exists. That fallback
  closes active work, revokes memberships and removes join codes as before.
- Transfer selections and per-class outcomes are stored only in the private
  backend deletion job so bounded retries cannot lose the owner's decision.

## Verification

- Worker account-deletion tests pass `10/10`.
- The complete Firestore Emulator suite passes `38/38`.
- Emulator coverage proves both the transfer path and archive-only fallback.
- The iOS model has acceptance coverage for classes with and without eligible
  successors.
- No deployment, push or Xcode Cloud run was performed in STORE-3.
