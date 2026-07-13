# FIX-E volunteer service scope

Date: 2026-07-14
Decision: FIX-E C, teacher-controlled class invitation and approval

## Problem

Volunteer qualification review existed, but an approved volunteer had no
product flow for joining a service scope. The volunteer UI could therefore
show local or legacy queue data without explaining which students the
volunteer was authorized to support. Opening every student to every approved
volunteer would be an unacceptable privacy boundary.

## Product flow

1. Platform review approves a volunteer's eligibility. No class data is
   available yet.
2. A class owner creates a dedicated volunteer invitation code. It is separate
   from the student join code and either code cannot be used in the other flow.
3. The volunteer submits the code. The request remains pending and exposes no
   student data. The volunteer may withdraw the request before approval.
4. The owning teacher approves or rejects the request from the class screen.
5. Approval atomically creates the class member record and the volunteer's
   membership mirror. The volunteer then selects that class from `服務班級`.
6. The volunteer can read only student-initiated support threads in the
   selected class. The class roster, complete learning timeline, assignments,
   and student mood profile remain unavailable.
7. Volunteer leave, teacher removal, or class deletion updates both membership
   records and immediately removes support access, notifications, and the
   active-class selection.
8. The volunteer's service list and the teacher's request list use Firestore
   listeners, so submit, approve, reject, withdraw, remove, and leave changes
   appear across devices without reopening the screen.

## Data contract

- Private code mapping: `volunteerJoinCodes/{code}`
- Teacher-owned request: `classes/{classId}/volunteerRequests/{volunteerUid}`
- Volunteer mirror: `users/{uid}/volunteerServices/{classId}`
- Active authorization: `classes/{classId}/members/{uid}` with role
  `volunteer`
- User membership mirror: `users/{uid}/classMemberships/{classId}`

All consequential mutations are authenticated Worker operations. Firestore
clients can read only their own service record or, for the class owner, the
class request list. Clients cannot create or approve service membership.

## Acceptance requirements

- Pending and rejected volunteers cannot read the class or support threads.
- An approved class volunteer can read actionable support threads in that
  class, but cannot read the roster or student profile.
- A volunteer cannot access another class.
- Removing or leaving a volunteer revokes access without requiring an app
  restart.
- Withdrawing a pending request never creates a class membership and removes
  it from the teacher's pending queue in realtime.
- Deleting a class invalidates both student and volunteer codes and closes all
  active volunteer memberships.
- Volunteer UI has a real class tab, clear empty/pending states, class switch,
  and leave confirmation.
- Teacher UI has a dedicated volunteer code, pending approvals, active service
  list, and destructive removal confirmation.
