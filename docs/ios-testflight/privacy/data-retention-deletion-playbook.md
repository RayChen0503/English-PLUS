# English+ Data Retention And Deletion Playbook

This playbook translates the Round 6 privacy decisions into implementable product behavior.

## Retention Rule

Recommended rule:

```text
Keep identifiable student data while the account, class, school project, or learning-support purpose is active. Review retention once per school year. When the class/project ends, delete or de-identify records unless continued retention is documented and approved.
```

Do not describe retention as unconditional permanent storage.

## Data States

| State | Meaning | Visible To Student | Visible To Teacher | Visible To Volunteer | Backend |
| --- | --- | --- | --- | --- | --- |
| active | normal usable data | yes if own | yes if assigned | yes if assigned | yes |
| hiddenPendingReview | hidden after deletion request | limited | yes | no by default | yes |
| deletedContent | body removed, audit shell kept | no | limited | no | yes |
| deleted | document removed | no | no | no | no |
| deidentified | no direct identity link | no personal view | aggregate only | no | analytics only |

## Firestore Collections To Add Later

```text
users/{uid}/consents/{consentVersion}
classes/{classId}/students/{studentUid}/consents/{consentVersion}
classes/{classId}/students/{studentUid}/deletionRequests/{requestId}
classes/{classId}/privacyAuditLogs/{eventId}
classes/{classId}/retentionReviews/{reviewId}
```

## Deletion Request Shape

```json
{
  "requestId": "uuid",
  "studentUid": "firebase-auth-uid",
  "classId": "YILAN-CHENGZHI-8A",
  "requestType": "deleteMoodCheckIn",
  "targetPath": "classes/YILAN-CHENGZHI-8A/students/studentUid/checkIns/2026-06-10",
  "reason": "I do not want to keep this mood check-in.",
  "status": "pending",
  "createdByUid": "studentUid",
  "createdAt": "serverTimestamp",
  "reviewedByUid": null,
  "reviewedAt": null,
  "resolution": null
}
```

Allowed `requestType` values:

- `deleteMoodCheckIn`
- `deleteSupportMessage`
- `correctProfile`
- `deleteAccount`
- `stopProcessing`
- `exportCopy`

## Deletion Processing Flow

1. Student submits request.
2. App immediately marks target data as `hiddenPendingReview` if safe.
3. Teacher/admin receives request.
4. Teacher/admin approves, rejects with reason, or asks student for clarification.
5. Backend performs deletion, soft deletion, or de-identification.
6. Backend writes privacy audit log.
7. Student sees completion state.

## Privacy Audit Log Shape

```json
{
  "eventId": "uuid",
  "eventType": "deletionApproved",
  "actorUid": "teacher-or-admin-uid",
  "actorRole": "teacher",
  "studentUid": "studentUid",
  "classId": "YILAN-CHENGZHI-8A",
  "targetPath": "classes/YILAN-CHENGZHI-8A/students/studentUid/checkIns/2026-06-10",
  "createdAt": "serverTimestamp",
  "note": "Mood check-in deleted at student request."
}
```

Do not store the deleted sensitive body inside the audit log.

## Annual Retention Review

Each school year, create:

```json
{
  "reviewId": "2026-YILAN-CHENGZHI-8A",
  "classId": "YILAN-CHENGZHI-8A",
  "status": "pending",
  "reviewedByUid": null,
  "studentCount": 0,
  "action": "delete-or-deidentify-ended-class-records",
  "createdAt": "serverTimestamp",
  "completedAt": null
}
```

Review checklist:

- Is the class still active?
- Are students still using English+?
- Does the school/project still need identifiable records?
- Can old records be de-identified?
- Are deletion requests unresolved?

## AI Data Deletion

When a student deletes a mood check-in or support thread:

- Delete or de-identify linked AI summaries if they reveal the deleted content.
- Keep only minimal usage counters if needed for abuse prevention.
- Do not keep raw prompts containing sensitive student text.

## Admin Safeguards

Before deleting a full account:

- Confirm student identity.
- Confirm school/project policy.
- Export a copy if the student requests it.
- Delete Auth account only after Firestore data handling is decided.
- Write an audit log that does not expose sensitive content.

## Product Copy For Completed Deletion

```text
已完成刪除。這筆資料不會再出現在你的學習紀錄或老師/志工工作台中。
```

For rejected requests:

```text
這次申請尚未完成。請找老師或專案負責人確認原因。
```
