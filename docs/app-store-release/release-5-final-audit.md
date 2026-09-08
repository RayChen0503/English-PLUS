# RELEASE-5 Pre-Submission Final Audit

Audit date: 2026-07-18

## Release boundary

This audit covers the production App Store candidate on branch
`codex/app-store-production-release`. It does not authorize a commit, push,
Xcode Cloud run, TestFlight group change or App Store submission.

The competition release remains frozen:

- Tag `maic-competition-build-52` resolves to commit `1207a35`.
- Build 53 remains the only build assigned to the external group
  `English+Public Beta` (`English+公測` in App Store Connect).
- The public TestFlight invitation and its existing testers are unchanged.
- Production resources are isolated from `englishplus-testflight` and the
  competition Worker, R2 data and administrator site.

## Scope examined

The audit followed the complete first-use, returning-use and failure paths for:

- Student: Email, Google and Apple authentication; privacy consent; personal
  mode; class joining; mood check-in; daily mission; free practice; teacher
  assignments; AI explanations and repair sets; support requests and replies;
  mastery; offline recovery; reporting, blocking and account deletion.
- Teacher: account onboarding; school profile; class creation and membership;
  assignment creation, progress, withdrawal and deletion; student-submitted
  support; class transfer and account deletion.
- Volunteer: application, evidence upload and supplementation; approval scope;
  class service authorization; support replies; removal and account deletion.
- Administrator: authenticated access, evidence review, moderation queue,
  audit events and production-only authorization.

The implementation boundaries reviewed include Firebase Authentication,
Firestore rules and indexes, Cloudflare Worker authorization and quotas, R2
evidence retention, the administrator portal, AI transport, local caching,
listener recovery, privacy manifests, App Store metadata and competition/
production isolation.

## Finding fixed in this audit

The account-deletion flow already reauthenticated and revoked Sign in with
Apple, but a Google-linked account did not explicitly revoke its Google OAuth
grant before backend deletion. That left a third-party credential lifecycle gap
for App Store submission.

The pending patch now:

1. Detects whether the current Firebase account is linked to Google.
2. Obtains a fresh Google credential and reauthenticates Firebase.
3. Calls the Google Sign-In disconnect operation before backend deletion, which
   revokes the Google grant rather than merely signing out locally.
4. Blocks deletion if reauthentication or revocation fails.
5. Adds acceptance and contract tests for the Google deletion path.

The Apple deletion path remains unchanged and still requires fresh Apple
reauthentication and authorization-code revocation before deletion.

## Automated evidence

All available Windows-side gates passed after the patch:

- Repository validators: `104/104` passed.
- Firestore Emulator security/lifecycle suite on JDK 21: `40/40` passed.
- Cloudflare Worker Node suite: `35/35` passed; syntax check passed.
- Firebase Functions: TypeScript typecheck and production build passed.
- Administrator portal: `10/10` tests passed; production environment validation
  and a Vite production build passed.
- Question bank: 1,080 records, 36 skill categories, 218 semantic prompt forms;
  answer positions are evenly distributed at 270 each.
- Secret scan: no API key, service-account private key, review password,
  volunteer evidence or tracked `GoogleService-Info.plist` was found.
- Repository consistency: `git diff --check` passed.
- Public privacy and support pages are online. The privacy page covers identity,
  roles, learning and mood data, AI processing, volunteer evidence retention,
  account deletion, minors, access controls and third-party services. The
  support page provides `englishplus.tw@gmail.com`, account/deletion/class/AI/
  volunteer support topics and safe-contact guidance.

The emulator's `PERMISSION_DENIED` output is expected: those assertions prove
that students, teachers, volunteers and administrators cannot cross their
authorized data boundaries.

## Verified product properties

- Production cannot fall back to mock authentication, mock repositories or a
  debug AI route when configuration is missing; it fails closed.
- Google, Apple and Email first-use onboarding, consent and returning sessions
  have explicit role/profile gates. Sign-out removes active listeners.
- Personal mode works without class membership. Class assignments become
  visible only after authorized membership.
- Daily missions and manual practice use finite question sets. Type, difficulty
  and skill filters are enforced, and repair practice preserves the parent set.
- AI explanations appear only after an answer is submitted. Production clients
  do not contain the Groq key and cannot call Groq directly.
- Teacher assignments use exact question IDs; completion, withdrawal and
  progress states share one backend source of truth.
- Student support, teacher/volunteer replies, recall/archive state and unread
  counts are listener-backed across devices.
- Sync errors distinguish network, authentication, permission, configuration
  and index failures. Transient retry uses bounded backoff and no longer inserts
  a layout-shifting banner every second.
