# Round 4 - Provider UI and private volunteer review

Date: 2026-07-12

Working branch: `codex/app-store-hardening`

Progress after completion: **4/20**

## Outcome

Round 4 completes the first four-round hardening block on Windows. The app now
contains the production-facing Google, Apple, and Email/password onboarding
layer, role-specific registration, a nationwide institution picker, a private
volunteer-evidence boundary, and an administrator-only review surface.

No production secret was committed. After the required Cloudflare and Firebase
console settings were completed, the Worker and Firestore rules were deployed
from Windows. The hardening branch has not been merged or pushed and Xcode
Cloud has not been triggered.

## Identity providers

- Google Sign-In `9.1.0` is declared through Swift Package Manager. Both the
  provider SDK and its official SwiftUI sign-in button are target products.
- Sign in with Apple uses `AuthenticationServices`, a cryptographically random
  nonce, SHA-256 request binding, and the app entitlement/capability.
- Email/password registration, verification, reset, and explicit role sign-in
  remain available.
- Provider collisions preserve the pending credential. After the user proves
  ownership with an existing sign-in method, Firebase links the provider to
  the same UID and Firestore records the non-authoritative provider list.
- Cold launch still starts with role selection and explicit sign-in. The new
  provider UI does not restore the old automatic-login regression.

Xcode Cloud restores the ignored `GoogleService-Info.plist` from its secret
environment variable. The post-clone scripts also read `REVERSED_CLIENT_ID`
and inject the Google callback URL scheme. They fail early when the refreshed
Firebase plist does not contain Google configuration.

## Role onboarding

### Student

- Can register with Google, Apple, or Email/password.
- Starts in personal mode and can use learning features without a class.

### Teacher

- Can self-register without administrator approval.
- Must select an education institution.
- The affiliation is visibly and structurally `selfDeclared`; it is not
  represented as verified employment.
- A teacher still sees no student data until the student joins a class.

### Volunteer

- Creates a restricted `pendingApplication` account first.
- Confirms adult status and conduct terms, states motivation, then uploads at
  least one PDF/JPEG/PNG proof up to 10 MB.
- Cannot access student or class data while applying or awaiting approval.
- Approval activates the account. Rejection disables it. A request for more
  information returns the applicant to the evidence step without granting
  student-data access.

## Institution directory

The generated seed contains **3,921 unique active institutions** for academic
year 114:

| Type | Count |
| --- | ---: |
| Elementary school | 2,608 |
| Junior high school | 747 |
| Senior high school | 507 |
| Experimental education institution | 59 |

The directory is generated from registered Ministry of Education/open-data
sources. Search begins after two characters, returns at most ten ranked
results, and prioritizes official and prefix matches. Unlisted experimental,
homeschool, and education groups can be entered manually but remain
`userSubmitted` and self-declared.

## Private evidence boundary

Raw evidence bytes never enter Firestore user documents and never enter the
iOS repository. The Cloudflare Worker provides:

- Firebase ID-token verification using the Firebase issuer/audience and
  Google signing keys.
- Five-minute HMAC upload tickets bound to UID, object key, MIME type, size,
  qualification type, and expiry.
- A private R2 binding named `VOLUNTEER_EVIDENCE`.
- Owner-scoped keys and upload/delete access only while the account is in
  `pendingApplication`.
- PDF/JPEG/PNG allow-list and a 10 MB maximum.
- A five-file and 25 MB aggregate limit per applicant, enforced before a
  single-use upload reservation is issued.
- Administrator-only application listing, review, and evidence download.
- `no-store`, attachment disposition, and `nosniff` evidence responses.
- Firestore review commits through a service account, not through a mobile
  client secret.
- Pagination for more than 100 volunteer applications and Worker
  observability with 10% head sampling.
- A daily retention job that deletes final-review evidence after 30 days,
  clears stale Firestore references, and removes expired upload reservations.
  The 90-day R2 lifecycle rule remains a second-line orphan cleanup.

The iOS app never contains the Groq key, service-account key, R2 credentials,
or upload signing secret.

## Administrator review

The volunteer review tab appears only when the authenticated Firebase token
contains the `admin: true` custom claim. An administrator can:

- review pending and returned applications;
- inspect each evidence attachment through Quick Look;
- approve, reject, suspend, or request more information;
- add a review note before rejection or requesting more information.

Normal teachers do not receive this tab merely because they selected a school.

## Firestore rules

The draft rules now enforce:

