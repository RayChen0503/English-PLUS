# English+ Android-To-iOS Data Format Spec

Last updated: 2026-06-10
Round: 3 of 8
Status: Windows-side iOS data handoff
Depends on:
- `round-1-migration-master-spec.md`
- `round-2-swiftui-screen-map.md`

## 1. Purpose

This document defines how the current Android prototype data should become iOS-ready data for the future SwiftUI/TestFlight app.

The iOS app should not copy Android Kotlin classes directly. It should consume stable, platform-neutral data contracts:

- JSON seed files for first-run local data.
- Swift `Codable` models with stable English field names.
- Firestore documents for cloud sync after Firebase setup.
- Explicit role and visibility rules so student, teacher, and volunteer data do not mix.

The immediate Mac/Xcode phase can start with bundled JSON seed files, then connect those same shapes to Firebase later.

## 2. Source Data Inventory

| Android source | Data represented | iOS target |
| --- | --- | --- |
| `Models.kt` | Role, question, student profile, support note, mission state | Swift `Codable` models |
| `PrototypeRepository.kt` | Seed question bank, accounts, tasks, support options, demo roster | Bundled JSON seed files |
| `EnglishPlusDatabase.kt` | SQLite tables for state, events, accounts, notes, sync items, question bank | Firestore collections plus optional local cache |
| `DailyMissionContract.kt` | Daily mission progress rules | Swift mission service rules |
| `QuestionBankContract.kt` | Question bank schema, level/type filtering, review state | Question bank JSON and Firestore schema |
| `CloudDataContract.kt` | Cloud collection names, write scopes, payload shapes | Firebase schema and security rules |
| `CollaborationFlowContract.kt` | Help requests, staff replies, student-visible timeline | Support thread collections |
| `CollaborationSyncContract.kt` | Collaboration merge and conflict behavior | Firestore sync conflict rules |
| `AiLearningPlanContract.kt` | Daily mission AI request/response shape | AI proxy request/response schema |

## 3. Data Packaging Strategy

Use three layers:

1. Bundled seed data
   - Stored in the iOS app bundle under `Resources/SeedData/`.
   - Used for the first TestFlight build, offline demo, and local UI development.
   - Must not include real sensitive student records.

2. Local runtime cache
   - Stored on device after decoding seed or Firestore data.
   - Suggested iOS options: SwiftData, SQLite, or simple file cache for the first prototype.
   - Cache is a convenience layer, not the source of truth once Firestore is active.

3. Firestore source of truth
   - Used after Firebase Auth and Firestore are configured.
   - Stores real users, class membership, student progress, mission records, support threads, staff replies, and approved question bank items.

Recommended first iOS build order:

```text
Seed JSON -> Swift Codable models -> ViewModels -> SwiftUI screens
```

Recommended cloud build order:

```text
Firestore documents -> Repository layer -> same Swift Codable models -> ViewModels
```

## 4. Folder Layout For iOS Seed Data

```text
EnglishPlusIOS/
  EnglishPlusIOS/
    Resources/
      SeedData/
        seed_manifest.json
        roles_seed.json
        accounts_seed.json
        question_bank_seed.json
        daily_mission_rules_seed.json
        support_options_seed.json
        demo_roster_seed.json
        staff_scripts_seed.json
```

`seed_manifest.json` should describe all bundled seed files:

```json
{
  "app": "English+",
  "seedSchemaVersion": 1,
  "generatedFrom": "Android prototype 0.7.0",
  "generatedAt": "2026-06-10T00:00:00Z",
  "files": [
    "roles_seed.json",
    "accounts_seed.json",
    "question_bank_seed.json",
    "daily_mission_rules_seed.json",
    "support_options_seed.json",
    "demo_roster_seed.json",
    "staff_scripts_seed.json"
  ]
}
```

## 5. Role And Account Data

### Role Enum

Use stable IDs internally:

| Role ID | User-facing label | Meaning |
| --- | --- | --- |
| `student` | 學生 | Student learning track |
| `teacher` | 老師 | Class triage, student detail, reply, report |
| `volunteer` | 志工 | Assigned support and companionship track |

Do not use Android's old `Mentor` role in the iOS data model. If imported, map it to `volunteer`.

