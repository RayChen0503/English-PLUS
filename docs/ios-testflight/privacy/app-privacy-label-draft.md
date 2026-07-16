# English+ App Privacy Label Working Record

Last implementation check: 2026-07-16. Recheck this file against the shipping
binary before every App Store submission.

## Public URLs

- Privacy policy:
  `https://sites.google.com/view/englishplus-privacy/%E9%9A%B1%E7%A7%81%E6%94%BF%E7%AD%96`
- Support and privacy choices:
  `https://sites.google.com/view/englishplus-privacy/%E6%94%AF%E6%8F%B4%E8%88%87%E8%81%AF%E7%B5%A1`
- Support email: `englishplus.tw@gmail.com`

## App Store Connect answer

English+ and its third-party processors collect data from the app. Data is
used for App Functionality and, where noted, Product Personalization. English+
does not use any collected data for tracking, third-party advertising, or
developer advertising.

| App Store data type | English+ examples | Linked to user | Tracking | Purpose |
| --- | --- | --- | --- | --- |
| Contact Info - Name | display name | yes | no | App Functionality |
| Contact Info - Email Address | account login and support contact | yes | no | App Functionality |
| Identifiers - User ID | Firebase UID and app account ID | yes | no | App Functionality |
| User Content - Photos or Videos | optional JPEG/PNG volunteer qualification evidence | yes | no | App Functionality |
| User Content - Other User Content | support requests, replies, teacher tasks, PDF evidence and review reasons | yes | no | App Functionality |
| Usage Data - Product Interaction | question attempts, mission progress, class assignment completion | yes | no | App Functionality, Product Personalization |
| Sensitive Info | mood check-in, support context, volunteer qualification evidence | yes | no | App Functionality, Product Personalization |
| Diagnostics - Crash Data | opt-in Firebase Crashlytics crash and non-fatal reports | no | no | App Functionality |
| Diagnostics - Other Diagnostic Data | minimized route, role and error-category context when diagnostics is enabled | no | no | App Functionality |
| Location - Coarse Location | Google Sign-In may infer coarse location from IP for fraud prevention | no | no | App Functionality |

Crash diagnostics is bundled but disabled by default. Because a user may opt in,
the optional collection is still disclosed. No email, Firebase UID, question,
answer, support text or evidence filename is attached as a Crashlytics custom key.

## Processors and data boundaries

| Provider | Purpose | Data boundary |
| --- | --- | --- |
| Firebase Auth | Email, Google and Apple account authentication | account identifiers and selected provider data |
| Firestore | account, personal learning, class, task, mood and support synchronization | role- and class-scoped linked records |
| Apple / Google | optional federated sign-in | data the user approves in the provider flow |
| Cloudflare Worker | authenticated AI gateway, quota and account operations | Firebase identity token plus minimized task context |
| Cloudflare R2 | private volunteer evidence storage | user-selected evidence files; administrator-only review |
| Groq | AI model inference | minimized learning context received only through the Worker |

The iOS app contains no Groq key and never calls Groq directly. AI prompts must
exclude real names, email addresses and volunteer evidence. A question prompt,
student answer, correct answer, mood score, available time level or recent
accuracy may be sent only when needed for the selected AI feature.

## User controls

- The app links the privacy policy before sign-in, during versioned consent and
  from the account screen.
- The app links the support/privacy-choices page and support email.
- Users can initiate complete account deletion in the app.
- Students choose whether to send a question or emotional-support request to a
  teacher or volunteer; a mood score never triggers automatic staff contact.
- A policy-version change requires a new in-app agreement.
- Public student self-registration records only a declared 13+ access path,
  not an exact birth date. Under-13 students require a school- or
  guardian-managed account.

## Submission checklist

1. In App Store Connect choose **Yes, we collect data from this app**.
2. Select every category in the table and use the listed purposes.
3. Match the **Linked to user** answer to the table above: name, email,
   user ID, user content, product interaction and sensitive information are
   linked; crash data, other diagnostics and coarse location are not linked.
   Mark every category as **not used for tracking**.
4. Enter the privacy-policy URL above.
5. Use the support page as the optional User Privacy Choices URL.
6. Compare the generated Xcode privacy report, `PrivacyInfo.xcprivacy`, this
   record and the production policy before publishing the answers.
