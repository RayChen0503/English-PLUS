# STORE-4 App Privacy Questionnaire

Use this as the click-by-click truth record for the shipping production build.
Apple requires the answers to include both English+ collection and integrated
third-party SDK practices. Recheck after any SDK or backend change.

## Top-level answers

- **Does this app collect data?** Yes.
- **Tracking:** No. English+ does not track users across other companies' apps or websites.
- **Advertising:** None.
- **Data broker sharing:** None.
- All listed data is **not used for tracking**.

## Data types to select

| Apple data type | Collected | Linked | Purposes | English+ use |
| --- | --- | --- | --- | --- |
| Contact Info / Name | Yes | Yes | App Functionality | display name and role profiles |
| Contact Info / Email Address | Yes | Yes | App Functionality | Email, Google and Apple authentication; support contact |
| Identifiers / User ID | Yes | Yes | App Functionality | Firebase UID and federated sign-in identifier |
| User Content / Photos or Videos | Yes | Yes | App Functionality | optional JPEG/PNG volunteer qualification evidence |
| User Content / Other User Content | Yes | Yes | App Functionality | support requests and replies, teacher tasks, PDF evidence and review reasons |
| Usage Data / Product Interaction | Yes | Yes | App Functionality; Product Personalization | attempts, answers, progress, mastery, mission and assignment completion |
| Sensitive Info | Yes | Yes | App Functionality; Product Personalization | mood check-in and user-selected qualification evidence; treated conservatively |
| Diagnostics / Crash Data | Yes | No | App Functionality | opt-in Firebase Crashlytics crash and non-fatal reports |
| Diagnostics / Other Diagnostic Data | Yes | No | App Functionality | SDK transport health and minimized route/role diagnostic context when enabled |
| Location / Coarse Location | Yes | No | App Functionality | Google Sign-In may infer coarse location from IP for fraud prevention |

Do **not** select precise location, contacts, browsing history, search history,
financial information, purchases, advertising data, audio data or fitness data.

## Processor reconciliation

| Processor | Shipping purpose | Data boundary |
| --- | --- | --- |
| Firebase Authentication | Email, Google and Apple sign-in | account identifier, selected provider profile data and SDK user agent |
| Cloud Firestore | synchronized app records | role-scoped account, learning, class, assignment, mood and support records |
| Firebase Crashlytics | optional stability diagnostics | crash state, device/OS details, route, role and sanitized error category; no prompt, reply, email or UID custom key |
| Google Sign-In | optional federated sign-in | user identifier and IP-based fraud prevention data |
| Cloudflare Worker | authenticated AI and evidence gateway | Firebase token plus minimized feature payload; rejects client-supplied API keys |
| Groq | model inference | minimized learning context received only from the Worker |
| Cloudflare R2 | private volunteer evidence | PDF/JPEG/PNG evidence, administrator-only review, retention policy enforced server-side |

## User controls and retention

- Versioned consent is shown before protected app features.
- Stability diagnostics is optional and can be disabled; unsent reports are deleted.
- Students explicitly choose whether to send a question to a person. Mood results
  do not automatically notify teachers or volunteers.
- Account deletion is initiated in the app and completed by the backend lifecycle.
- Volunteer evidence is limited to five files and 25 MB total, with a 90-day
  lifecycle ceiling and an earlier post-review deletion target where applicable.
- Privacy policy: `https://sites.google.com/view/englishplus-privacy/%E9%9A%B1%E7%A7%81%E6%94%BF%E7%AD%96`
- Privacy choices/support: `https://sites.google.com/view/englishplus-privacy/%E6%94%AF%E6%8F%B4%E8%88%87%E8%81%AF%E7%B5%A1`
- Contact: `englishplus.tw@gmail.com`

## Pre-submission check

Compare this table with the generated Xcode privacy report, every SDK privacy
manifest, `PrivacyInfo.xcprivacy`, the production policy and actual network
captures. A mismatch blocks submission.