### Swift Model

```swift
enum UserRole: String, Codable, CaseIterable {
    case student
    case teacher
    case volunteer
}

struct AppUserProfile: Codable, Identifiable {
    let id: String
    let displayName: String
    let role: UserRole
    let classId: String
    let groupId: String?
    let consentStatus: ConsentStatus
    let isDemo: Bool
    let createdAt: Date
    let updatedAt: Date
}
```

### Seed Example

```json
{
  "schemaVersion": 1,
  "accounts": [
    {
      "id": "student-xiao-an",
      "displayName": "小安",
      "role": "student",
      "classId": "YILAN-CHENGZHI-8A",
      "groupId": null,
      "consentStatus": "demo",
      "isDemo": true
    },
    {
      "id": "volunteer-emily",
      "displayName": "Emily",
      "role": "volunteer",
      "classId": "YILAN-CHENGZHI-8A",
      "groupId": "MENTOR-GROUP-A",
      "consentStatus": "demo",
      "isDemo": true
    },
    {
      "id": "teacher-lin",
      "displayName": "林老師",
      "role": "teacher",
      "classId": "YILAN-CHENGZHI-8A",
      "groupId": null,
      "consentStatus": "demo",
      "isDemo": true
    }
  ]
}
```

### Firestore Target

```text
users/{uid}
classes/{classId}/members/{uid}
```

`users/{uid}` should store identity-level fields. `classes/{classId}/members/{uid}` should store class membership and role-scoped access.

## 6. Question Bank Data

The Android app currently has a 1,000+ item question bank. iOS should receive it as a structured seed file, not as hard-coded Swift arrays.

### Question Type IDs

Use stable English IDs and separate Traditional Chinese labels:

| Type ID | Label | Android equivalent |
| --- | --- | --- |
| `choice` | 選擇題 | 選擇題 |
| `fillBlank` | 填空題 | 填空題 |
| `cloze` | 克漏字 | 克漏字 |
| `reading` | 閱讀理解 | 閱讀理解 |
| `translation` | 翻譯/句子重組 | 翻譯/句子重組 |

### Difficulty Levels

Use CEFR-like levels already present in Android metadata:

```text
A1, A2, B1, B2
```

For UI grouping, map them to:

| Level | UI group |
| --- | --- |
| `A1` | 入門 |
| `A2` | 基礎 |
| `B1` | 會考核心 |
| `B2` | 挑戰 |

### Swift Model

```swift
struct QuestionBankItem: Codable, Identifiable {
    let id: String
    let level: QuestionLevel
    let unit: String
    let skill: String
    let source: String
    let reviewState: ReviewState
    let importBatchId: String
    let updatedAt: Date
    let question: Question
}

struct Question: Codable {
    let prompt: String
    let type: QuestionType
    let options: [String]
    let answer: String
    let acceptedAnswers: [String]
    let explanation: String
    let concept: String
    let repairHint: String
}
```

### JSON Shape

```json
{
  "questionBankSchemaVersion": 5,
  "app": "English+",
  "items": [
    {
      "id": "cap-style-0001",
      "level": "A1",
      "unit": "基礎文法",
      "skill": "主詞搭配",
      "source": "English+ seed",
      "reviewState": "approved",
      "importBatchId": "seed",
      "updatedAt": "2026-06-10T00:00:00Z",
      "question": {
        "prompt": "He ___ a student.",
        "type": "choice",
        "options": ["am", "is", "are", "be"],
        "answer": "is",
        "acceptedAnswers": ["is"],
        "explanation": "He 是第三人稱單數，be 動詞要用 is。",
        "concept": "He / She / It + is",
        "repairHint": "先看主詞 He，再選 is。"
      }
    }
  ]
}
```

### Import Rules

- `id` must be stable across Android, iOS, and Firestore.
- `prompt` must be unique within a session candidate list.
- `reviewState` values are `draft`, `approved`, `archived`.
- Students can read only approved or locally bundled items.
- Teachers can publish or archive question-bank items after Firestore rules are active.
- Volunteers cannot manage the question bank.
- Public exam or web-sourced items must keep a source/license note before public use.

### Session Selection Rules

