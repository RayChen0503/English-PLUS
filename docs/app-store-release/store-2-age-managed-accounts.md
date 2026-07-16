# STORE-2 Public Age Gate and Managed Student Accounts

Decision A is implemented for the App Store release branch.

## Shipping behavior

- Public Email, Google and Apple first-use registration share one student gate.
- A student may self-register only after selecting `13 years or older`.
- A student selecting `under 13` cannot submit public registration and is sent
  to the English+ support path for a school- or guardian-managed account.
- English+ does not collect an exact date of birth in this flow.
- The iOS client cannot create `managedStudent` profiles. That provisioning
  source is reserved for a trusted administrative backend.
- Existing student records without the new field use a one-time legacy
  eligibility confirmation; they are not silently treated as 13+.

## Stored contract

- `studentAccessPath = age13OrOlder` for public student registration.
- `studentAccessPath = schoolOrGuardianManaged` only for a trusted
  `managedStudent` profile.
- `studentAccessPath = notApplicable` for teacher and volunteer accounts.
- Versioned consent stores the same access path. Firestore denies consent that
  does not match the authenticated profile.

## Safety and privacy boundary

- The app does not use Apple's Kids Category for version 1.0.
- Under-13 users do not complete the public adult-style self-registration flow.
- A managed account does not automatically expose classroom or support data;
  normal class membership and role rules still apply.
- The public privacy page was verified online with the finalized 2026-07-16
  minor and managed-account wording before release-candidate preparation.

## Verification

- Swift acceptance coverage rejects missing and forged managed student paths.
- Firestore Emulator coverage accepts a valid 13+ public student, rejects a
  missing age path, rejects client-created managed profiles, and rejects a
  mismatched consent path.
- Full Firestore suite: `40/40` passed on 2026-07-16.
- No remote deployment, push or Xcode Cloud run was performed in STORE-2.
