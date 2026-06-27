# Round 4 - Firebase Auth And Firestore Schema

This round turns the iOS/TestFlight backend direction into a concrete Firebase handoff spec. It is written for the future Mac/Xcode build, but it can already live in this repository so the Android prototype, iOS migration, and Firebase setup stay aligned.

## Confirmed Project Decisions

Use these values when creating the Firebase project and the iOS app entry:

| Item | Value |
| --- | --- |
| Firebase display name | `English+` |
| Fallback display name | `Englishplus` |
| Firebase project ID | `englishplus-testflight` |
| iOS Bundle ID | `com.englishplus` |
| iOS Firebase config file | `GoogleService-Info.plist` |

Important notes:

- The iOS bundle ID must be `com.englishplus`. Do not use the Android package name or any previous course-package wording for the iOS target.
- If Firebase does not allow `English+` as a display name, use `Englishplus` for the display name only. Do not change the project ID unless Firebase says the ID is unavailable.
- `GoogleService-Info.plist` will be downloaded later after the Firebase iOS app is registered. It should be added to the Xcode project on the Mac.
- Do not commit the real `GoogleService-Info.plist` to a public repository unless the repository access model is intentionally private and reviewed. Firebase config values are not secret like an API key, but they identify the Firebase project and should still be handled carefully.

## What `GoogleService-Info.plist` Means

`GoogleService-Info.plist` is the Firebase configuration file for an Apple app. After the Firebase project exists, Firebase asks for the iOS app bundle ID. For this app, enter:

```text
com.englishplus
```

Firebase then generates `GoogleService-Info.plist`. The file tells the iOS app which Firebase project to connect to. On the Mac, this file should be dragged into the Xcode app target, usually near the root of the app target.

For this repository:

- Documentation can mention the file name.
- The actual downloaded file should not be created here yet.
- The real file belongs to the future Xcode project setup step.

## Firebase Auth Strategy

### Phase 1 - TestFlight Internal Testing

Start with Firebase Auth email/password accounts because it is the fastest reliable path for TestFlight:

| Role | Example test account pattern | Purpose |
| --- | --- | --- |
| Student | `student.test01@example.test` | Mood check, daily mission, practice, help request |
| Teacher | `teacher.test01@example.test` | Class overview, student risk queue, feedback |
| Volunteer | `volunteer.test01@example.test` | Assigned support queue and replies |

These are examples only. Actual test accounts should be created in Firebase Auth later.

### Phase 2 - More Formal Login

After the TestFlight prototype is stable, add one or more formal identity routes:

- Google sign-in for easier teacher and volunteer login.
- Sign in with Apple if a wider iOS testing group needs it.
- School account integration only if the school has a real identity provider and can provide setup details.

### Role Model

Do not infer a user's role from the email address. Role and class membership should come from Firestore membership records, with custom claims used only for coarse access acceleration if needed.

Recommended role fields:

```json
{
  "uid": "firebase-auth-uid",
  "role": "student | teacher | volunteer",
  "classIds": ["YILAN-CHENGZHI-8A"],
  "active": true
}
```

Custom claims may later contain a small access-control summary:

```json
{
  "role": "teacher",
  "classIds": ["YILAN-CHENGZHI-8A"]
}
```

Keep student names, check-in history, support text, question attempts, and profile details in Firestore, not in custom claims.

## Firestore Collection Structure

Use Firebase Auth `uid` as the stable user identifier whenever possible. For demo data migrated from Android, keep the old local IDs only as `legacyAndroidId`.

```text
appConfig/public

users/{uid}

classes/{classId}
classes/{classId}/members/{uid}
classes/{classId}/students/{studentUid}
classes/{classId}/students/{studentUid}/checkIns/{dateKey}
classes/{classId}/students/{studentUid}/dailyMissions/{missionId}
classes/{classId}/students/{studentUid}/answerEvents/{eventId}
classes/{classId}/students/{studentUid}/learningEvents/{eventId}

classes/{classId}/supportThreads/{threadId}
classes/{classId}/supportThreads/{threadId}/messages/{messageId}

classes/{classId}/staffAssignments/{assignmentId}
classes/{classId}/questionBank/{questionId}
classes/{classId}/reports/{reportId}
classes/{classId}/syncQueue/{syncItemId}
```