The iOS practice selector should preserve the Android behavior:

- Prefer selected question types from check-in or practice filters.
- Avoid recently seen prompts.
- Use lower levels first when the student is low-pressure or not challenging.
- Use higher levels earlier when `challengeWanted == true`.
- Fall back to all available types only if the selected type has no items.
- Daily mission takes exactly the assigned goal when possible.
- Free practice may use longer sessions but must not change daily mission progress.

## 7. Check-In And Daily Mission Data

### Check-In Model

```swift
struct StudentCheckIn: Codable, Identifiable {
    let id: String
    let studentId: String
    let classId: String
    let dateKey: String
    let moodScale: Int
    let timeScale: Int
    let minutes: Int
    let challengeWanted: Bool
    let preferredQuestionTypes: [QuestionType]
    let createdAt: Date
}
```

### Check-In Rules

| Input | Valid range | Mapping |
| --- | --- | --- |
| `moodScale` | 1 to 5 | 1-2 low, 3-4 stable, 5 good |
| `timeScale` | 1 to 5 | 1-2 = 3 minutes, 3 = 5 minutes, 4 = 8 minutes, 5 = 12 minutes |
| `challengeWanted` | true/false | Controls difficulty weighting |
| `preferredQuestionTypes` | 1 or more types | Controls mission candidate pool |

The app should ask time only once during check-in.

### Daily Mission Plan

```swift
struct DailyMissionPlan: Codable, Identifiable {
    let id: String
    let studentId: String
    let classId: String
    let dateKey: String
    let route: MissionRoute
    let questionGoal: Int
    let recommendedTypes: [QuestionType]
    let assignedQuestionIds: [String]
    let studentMessage: String
    let source: MissionPlanSource
    let createdAt: Date
}
```

### Mission Route Values

| Route ID | Label | When used |
| --- | --- | --- |
| `repair` | 低壓修復 | Low mood, short time, or no challenge |
| `steady` | 穩定練習 | Middle state and normal practice |
| `challenge` | 挑戰暖身 | Good state and challenge wanted |

### Goal Rules

| Minutes | Goal |
| --- | --- |
| 1-3 | 1 question |
| 4-5 | 2 questions |
| 6-8 | 3 questions |
| 9+ | 4 questions |

This is a question goal, not a total task checklist. Mood check-in and support messages do not count toward mission progress.

### Mission Progress

```swift
struct MissionProgress: Codable {
    let missionId: String
    let goal: Int
    let correctCount: Int
    let attemptedQuestionIds: [String]
    let correctQuestionIds: [String]
    let incorrectQuestionIds: [String]
    let isComplete: Bool
    let completedAt: Date?
}
```

Progress update rule:

```text
if answer.isCorrect:
    correctCount = min(correctCount + 1, goal)
else:
    correctCount is unchanged
isComplete = correctCount >= goal
```

## 8. Answer And Learning Event Data

### Answer Event

```swift
struct AnswerEvent: Codable, Identifiable {
    let id: String
    let studentId: String
    let classId: String
    let questionId: String
    let missionId: String?
    let sessionType: PracticeSessionType
    let selectedAnswer: String
    let isCorrect: Bool
    let concept: String
    let questionType: QuestionType
    let level: QuestionLevel
    let createdAt: Date
}
```

`sessionType` values:

- `dailyMission`
- `freePractice`
- `repairPractice`

Daily mission progress updates only when `sessionType == dailyMission` and `isCorrect == true`.

### Learning Event

Use learning events for timeline/report summaries:

```swift
struct LearningEvent: Codable, Identifiable {
    let id: String
    let studentId: String
    let classId: String
    let type: LearningEventType
    let title: String
    let detail: String
    let sourceId: String?
    let createdAt: Date
}
```

`LearningEventType` values:

- `checkInCompleted`
- `missionCreated`
- `questionAnswered`
- `missionCompleted`
- `supportRequested`
- `staffReplyRead`

## 9. Support And Collaboration Data

### Support Option Seed

