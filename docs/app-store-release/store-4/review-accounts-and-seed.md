# STORE-4 Review Accounts and Deterministic Seed

Apple must be able to test every gated role without waiting for an administrator,
teacher, volunteer or scheduled job. Passwords belong only in App Store Connect.
Do not commit them to Git, CI variables, screenshots or Review Notes source files.

## Required private accounts

| Role | App Store Connect label | Required precondition |
| --- | --- | --- |
| Student | `Student reviewer` | active account, current consent, joined to `APP-REVIEW-CLASS`, one pending assignment, one answered support thread and clean daily mission state |
| Teacher | `Teacher reviewer` | active teacher profile, owns `APP-REVIEW-CLASS`, may assign and reply, roster contains only fictional review users |
| Volunteer | `Volunteer reviewer` | approved application, evidence already purged or replaced by synthetic metadata, active service authorization for `APP-REVIEW-CLASS` |

Use dedicated Email/password accounts for review even though Google and Apple
sign-in remain available to customers. This avoids 2FA and provider-consent
screens blocking App Review.

## Seed data contract

The machine-readable, credential-free source of truth is
`review-seed-spec.json`. Provisioning must be idempotent: rerunning it replaces
only the dedicated review scope and never touches ordinary production users.

- Class display name: `English+ App Review Demo`
- Class code: a non-secret code shown in Review Notes only if the student flow
  requires it; otherwise prejoin the student.
- Names: `Review Student`, `Review Teacher`, `Review Volunteer`.
- No real school, student, teacher, volunteer, email thread or uploaded evidence.
- One 5-question assignment across at least two skills.
- One unresolved support request for teacher/volunteer reply testing.
- One resolved support request so the student can test read/archive behavior.
- One completed attempt and mastery record for progress views.
- A reset procedure must restore the seed after review mutations.

## Provisioning gate

The accounts cannot be created safely until the isolated production Firebase,
Worker, R2 and admin portal from STORE-0 are deployed. Creating them in
`englishplus-testflight` would alter the competition backend and violates the
frozen-source/public-build-53 boundary. Provision them only in
`englishplus-production`, then run a
three-device smoke test before entering credentials in App Store Connect.

## Manual secret procedure

1. Generate three unique passwords with a password manager.
2. Create the accounts in production Firebase Authentication.
3. Run the reviewed seed command against production with explicit confirmation.
4. Verify each role in a clean install.
5. Enter usernames and passwords in App Store Connect App Review Information.
6. Keep the credentials active and backend services online for the entire review.
7. Rotate or disable the review passwords after release, then create fresh ones
   for the next version if Apple may need to retest.

## Mandatory rotation before first submission

Earlier development builds stored seeded demo credentials in source control.
Those values have been removed from the shipping target and automated tests,
but Git history must be treated as public. Disable or rotate every account that
ever used a historical seeded password before provisioning the production
review accounts. Never reuse a historical demo password for App Review.
