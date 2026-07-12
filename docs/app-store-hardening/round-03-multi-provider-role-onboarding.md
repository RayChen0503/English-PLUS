# Round 3 - Multi-provider role onboarding

Date: 2026-07-12

Working branch: `codex/app-store-hardening`

Progress after completion: **3/20**

## Correction applied

The earlier Round 3 interpreted option `3.C` as Email-only because a later
prompt reused local option letters. The original product choice was **Google +
Apple + Email/password**. This report and its implementation supersede
`round-03-email-identity-and-staff-provisioning.md` without rewriting Git
history.

## Confirmed product behavior

- One account may link Email/password, Google, and Apple identities while
  retaining one Firebase UID and one learning history.
- Authentication providers prove identity; they do not grant a product role.
- Students self-register into personal mode and may use the app without a
  class.
- Teacher self-registration becomes active after identity verification and
  requires an education-institution selection.
- A teacher affiliation is explicitly `selfDeclared`; choosing a school is
  not represented as employment verification.
- A teacher sees no student data until a student intentionally joins the
  teacher's class. Post-join visibility from Round 2 remains unchanged.
- Volunteer self-application requires age-18 confirmation, a conduct version,
  motivation, and at least one evidence reference. The account remains pending
  until a trusted administrator approves it.

## Identity and registration domain

`IdentityModels.swift` now separates:

- `AccountIdentityProvider`: Email/password, Google, Apple.
- `AccountProvisioningSource`: role onboarding source, independent of login.
- `AccountRegistration`: shared profile input plus role-specific details.
- `RoleOnboardingProfile`: credential-independent role completion for a new
  Google or Apple identity.
- `FederatedIdentityCredential`: a provider-neutral boundary for Round 4 SDK
  integration and account linking.
- Institution, teacher-affiliation, volunteer-qualification, evidence, and
  application-state models.

`AuthService` exposes federated sign-in and identity-linking contracts. Existing
Email/password creation remains available and is now routed through the same
role-aware registration object.

## Role state guarantees

The Firebase and fallback implementations agree on these states:

| Role | Self-registration | Initial account state | Required detail |
| --- | --- | --- | --- |
| Student | Yes | Active after email policy | None; personal mode |
| Teacher | Yes | Active after email policy | Self-declared institution |
| Volunteer | Application only | Pending approval | 18+, conduct, motivation, evidence |

The Firebase implementation writes the user profile and role-specific document
in one Firestore batch. A failed role-document write cannot leave a partially
provisioned profile.

## Firestore boundary

- `users/{uid}` contains immutable role, provisioning state, account state, and
  non-authoritative linked-provider metadata.
- `teacherProfiles/{uid}` contains the self-declared institution claim.
- `volunteerApplications/{uid}` contains the application and private evidence
  object references.
- `educationInstitutions/{institutionId}` is server-managed catalog data.
- Client rules allow a teacher to create only an active teacher profile with a
  `selfDeclared` claim.
- Client rules allow a volunteer to create only a pending account and a
  `pendingReview` application. No client rule can approve or activate it.
- Raw evidence bytes, object-store credentials, and download secrets are not
  stored in user documents.

## Institution catalog

The source register covers Ministry of Education datasets:

- 6087 - elementary schools
- 6088 - junior high schools
- 6089 - senior high schools
- 162568 - experimental education schools

`build_taiwan_education_institution_catalog.py` converts explicitly downloaded
CSV files into deterministic JSON. It supports UTF-8/UTF-8-BOM/CP950, stable
IDs, deduplication, academic-year metadata, and official source attribution.
The app-side search contract waits for two characters, supports city/type
filters, prioritizes prefix and official matches, and caps visible results.
Unlisted experimental institutions, homeschool groups, and other education
organizations use a manual `userSubmitted` record and remain visibly
`selfDeclared`.

## Preserved behavior

- Explicit cold-launch role selection and sign-in remain mandatory.
- Email verification, password reset, enumeration-safe reset copy, account
  status enforcement, and personal/class separation remain intact.
- Existing Email-only accounts remain valid and can link another provider in a
  later session instead of creating a second account.
- No provider name, mock state, secret, or diagnostics text is added to the
  student, teacher, or volunteer product screens in this domain round.

## Verification evidence

The final command results are recorded in the completion summary and Git
commit. Required checks include the rewritten Round 3 validator, Round 2 mini
regression, Xcode project-source validation, Firebase contract validators,
Python syntax checks, TypeScript build, and `git diff --check`.

Swift compilation is unavailable on the Windows host. Round 4 is the first
block checkpoint and must run the full validator audit before one deliberate
merge/push and Xcode Cloud build.

## Round 4 prerequisites

Round 4 implements the visible/provider-specific layer:

1. Enable Google and Apple providers in Firebase Authentication.
2. Refresh `GoogleService-Info.plist` after Google provider configuration.
3. Add Google Sign-In SDK and URL scheme; add Sign in with Apple capability.
4. Build role onboarding screens, searchable institution picker, volunteer
   application, pending state, and administrator review surface.
5. Use a private signed-upload Worker and Cloudflare R2 for evidence unless the
   storage decision changes before Round 4 starts.
6. Complete the first-block full audit before any `main` push/Xcode Cloud run.

No Firebase deployment, production secret, `main` merge, or Xcode Cloud trigger
is part of Round 3.