```json
{
  "schemaVersion": 1,
  "supportOptions": [
    {
      "id": "question-meaning",
      "reason": "我看不懂這題",
      "studentText": "我不知道這題在問什麼。",
      "platformAction": "English+ 先把題目拆成一句話。",
      "route": "aiCoach"
    },
    {
      "id": "human-company",
      "reason": "我想要有人陪我",
      "studentText": "我知道答案好像不對，但不知道差在哪裡。",
      "platformAction": "系統會整理給老師或志工。",
      "route": "humanHandoff"
    }
  ]
}
```

Route values:

| Route | Meaning |
| --- | --- |
| `aiCoach` | Built-in or AI repair support |
| `humanHandoff` | Teacher/volunteer support |
| `readingBreakdown` | Reading-specific breakdown |
| `recovery` | Low-pressure recovery route |

### Support Thread Model

```swift
struct SupportThread: Codable, Identifiable {
    let id: String
    let classId: String
    let studentId: String
    let reason: String
    let route: SupportRoute
    let status: SupportThreadStatus
    let createdAt: Date
    let updatedAt: Date
    let closedAt: Date?
}
```

`SupportThreadStatus` values:

- `open`
- `waitingForStaff`
- `replied`
- `readByStudent`
- `closed`

### Support Message Model

```swift
struct SupportMessage: Codable, Identifiable {
    let id: String
    let threadId: String
    let classId: String
    let studentId: String
    let actorId: String
    let actorRole: UserRole
    let body: String
    let visibility: MessageVisibility
    let messageType: SupportMessageType
    let createdAt: Date
}
```

Visibility values:

- `studentVisible`
- `staffOnly`

Message type values:

- `studentRequest`
- `aiSuggestion`
- `teacherReply`
- `volunteerReply`
- `staffNote`
- `systemStatus`

### Duplicate Request Rule

The Android prototype prevents duplicate open requests for the same unresolved reason. Preserve that in iOS:

```text
studentId + normalized(reason) can have only one open or waitingForStaff thread.
```

If a student asks for the same unresolved reason again, route them to the existing thread instead of creating a duplicate.

### Student Visibility Rule

Student support timeline includes:

- the student's own request;
- teacher replies marked `studentVisible`;
- volunteer replies marked `studentVisible`;
- AI repair suggestions meant for the student.

Student support timeline must not include:

- staff-only notes;
- internal handoff notes;
- sync/debug records;
- teacher-only risk labels.

## 10. Teacher And Volunteer Data

### Roster Row

```swift
struct StudentRosterRow: Codable, Identifiable {
    let id: String
    let studentId: String
    let displayName: String
    let classId: String
    let riskLevel: RiskLevel
    let currentIssue: String
    let statusSummary: String
    let pendingHelpCount: Int
    let lastActivityAt: Date?
}
```

`RiskLevel` values:

- `low`
- `medium`
- `high`

### Staff Assignment

```swift
struct StaffAssignment: Codable, Identifiable {
    let id: String
    let classId: String
    let studentId: String
    let assignedToUserId: String
    let assignedRole: UserRole
    let title: String
    let contextSummary: String
    let nextAction: String
    let priority: RiskLevel
    let status: StaffAssignmentStatus
    let createdAt: Date
    let updatedAt: Date
}
```

`StaffAssignmentStatus` values:

- `pending`
- `inProgress`
- `completed`
- `escalated`

Teacher can see class-level assignments. Volunteer can see only assignments explicitly assigned to them or their group.

## 11. Offline Sync Data

### Sync Queue Item

```swift
struct SyncQueueItem: Codable, Identifiable {
    let id: String
    let collectionPath: String
    let documentId: String
    let operation: SyncOperation
    let payload: [String: JSONValue]
    let attemptCount: Int
    let status: SyncStatus
    let lastError: String?
    let updatedAt: Date
}
```

`SyncStatus` values:

- `pending`
- `retry`
- `blocked`
- `synced`

Retry rule:

- retry after 30 seconds, 60 seconds, 120 seconds, then at most 300 seconds;
- after 3 failed attempts, mark as `blocked`;
- normal user screens should say "資料稍後補傳" instead of showing technical errors.

## 12. Firestore Collection Mapping

Round 4 will define the full Firebase schema and rules. Round 3 establishes the data mapping:

