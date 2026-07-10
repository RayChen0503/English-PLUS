# Round 3 - Email identity and staff provisioning

Date: 2026-07-10

Working branch: `codex/app-store-hardening`

## Confirmed direction

- **Decision 3C - Email/password only.** This round does not add Google or
  Apple identity providers.
- Teacher and volunteer accounts remain invitation/admin provisioned. A public
  client cannot create or promote itself into a staff role.
- Cold launch continues to require role selection and explicit sign-in.

## Identity contract

- Student self-service registration creates a personal-mode student profile.
- New student profiles set `emailVerificationRequired` and receive a localized
  verification email before they may enter protected learning flows.
- Existing internal seed accounts remain compatible when the migration field
  is absent. Production accounts should be migrated deliberately rather than
  silently locked out.
- Password reset copy does not reveal whether an email is registered.
- Invalid email, invalid credentials, weak password, duplicate email,
  disabled/pending accounts, role mismatch, network failure, and throttling
  are mapped into clear user-facing outcomes.

## Staff provisioning boundary

- Staff self-registration is rejected in both real and fallback Auth services.
- `AccountProvisioningStatus` models active, pending, suspended, and disabled
  accounts.
- `FirestoreStaffInvitationDocument` defines a time-bound server-managed
  invitation contract.
- The draft rules deny all direct client reads and writes to
  `staffInvitations`; a trusted backend or Firebase Admin SDK must perform the
  actual invitation acceptance and profile creation later.

## Login UX

- Production login fields start empty and no longer expose or prefill demo
  credentials.
- Only students see account creation.
- Forgot-password and verification-resend actions are available on the same
  screen with loading, success, and error states.
- User-facing copy describes the action the person must take and does not name
  Firebase, mocks, providers, or internal infrastructure.
- New passwords require at least eight characters.

## Firestore draft protection

- New self-created user documents must be students in personal mode with an
  active account status, `selfServiceStudent` provisioning source, and email
  verification required.
- New self-created documents use an explicit field allowlist; clients cannot
  smuggle additional account-control fields into their profile.
- Personal and classroom data access requires an active account and either a
  verified email token or an explicitly migrated legacy profile.
- Account status, primary role, provisioning source, and verification policy
  cannot be promoted through the normal self-update allowlist.
- A user cannot update the legacy `active` field, so an inactive legacy
  account cannot reactivate itself before account-status migration.

## Verification evidence

Passed on the Windows hardening host:

- `python scripts/validate_app_store_hardening_round3.py`
- `python scripts/validate_app_store_hardening_round2.py`
- `python scripts/validate_firebase_role_entry_signin.py`
- `python scripts/validate_ios_mission_login_regression.py`
- `python scripts/validate_ios_seed.py`
- `python scripts/validate_round6_firebase_privacy_contract.py`
- `python scripts/validate_round2_firebase_runtime_sync.py`
- `python scripts/validate_firebase_sync_ai_readiness.py`
- `python scripts/validate_cross_role_flow_consistency_round6.py`
- `python scripts/validate_ios_xcode_project_sources.py`
- `python scripts/validate_round4_backend_contract.py`
- `python scripts/validate_firebase_deploy_config.py`
- TypeScript `tsc --noEmit` for `functions/`
- Python syntax compilation for the changed validators
- `git diff --check`

Some existing validators encoded superseded copy and behavior. They were
updated to verify the current contracts: explicit cold-launch sign-in, the
shared `AuthServiceError`, the current visible password field, the shared
teacher/volunteer relay UI, and the removal of the obsolete no-reply action.
No retired product behavior was restored merely to satisfy a test.

Swift compilation is not available on this Windows host. Release-level Swift
compilation remains the Round 4 Xcode Cloud checkpoint after the full audit.

## External setup still required

Before this contract becomes a production gate:

1. Enable Email/Password in Firebase Authentication.
2. Configure the verification and password-reset email templates and domains.
3. Enable Firebase email-enumeration protection.
4. Provision teacher/volunteer profiles through a trusted admin process with
   `accountStatus: active` and the correct immutable role.
5. Migrate legacy accounts to an explicit email-verification policy.
6. Deploy and emulator-test the final Firestore rules in the backend-security
   block.

No secret, Firebase configuration file, production rule deployment, `main`
merge, or Xcode Cloud trigger is part of this round.
