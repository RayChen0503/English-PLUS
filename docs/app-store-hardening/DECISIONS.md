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
| D-05 | 2026-07-10 | Staff accounts are not self-created in the current product. Superseded by D-10 and D-11. | Historical Round 3 decision retained for traceability. |
| D-06 | 2026-07-10 | TestFlight/Xcode Cloud releases are gated by four-round blocks. | Reduces unnecessary cloud builds while preserving deliberate release checks. |
| D-07 | 2026-07-10 | Internal provider, mock, diagnostic, and key language stays out of role-facing UI. | The app must present learning actions, not implementation details. |
| D-08 | 2026-07-10 | Production identity uses email/password only in Round 3. Superseded by D-09. | Historical interpretation of `3.C`; later corrected against the original option numbering. |
| D-09 | 2026-07-12 | Production identity supports Google + Apple + Email/password, with provider linking to one account. | The original `3.C` meant all three methods; linked providers must preserve one UID and learning history. |
| D-10 | 2026-07-12 | Teacher self-registration is active immediately after verified sign-in and requires a self-declared education institution. | School selection improves context but is not proof of employment; students must still opt into a class before data becomes visible. |
| D-11 | 2026-07-12 | Volunteer self-application remains pending until an administrator approves evidence and conduct eligibility. | A volunteer cannot access minor students or support records before review. |
| D-12 | 2026-07-12 | Official institutions come from annual Ministry of Education directories; unlisted experimental or homeschool groups are user-submitted and visibly unverified. | Search stays usable without misrepresenting a manual entry as an official record. |

## Pending decisions

- Round 4 will use Cloudflare R2 signed uploads for volunteer evidence unless a
  different private object store is selected before implementation.
- Exact volunteer evidence retention and deletion periods remain part of the
  later privacy and operations block; raw evidence must never be stored in a
  user profile document.
