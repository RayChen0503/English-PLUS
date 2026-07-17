# RELEASE-3 App Review Accounts and Deterministic Seed

## Scope

RELEASE-3 provisions three fictional App Review accounts in
`englishplus-production`. It does not read, write or deploy the competition
Firebase project, Worker, R2 bucket, public TestFlight group, build 53 or public
link. This round does not push the Git branch and does not trigger Xcode Cloud.

## Review experience

- Student reviewer: accepted current privacy consent, active membership in
  `APP-REVIEW-CLASS`, one pending five-question assignment, one completed answer
  and mastery record, one pending support request and one unread staff reply.
- Teacher reviewer: active teacher profile, owns the review class, sees the
  fictional student, may inspect the assignment and answer the pending request.
- Volunteer reviewer: approved application with no real evidence, active service
  authorization for the review class and access only to student-submitted support.
- Production administrator: remains `englishplus.tw@gmail.com`; this is separate
  from the three role sign-ins supplied to App Review.

## Private credential boundary

The provisioning source contains account emails but no passwords. On first
apply it generates three unique random passwords in a local file outside the Git
repository. No password is printed, committed, placed in Review Notes source or
passed on a command line. The same private file makes the seed rerunnable and is
the only source used when credentials are entered manually in App Store Connect.

## Reset and verification

The apply operation deletes and recreates only the fixed review class and the
three dedicated review-user document trees. It never queries or deletes ordinary
production users. Firebase Authentication user IDs remain stable. Verification
checks all required Firestore paths, all three Email/password sign-ins and all
three authenticated production Worker classroom responses.

The live verification additionally proves that the student can read the assigned
task and the staff reply, the teacher can read the classroom roster and pending
support request, and the volunteer can read only the authorized service scope and
student-submitted request. Negative checks confirm that a student cannot read the
class administration document and a volunteer cannot read the student's full
class summary. The production administrator claim and production Hosting endpoint
are also verified.

Two consecutive live apply-and-verify runs passed against
`englishplus-production`. This confirms that the fixed review scope can be reset
without changing ordinary production users or creating duplicate Auth accounts.

The final regression also passed RELEASE-0 through RELEASE-3 validators, the
release polish validator, the Firebase Functions TypeScript build, Worker syntax
checking and all 35 Node-compatible Worker tests. A repository-wide comparison
confirmed that none of the three generated passwords appears in any tracked file.
The default Cloudflare Vitest pool cannot start `workerd` in this Windows sandbox,
so the repository's supported `test:node` configuration was used; no product test
case failed.

## App Store Connect handoff

The reviewer usernames are:

- Student: `englishplus.tw+review.student@gmail.com`
- Teacher: `englishplus.tw+review.teacher@gmail.com`
- Volunteer: `englishplus.tw+review.volunteer@gmail.com`

Their three unique passwords exist only in the private local credential file
outside the repository. When RELEASE-5 prepares App Store Connect metadata, the
passwords must be copied manually from that file into the private review fields;
they must never be pasted into Git, Review Notes source, logs or this task.

The deterministic source is
`docs/app-store-release/store-4/review-seed-spec.json`; the executable tool is
`scripts/release3_review_accounts.cjs`. Static validation is performed by
`scripts/validate_release3_review_accounts.py` before and after live provisioning.

## Release gate

RELEASE-3 is complete only after static validation, live provisioning, three role
sign-ins, production Worker authorization and a final verification rerun all pass.
The result remains local until a later release round explicitly authorizes a push.
The competition build 53 remains assigned only to its existing external group.