Recommended first `classId`:

```text
YILAN-CHENGZHI-8A
```

## Document Shapes

### `users/{uid}`

```json
{
  "displayName": "Xiao An",
  "preferredName": "Xiao An",
  "primaryRole": "student",
  "createdAt": "serverTimestamp",
  "lastLoginAt": "serverTimestamp",
  "active": true
}
```

### `classes/{classId}/members/{uid}`

```json
{
  "uid": "firebase-auth-uid",
  "role": "student",
  "displayName": "Xiao An",
  "active": true,
  "joinedAt": "serverTimestamp"
}
```

Valid roles:

- `student`
- `teacher`
- `volunteer`

### `classes/{classId}/students/{studentUid}`

```json
{
  "uid": "student-auth-uid",
  "displayName": "Xiao An",
  "gradeBand": "junior-high",
  "classCode": "YILAN-CHENGZHI-8A",
  "currentLevel": "foundation",
  "recommendedTrack": "repair",
  "lastMoodScore": 3,
  "lastMissionStatus": "active",
  "lastActivityAt": "serverTimestamp",
  "riskLevel": "low",
  "legacyAndroidId": "xiao-an"
}
```

### `checkIns/{dateKey}`

Use `dateKey` format `yyyy-MM-dd`, for example `2026-06-10`.

```json
{
  "dateKey": "2026-06-10",
  "moodScore": 3,
  "availableTimeLevel": 4,
  "wantsChallenge": true,
  "preferredQuestionTypes": ["multipleChoice", "cloze", "translation"],
  "aiSummary": "Student is ready for a moderate challenge with short repair first.",
  "createdAt": "serverTimestamp"
}
```

### `dailyMissions/{missionId}`

```json
{
  "missionId": "2026-06-10-main",
  "dateKey": "2026-06-10",
  "sourceCheckInId": "2026-06-10",
  "status": "active",
  "track": "repair",
  "targetCorrectCount": 5,
  "correctCount": 2,
  "progressPercent": 40,
  "recommendedMinutes": 8,
  "questionPlan": [
    {
      "type": "multipleChoice",
      "difficulty": "foundation",
      "targetCorrect": 1
    },
    {
      "type": "cloze",
      "difficulty": "core",
      "targetCorrect": 2
    },
    {
      "type": "translation",
      "difficulty": "challenge",
      "targetCorrect": 2
    }
  ],
  "aiRationale": "Start with one confidence question, then move to cloze and translation.",
  "createdAt": "serverTimestamp",
  "completedAt": null
}
```

### `answerEvents/{eventId}`

```json
{
  "eventId": "uuid",
  "questionId": "q-000142",
  "missionId": "2026-06-10-main",
  "studentAnswer": "B",
  "isCorrect": false,
  "attemptNumber": 1,
  "aiExplanation": "The sentence needs a past-tense verb because yesterday marks past time.",
  "createdAt": "serverTimestamp"
}
```

### `supportThreads/{threadId}`

