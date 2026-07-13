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
| D-13 | 2026-07-12 | Volunteer evidence uses short-lived signed uploads to a private Cloudflare R2 bucket and administrator-only downloads. | Sensitive evidence bytes stay out of Firestore profiles, Git, and the iOS binary. |
| D-14 | 2026-07-12 | Volunteer evidence is limited to five files and 25 MB per applicant, deleted 30 days after a final review, with the 90-day R2 lifecycle retained as an orphan failsafe. | The operational limit is now deployed and must remain aligned across iOS copy, Worker enforcement, privacy documentation, and tests. |
| D-15 | 2026-07-12 | A class uses a stable join code that its teacher can reset at any time. | Teachers can invalidate a shared code without deleting the class or disrupting existing members. |
| D-16 | 2026-07-12 | Leaving a class immediately removes the learner's class access while staff retain historical class reports under the agreed retention policy. | Personal learning continues, but old class permissions and live assignments cannot follow the learner. |
| D-17 | 2026-07-12 | Every active teacher account may create a class without a separate class-creation approval. | Teacher onboarding stays usable while class access still depends on explicit student membership. |
| D-18 | 2026-07-13 | AI usage is lenient during internal testing (`internal`: 180 weighted units per user per Taipei day and 30 requests per minute) and switches to a stricter public policy before release (`public`: 60 units and 8 requests per minute). | Internal testers can exercise every AI flow while Firebase identity, least-privilege task authorization, atomic daily quotas and provider-cost protection are already enforced. |
| D-19 | 2026-07-13 | Account deletion removes identifiable personal data while retaining only non-reversible anonymous aggregate statistics. | A deleted account must not remain reconstructable from operational records, while product-level learning metrics may remain useful. |
| D-20 | 2026-07-13 | High-risk emotional messages do not trigger automatic staff notifications; the product provides an explicit human-help entry and clear emergency guidance. | Avoids presenting English+ as a monitored crisis service while preserving a direct route to trusted adults and appropriate help. |
| D-21 | 2026-07-13 | The question-bank target spans junior-high comprehensive-exam preparation through introductory high-school English, while retaining foundation material. | Learners can progress beyond the current floor without losing accessible recovery practice. |
| D-22 | 2026-07-13 | The UI direction is `Clear Learning Companion`: structured like Junyi, motivating like Duolingo, and restrained like native Apple interfaces. | Keeps learning actions obvious and encouraging without becoming childish or looking like a cold school administration tool. |
| D-23 | 2026-07-13 | The public privacy policy, support page and support mailbox are the Google Sites URLs and `englishplus.tw@gmail.com` supplied for English+. | The app, App Store metadata and privacy records must use one public source of truth instead of placeholders. |
| D-24 | 2026-07-13 | Third-party AI consent explicitly names Cloudflare and Groq, is versioned to the 2026-07-13 policy, minimizes prompt content and never treats AI output or a mood score as automatic human intervention. | Apple requires clear third-party AI disclosure and explicit permission; users also need an accurate, reversible understanding of the feature. |

## Pending decisions

- No unresolved product decision remains for Rounds 1-12. Raw volunteer
  evidence must never be stored in a user profile document.