```text
classes/{classId}
classes/{classId}/members/{uid}
classes/{classId}/students/{studentId}
classes/{classId}/students/{studentId}/checkIns/{dateKey}
classes/{classId}/students/{studentId}/dailyMissions/{missionId}
classes/{classId}/students/{studentId}/answerEvents/{eventId}
classes/{classId}/students/{studentId}/learningEvents/{eventId}
classes/{classId}/supportThreads/{threadId}
classes/{classId}/supportThreads/{threadId}/messages/{messageId}
classes/{classId}/staffAssignments/{assignmentId}
classes/{classId}/questionBank/{questionId}
classes/{classId}/reports/{reportId}
```

## 13. Android Export To iOS Seed Mapping

| Android field | iOS field | Notes |
| --- | --- | --- |
| `LocalAccount.displayName` | `AppUserProfile.displayName` | Demo only until Firebase Auth is active |
| `LocalAccount.roleLabel` | `AppUserProfile.role` | Normalize to `student`, `teacher`, `volunteer` |
| `LocalAccount.classCode` | `classId` | Use uppercase stable class ID |
| `QuestionBankItem.id` | `QuestionBankItem.id` | Keep stable |
| `QuestionBankItem.level` | `QuestionBankItem.level` | A1/A2/B1/B2 |
| `QuestionBankItem.unit` | `unit` | User-facing category |
| `QuestionBankItem.skill` | `skill` | Report and recommendation grouping |
| `QuestionBankItem.source` | `source` | Required for license review |
| `Question.prompt` | `question.prompt` | Must be clean visible text |
| `Question.options` | `question.options` | Empty array allowed for non-choice input |
| `Question.answer` | `question.answer` | Canonical answer |
| `Question.explanation` | `question.explanation` | Student-facing explanation |
| `Question.concept` | `question.concept` | Teacher/report grouping |
| `Question.type` | `question.type` | Convert label to stable type ID |
| `Question.repairHint` | `question.repairHint` | Student-facing hint |
| `CollaborationNote.actor` | `SupportMessage.actorId/displayName` | Use UID when Firebase exists |
| `CollaborationNote.role` | `SupportMessage.actorRole` | Normalize role |
| `CollaborationNote.target` | `studentId` | Convert display name to stable student ID |
| `CollaborationNote.note` | `SupportMessage.body` | Student-visible only if visibility allows |
| `CollaborationNote.status` | `SupportThread.status` or `SupportMessage.messageType` | Replace old status labels with stable enum |

## 14. Clean Text And Encoding Rules

The current Android codebase has some historical mojibake in older source files. The iOS migration must not import those corrupted strings.

Rules:

- Prefer clean text from latest product docs, seed repository sections, and UI tests.
- Use stable enum IDs for logic; use Traditional Chinese only for visible labels and content.
- Reject any seed item containing replacement artifacts such as `?`, `�`, or broken punctuation sequences.
- Keep a seed validation script in the Mac phase before importing question data.
- If a question has corrupted prompt/options/explanation, exclude it until repaired.

Suggested validation checks:

```text
question.id is not empty
question.prompt is not empty
question.answer is not empty
question.type is one of allowed type IDs
question.level is A1/A2/B1/B2
visible text does not contain mojibake markers
choice questions have at least 2 options
approved items have source/license text
```

## 15. Recommended Swift Decoding Pattern

```swift
protocol SeedLoadable: Decodable {
    static var seedFileName: String { get }
}

struct SeedLoader {
    func load<T: SeedLoadable>(_ type: T.Type) throws -> T {
        guard let url = Bundle.main.url(
            forResource: T.seedFileName,
            withExtension: "json",
            subdirectory: "SeedData"
        ) else {
            throw SeedError.fileNotFound(T.seedFileName)
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}
```

## 16. Round 3 Self-Review

- Role IDs are stable and not tied to Android labels.
- Question bank format preserves level, unit, skill, source, review state, prompt, answers, explanations, and repair hints.
- Daily mission progress is stored separately from free practice.
- Support messages separate student-visible replies from staff-only notes.
- Firestore paths are introduced as mapping targets, while full security rules are deferred to Round 4.
- The spec warns against importing Android mojibake strings into iOS seed data.
- The Mac/Xcode phase can start with JSON seed files before Firebase is ready.
