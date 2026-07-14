# English+ TestFlight Internal Build Notes

Version: `1.0`
Build: assigned by Xcode Cloud
Bundle ID: `com.englishplus`
Audience: internal student, teacher, and volunteer testers  
Language: Traditional Chinese first

## What To Test

- Google, Apple and Email sign-in, account restoration after relaunch, privacy consent and role-specific onboarding.
- Student personal learning, mood check-in, AI-generated daily mission, answer feedback, post-answer AI explanation, free practice, remedial practice and learning map.
- Classroom join/switch/leave, teacher assignments, live assignment progress and question-specific support across devices.
- Teacher classroom creation, roster, assignment/retraction, support reply, volunteer invitation/approval and class reports.
- Volunteer evidence application, review status, authorized class service, support reply and relay records.
- Role separation: student, teacher, and volunteer screens should not expose each other's controls.
- Sensitive data handling: no AI key, Firebase debug state, backend setup text, user ID or internal implementation wording should appear in normal user screens.

## Connected Services And Boundaries

- TestFlight builds use Firebase Authentication and Firestore. The protected Firebase configuration is injected during Xcode Cloud post-clone and is not stored in Git.
- Google, Apple and Email sign-in are real authentication providers. Account linking prevents the same person from silently receiving duplicate English+ accounts.
- AI requests use a Firebase-authenticated Cloudflare Worker and Groq. The app contains no Groq key and shows a recoverable fallback if the service is unavailable.
- Classroom assignments, support replies, volunteer service scope and review state synchronize through Firestore across signed-in devices.
- Teacher school affiliation is currently self-declared. Volunteer access requires both platform approval and approval for each service class.
- English+ provides learning support, not medical, psychological or emergency services. High-risk messages show human-help options but are not automatically reported.

## Internal Tester Focus

- Can students understand the next step without reading technical instructions?
- Does first-time Google, Apple and Email sign-in lead to the correct role without skipping consent?
- Does the four-question mood check-in feel short and clear?
- Does daily mission progress only advance after correct answers?
- Does AI explanation remain hidden until an answer is submitted, and does remedial practice return to the original set?
- Do assignments and support replies update correctly on a second device?
- Do teachers immediately see who needs attention?
- Do volunteers see only approved classes and the minimum question context needed to reply?
- Is any screen crowded, duplicated, or showing debug/backend language?

## Feedback Format

Ask testers to report:

```text
Role tested:
Account/provider:
Screen and action:
What happened:
What they expected:
Screenshot or short recording:
Device model:
iOS version:
Network state:
```