```json
{
  "threadId": "uuid",
  "studentUid": "student-auth-uid",
  "classId": "YILAN-CHENGZHI-8A",
  "status": "open",
  "reason": "stuck_on_question | emotional_support | reading_help | teacher_requested",
  "priority": "normal",
  "assignedToUid": "volunteer-or-teacher-uid",
  "assignedRole": "volunteer",
  "studentVisible": true,
  "latestMessagePreview": "I do not understand why this answer is wrong.",
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

### `supportThreads/{threadId}/messages/{messageId}`

```json
{
  "messageId": "uuid",
  "authorUid": "firebase-auth-uid",
  "authorRole": "student",
  "body": "I know the answer is not B, but I do not know why.",
  "visibility": "studentVisible",
  "createdAt": "serverTimestamp"
}
```

Allowed `visibility` values:

- `studentVisible`: the student, teacher, and assigned volunteer can read it.
- `staffOnly`: only teacher and assigned volunteer can read it.

### `questionBank/{questionId}`

```json
{
  "questionId": "q-000142",
  "level": "core",
  "type": "cloze",
  "skillTags": ["grammar", "past-tense"],
  "prompt": "Choose the best answer to complete the sentence.",
  "body": "I ___ my homework yesterday.",
  "choices": ["finish", "finished", "finishing", "will finish"],
  "answer": "finished",
  "explanation": "Use past tense with yesterday.",
  "reviewState": "approved",
  "source": {
    "kind": "internal-seed",
    "note": "Converted from Android seed data."
  },
  "updatedAt": "serverTimestamp"
}
```

## Access Rules By Role

### Student

Can:

- Read their own student profile.
- Create their own mood check-in.
- Read and update their own daily mission progress.
- Create their own answer events.
- Open support threads for themself.
- Read support messages visible to them.

Cannot:

- Read other students' mood, answers, missions, or support threads.
- Read staff-only notes.
- Edit question bank content.
- Read class-wide reports.

### Teacher

Can:

- Read class members, student profiles, check-ins, missions, answer events, and support threads for their assigned classes.
- Reply to student support threads.
- Write staff-only notes.
- Create and manage assignments.
- Edit question bank documents for their classes.
- Read reports for their classes.

Cannot:

- Access classes where they are not a member.
- Store production OpenRouter keys in Firestore.

### Volunteer

Can:

- Read only assigned students/support threads, or class data explicitly assigned by teacher.
- Reply to assigned support threads.
- Write staff-only progress notes on assigned support.

Cannot:

- Browse the whole class by default.
- Edit question bank content.
- Read class-wide reports unless a teacher later grants that ability.

## Backend Proxy Boundary

The iOS app must not hold the production OpenRouter API key.

Recommended route:

```text
iOS App -> Firebase Auth ID token -> Backend Proxy -> OpenRouter -> Backend Proxy -> iOS App
```

The backend proxy should:

- Verify Firebase Auth ID tokens.
- Check user role and class membership before generating AI responses.
- Apply rate limits per user and per class.
- Strip unnecessary student-identifying data before sending prompts.
- Store only useful summaries in Firestore, not raw private prompt logs.

## Draft Files Added In This Round

This round also adds:

- `firebase/firestore.rules.draft`
- `firebase/firestore.indexes.draft.json`

These are drafts for future Firebase setup. They should be reviewed and tested with Firebase Emulator Suite before any real student data is used.

Current Windows verification status:

- `firestore.indexes.draft.json` has been parsed as valid JSON locally.
- Firebase CLI is not installed on the current Windows machine, so `firestore.rules.draft` has not been emulator-validated yet.
- Treat the rules file as a careful access-control draft, not a deployed production rule set.

## Setup Order On Mac

1. Create Firebase project with display name `English+`, fallback `Englishplus`.
2. Use project ID `englishplus-testflight` if available.
3. Register an iOS app with bundle ID `com.englishplus`.
4. Download `GoogleService-Info.plist`.
5. Create the SwiftUI project in Xcode with bundle ID `com.englishplus`.
6. Add `GoogleService-Info.plist` to the Xcode app target.
7. Add Firebase Auth and Firestore SDKs.
8. Create initial Auth test users.
9. Create `classes/YILAN-CHENGZHI-8A` and member records.
10. Import seed question bank.
11. Apply and test Firestore rules in the emulator.
12. Only after testing, deploy rules/indexes to the Firebase project.

## References

- Firebase Apple setup: https://firebase.google.com/docs/ios/setup
- Firebase project identifiers and config files: https://firebase.google.com/docs/projects/learn-more
- Firestore security rules getting started: https://firebase.google.com/docs/firestore/security/get-started
- Firestore rules structure: https://firebase.google.com/docs/firestore/security/rules-structure
- Firebase Auth custom claims: https://firebase.google.com/docs/auth/admin/custom-claims
- Apple App ID registration: https://developer.apple.com/help/account/identifiers/register-an-app-id/
