# English+ TestFlight Internal Build Notes

Build: `1.0 (1)`  
Bundle ID: `tw.edu.englishplus`  
Audience: internal student, teacher, and volunteer testers  
Language: Traditional Chinese first

## What To Test

- Student role selection, demo sign-in, privacy consent, mood check-in, daily mission, answer feedback, mission completion, free practice, support request, and learning map.
- Teacher dashboard, priority student cards, support request queue, student state summary, and teacher feedback reply.
- Volunteer dashboard, assigned support queue, waiting-student view, encouragement reply, and relay records.
- Role separation: student, teacher, and volunteer screens should not expose each other's controls.
- Sensitive data handling: no OpenRouter key, Firebase debug state, backend setup text, or internal implementation wording should appear in normal user screens.

## Known Boundaries For This Build

- Firebase Auth and Firestore still run through replaceable mock services until `GoogleService-Info.plist`, Firebase SDK wiring, and deployed rules are ready.
- AI responses still use `MockAIService` by default. `RemoteAIService` is prepared for the Cloud Functions proxy but requires real Firebase Auth ID tokens and deployed backend access.
- App Store Connect upload requires an Apple Distribution signing path and App Store Connect permission. If Xcode asks for Apple ID two-factor authentication, account agreements, paid account actions, or certificate/profile creation approval, pause and let the Account Holder handle it.

## Internal Tester Focus

- Can students understand the next step without reading technical instructions?
- Does the four-question mood check-in feel short and clear?
- Does daily mission progress only advance after correct answers?
- Are wrong-answer explanations useful and not overwhelming?
- Do teachers immediately see who needs attention?
- Do volunteers see only the context they need for encouragement and relay?
- Is any screen crowded, duplicated, or showing debug/backend language?

## Feedback Format

Ask testers to report:

```text
Role tested:
Screen:
What happened:
What they expected:
Screenshot or short recording:
Device model:
iOS version:
```
