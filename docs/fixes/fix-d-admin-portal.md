# FIX-D: Windows administrator review portal

## Outcome

FIX-D adds a browser-based English+ administrator workspace for reviewing
volunteer applications. It is intentionally independent from the teacher and
volunteer iOS navigation. Approval is a platform-administration responsibility,
not a classroom-teaching action.

Production URL after Firebase Hosting deployment:

`https://englishplus-testflight.web.app`

The portal supports desktop and narrow screens, light and dark appearances,
keyboard focus, loading/empty/error states, and explicit confirmation before a
review decision is committed.

## Administrator workflow

1. Sign in with an existing Google or Email/password Firebase account.
2. The Worker verifies the Firebase ID token and requires the custom claim
   `admin: true`. The web app cannot grant this permission to itself.
3. Filter or search applications across pending, supplement requested,
   approved, rejected, suspended, and draft states.
4. Open an application to confirm age, volunteer-conduct acceptance,
   motivation, evidence count, file size, and submitted time.
5. Open a private R2 evidence file. The Worker verifies that the object belongs
   to the selected applicant before returning it with `no-store` headers.
6. Approve, request more information, reject, or suspend when the current state
   allows that transition. A reason is required for every adverse action.
7. The application status, user account state, and immutable review event are
   written in one Firestore commit.
8. If another administrator changed the application first, the stale operation
   is rejected and the user must reload before deciding again.

## Permission boundary

- Firebase web configuration is public application metadata and is safe to
  bundle. It is not an administrator credential.
- Firebase service-account keys, R2 credentials, Groq keys, and upload-signing
  secrets remain Worker secrets and never enter the browser bundle.
- Firestore application documents are not read directly by the browser. Every
  privileged read and write goes through the Worker after token verification.
- Do not assign `admin: true` to source-controlled demo accounts.
- After a custom claim is assigned, the administrator should sign out and sign
  back in, or force-refresh the ID token, before testing.

## Review-state rules

| Current state | Allowed operation | Result |
| --- | --- | --- |
| `pendingReview` | approve | application `approved`, account active |
| `pendingReview` | request more information | application `needsMoreInformation`, account inactive |
| `pendingReview` | reject | application `rejected`, account inactive |
| `approved` | suspend | application `suspended`, account inactive |

An application waiting for more information must be resubmitted by the
applicant before it returns to `pendingReview`. Evidence for final decisions is
deleted according to the existing 30-day retention policy.

## Development and validation

```powershell
npm.cmd --prefix admin-web ci
npm.cmd --prefix admin-web run check
npm.cmd --prefix workers/englishplus-ai-proxy run check
npm.cmd --prefix workers/englishplus-ai-proxy run test:node
python scripts/validate_fix_d_admin_portal.py
```

Local visual QA is available only on localhost with `?preview=1`; this fixture
mode cannot be enabled on Firebase Hosting.

## Deployment order

1. Deploy the Worker so the new admin APIs and audit transaction are live.
2. Run unauthenticated and ordinary-account negative smoke tests.
3. Build `admin-web` and deploy Firebase Hosting.
4. Assign one deliberately chosen owner account the `admin: true` custom claim.
5. Sign in to the portal and complete one controlled positive review test.
6. Confirm the applicant account status, review-event history, and evidence
   access behavior before inviting additional administrators.

FIX-D stays on its feature branch until the block audit is accepted. It does
not merge `main` or trigger Xcode Cloud by itself.