- User-generated support content is length-limited, screened, reportable and
  blockable; moderation decisions produce audit events.
- Volunteer evidence is private, limited to five files and 25 MB per
  application, and covered by review-state and retention controls.

## Production services verified

- Firebase project: `englishplus-production`.
- Production AI Worker: online and authenticated.
- Production Firestore rules and indexes: deployed and emulator-verified.
- Production R2 evidence storage and retention policy: isolated from competition.
- Production administrator portal: online and protected by the administrator
  claim.
- Fictional student, teacher and volunteer App Review accounts: provisioned and
  repeatedly verified against production without duplicate users.
- Build 56: archived, installed and isolated in `AppStore RC`; it was never
  added to the competition public group.

## Important compile boundary

Build 56 proves the production branch before this final local patch could be
archived and installed. The Google revocation change and its test updates are
not yet committed, pushed or compiled by macOS/Xcode Cloud. Windows cannot be
used as the authoritative Swift compiler.

Therefore the next candidate must be Build 57 or higher and must pass the Xcode
Cloud archive plus the Swift unit, integration and UI suites before it can
replace Build 56 as the submission candidate. It must be added only to
`AppStore RC`, never to `English+Public Beta`.

## Required clean-device verification

Complete this matrix on the next candidate before submission:

### Authentication and consent

- [ ] Fresh Email registration, Email verification, first consent and returning login.
- [ ] Fresh Google registration from the login screen and returning Google login.
- [ ] Fresh Apple registration from the login screen and returning Apple login.
- [ ] Role/profile setup is completed exactly once and survives app relaunch.
- [ ] Consent is account-scoped and is not shown again after acceptance.
- [ ] Wrong password, cancelled provider login and unavailable configuration show
      a useful error without entering another role.

### Student, class and assignment flow

- [ ] A student without a class completes personal mission, free practice, AI
      repair and mastery without blocked tabs.
- [ ] A student joins a class with a valid code; invalid/expired codes fail clearly.
- [ ] Teacher assignment appears on a second device with the exact selected set.
- [ ] Progress updates per answer, completion clears the student's badge, and
      teacher progress matches the student's results.
- [ ] Teacher withdrawal removes the assignment and badge on the student device.
- [ ] Class deletion/removal immediately removes class access without deleting
      personal learning history.

### Support and volunteer flow

- [ ] A new student account's first support request is immediately visible to
      authorized teacher/volunteer devices without relogin.
- [ ] The first staff reply appears immediately on the student's other device,
      clears waiting state and updates unread counts.
- [ ] Student recall, student archive and staff archive synchronize across devices.
- [ ] A volunteer can upload/view evidence, receive supplementation/rejection/
      approval reasons and dismiss the result notice.
- [ ] Approved volunteers see only authorized classes and submitted support;
      removal revokes access immediately.
- [ ] Administrator can view evidence and resolve a report with an audit event.

### Reliability and presentation

- [ ] Airplane mode shows a stable offline state; reconnect resumes listeners once.
- [ ] Permission/authentication failures are not mislabeled as network failure.
- [ ] Repeated navigation between class and support does not create refresh loops.
- [ ] Dark mode, light mode, Dynamic Type and small/large supported iPhones have
      readable text, reachable controls and no overlap.
- [ ] VoiceOver labels identify provider login, submit, back, destructive and
      progress controls.
- [ ] Google-linked and Apple-linked account deletion both reauthenticate,
      revoke the provider grant and remove app data without an orphan session.

## Required App Store Connect verification

- [ ] Upload current screenshots containing only fictional data.
- [ ] Confirm App Privacy answers against the privacy manifest and production traffic.
- [ ] Complete the live age-rating questionnaire and record the resulting rating.
- [ ] Sign the 1,080-question source/content-rights attestation.
- [ ] Confirm Taiwan availability, Education category, free price, no ads, no IAP
      and manual release.
- [ ] Confirm export compliance (`ITSAppUsesNonExemptEncryption = false`).
- [ ] Complete any trader/DSA status required by the selected storefronts.
- [ ] Enter the three private review credentials only in App Store Connect.
- [ ] Paste Review Notes describing the three roles, class seed, AI, evidence
      review, account deletion and administrator portal.
- [ ] Select Build 57 or higher from `AppStore RC`, inspect the submission draft,
      then submit for review with manual release.

## Final status

No remaining automatically discoverable product defect was found within the
audited source, service contracts and Windows-executable test surface after the
Google revocation fix. This is not yet submission approval: the pending Swift
patch must compile in Xcode Cloud, and every unchecked clean-device and App
Store Connect gate above must be completed.

No competition build, tester group, public invitation or competition backend
was modified by this audit.
