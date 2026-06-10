# English+ App Privacy Label Draft

This draft is for future App Store Connect / TestFlight preparation. It must be checked against the actual iOS implementation before submission.

## Current Expected Data Collection

English+ will collect data linked to the user.

| Data type | English+ examples | Linked to user | Tracking |
| --- | --- | --- | --- |
| Contact Info | name, email if used for login | yes | no |
| Identifiers | Firebase UID, app account ID | yes | no |
| User Content | support requests, teacher/volunteer replies | yes | no |
| Usage Data | question attempts, daily mission progress, app actions | yes | no |
| Diagnostics | crash logs if Firebase Crashlytics is added | maybe | no |
| Sensitive or highly private learning/support context | mood check-in and support context; final category must be checked against App Store Connect options | yes | no |

## Tracking Decision

Recommended answer:

```text
English+ does not track users across apps or websites owned by other companies.
```

Do not add advertising SDKs for the TestFlight classroom prototype.

## Third Parties

| Provider | Purpose | Data |
| --- | --- | --- |
| Firebase Auth | login | account identifiers, email if used |
| Firestore | app backend | student profile, class, learning, mood, support data |
| Firebase Cloud Functions | backend logic | minimized request context |
| OpenRouter | AI model routing | minimized AI prompt context only through backend proxy |

## OpenRouter Privacy Boundary

Do not send:

- real student names
- school email
- guardian contact
- phone number
- full private diary text
- teacher-only staff notes unless explicitly required and approved

Allowed minimized context examples:

```json
{
  "moodScore": 3,
  "availableTimeLevel": 4,
  "wantsChallenge": true,
  "recentAccuracy": 0.62,
  "recentWeakSkills": ["past-tense"],
  "questionPrompt": "I ___ my homework yesterday.",
  "studentAnswer": "finish",
  "correctAnswer": "finished"
}
```

## Privacy Policy Must Say

The public privacy policy should cover:

- what data is collected
- why it is collected
- who can see it
- how AI uses minimized context
- how to request access, correction, deletion, or stopping use
- how long data is kept
- contact method for privacy requests
- that the app is for learning support, not medical or counseling diagnosis

## TestFlight Notes

Even if the app is only distributed through TestFlight, the privacy statements should match the actual data flow. Do not wait until public App Store launch to build privacy wording because the app will already handle real student information during testing.
