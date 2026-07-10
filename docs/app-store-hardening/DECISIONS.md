# English+ hardening decision register

This is the compact record of confirmed product decisions. A later change must
add a new dated entry; do not silently rewrite a decision that code or rules
already depend on.

| ID | Date | Decision | Why it matters |
| --- | --- | --- | --- |
| D-01 | 2026-07-10 | One account may join multiple classes and choose one active class. | Supports school changes and multiple learning contexts without duplicating accounts. |
| D-02 | 2026-07-10 | Class staff see only records from the student's `visibilityStartsAt` onward. | Keeps personal learning history private when a student later joins a class. |
| D-03 | 2026-07-10 | New self-service accounts start in personal student mode. | A class is optional; independent learners must not be blocked. |
| D-04 | 2026-07-10 | Cold launch requires explicit role selection and sign-in. | Prevents the known regression where automatic restoration bypasses role choice. |
| D-05 | 2026-07-10 | Staff accounts are not self-created in the current product. | Teacher and volunteer provisioning needs an invitation or approval boundary. |
| D-06 | 2026-07-10 | TestFlight/Xcode Cloud releases are gated by four-round blocks. | Reduces unnecessary cloud builds while preserving deliberate release checks. |
| D-07 | 2026-07-10 | Internal provider, mock, diagnostic, and key language stays out of role-facing UI. | The app must present learning actions, not implementation details. |

## Pending decisions

| ID | Required before | Options |
| --- | --- | --- |
| P-01 | Round 3 identity | Google + Apple + email/password (recommended); Apple + email/password; email/password only |
| P-02 | Round 3 staff setup | Invitation/admin approval only (recommended); self-register then approval |