- active teacher self-registration with a self-declared institution profile;
- inactive volunteer application states;
- an atomic `pendingApplication` to `pendingApproval` client transition only
  when a pending-review application has evidence;
- append-only provider linking limited to Email/password, Google, and Apple;
- no client-side approval or activation of a volunteer.

The reviewed rules were deployed to `englishplus-testflight`. Runtime smoke
tests confirmed that an authenticated user may reach their own missing profile
document (404 rather than permission denied), while a student cannot read
another user's profile (403).

## Regression reconciliation

The first full audit initially reported 19 legacy-validator failures. The
implementation was checked before changing tests. Those failures expected
interfaces deliberately removed in later product decisions, including a
standalone AI branch in the support inbox, old selected-card volunteer UI,
read-without-reply controls, and assignments on the student home screen.

The validators now protect the current behavior:

- AI help stays inline with daily-mission and free-practice questions.
- The support tab is a human reply inbox.
- Teacher and volunteer share one queue model and each may archive locally.
- Student assignments live in the dedicated classroom tab.
- Practice receives the repository's approved question bank.

One real copy issue found during the audit was fixed: a teacher-facing fallback
no longer says that a question is missing "on this device"; it now says the
question content cannot currently be loaded.

## Verification evidence

Passed on Windows:

- Round 4 dedicated contract validator: 3,921 institutions.
- Xcode source-membership validator: 58 Swift files before the provider UI
  product-only addition; all new Swift files remain target members.
- Worker syntax check.
- Six Worker security tests cover unauthenticated AI rejection, evidence
  metadata enforcement, upload-ticket tamper/expiry rejection, aggregate quota
  reservations, final-review retention selection, and legal review-state
  transitions.
- Round 3 regression and all updated targeted legacy regressions.
- Full repository validator audit: **64 passed, 0 failed** at the completion
  gate.
- Python compilation, TypeScript build, JSON/plist parsing, and Git whitespace
  checks are part of the final command gate.

Swift/Xcode compilation is not available on this Windows host. Xcode Cloud is
the agreed release compiler after the manual provider/storage settings and the
deliberate first-block push.

## Deployment and runtime smoke evidence

- Cloudflare Worker URL:
  `https://englishplus-ai-proxy.englishplus-ray.workers.dev`
- Deployed Worker version:
  `06484437-4a9b-47a6-8044-80e48d2fdbe4`
- Private R2 binding: `VOLUNTEER_EVIDENCE` ->
  `englishplus-volunteer-evidence`.
- Daily cleanup schedule: `17 3 * * *` UTC.
- Firestore rules were compiled and released to `englishplus-testflight`.
- Online smoke tests passed for Worker health, unauthenticated boundaries,
  student/teacher/volunteer Firebase sign-in, a real Groq response with
  `fallbackUsed=false`, Firestore self/cross-user access, ordinary-teacher
  rejection from the admin endpoint, and volunteer upload-state rejection.
- The smoke client deletes an upload reservation if a positive volunteer
  ticket is issued, so validation does not consume an applicant's quota.

The positive administrator-review path still requires assigning `admin: true`
to a deliberately chosen non-demo owner account. It must not be assigned to a
demo account whose credentials are present in source fixtures.

## Block A final UX and behavior audit

The four-round checkpoint was reviewed as an end-to-end user flow rather than
only as source presence. The final audit fixed the following issues before the
release gate:

- the account-creation button now interpolates the selected role correctly;
- the applicant sees file count, total size, administrator-only visibility,
  and the 30-day final-review deletion policy before uploading;
- upload and delete controls cannot race each other, and a failed upload
  releases its reserved quota instead of blocking the applicant for ten
  minutes;
- evidence download failures are visible to the administrator;
- downloaded evidence is removed from the local temporary directory when its
  preview closes or the review screen exits;
- an application waiting for more information cannot be approved or rejected
  until the applicant resubmits it;
- the Worker validates the same review-state transitions and uses the
  Firestore document update time to reject stale concurrent review writes;
- the decision register now matches the deployed quota and retention policy.

## Manual gate before release build

1. Replace the Xcode Cloud base64 `GoogleService-Info.plist` environment
   variable with the refreshed Google-enabled Firebase configuration.
2. Assign a chosen owner account the Firebase `admin: true` custom claim.
3. Resolve packages/build in Xcode Cloud, then test all three providers and the
   volunteer application/review lifecycle before TestFlight distribution.
