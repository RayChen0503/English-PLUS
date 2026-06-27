# Round 8 - Xcode Development Handoff

This round is the Mac handoff guide for the teammate who will build the iOS version of English+. It assumes the teammate knows a little SwiftUI but still needs detailed steps.

## Confirmed Decisions

| Item | Decision |
| --- | --- |
| iOS Xcode project name | `EnglishPlus` |
| App display name | `English+` |
| Bundle ID | `com.englishplus` |
| Git branch | `main` only |
| GitHub workflow | Teammate is added as repository collaborator |
| Git tool | GitHub Desktop first, Terminal optional |
| Firebase | Include formal setup steps; first local build may use mock/local data until `GoogleService-Info.plist` is ready |
| First iOS scope | role choice, student home, mood check-in, daily mission, practice center, teacher home, volunteer home, local seed question bank |

## What This Round Does

This document tells the Mac teammate how to:

1. Prepare the Mac.
2. Clone the GitHub repository.
3. Create the Xcode SwiftUI project.
4. Use the correct project name and bundle ID.
5. Add Firebase SDKs when the config file is ready.
6. Build the first local iOS prototype with mock data.
7. Keep commits flowing back to GitHub on `main`.
8. Avoid common mistakes that would block TestFlight later.

## What This Round Does Not Do Yet

This round does not:

- Upload to TestFlight.
- Create App Store Connect app metadata.
- Deploy Firebase Cloud Functions.
- Deploy Firestore rules.
- Use a production OpenRouter key.

Those happen after Apple Developer enrollment is active and after the app can run locally in Xcode.

## Teammate Setup Checklist

### 1. Install Xcode

On the Mac:

1. Open the Mac App Store.
2. Search `Xcode`.
3. Install Xcode.
4. Open Xcode once after installation.
5. Let Xcode finish installing additional components.

Why: Xcode includes tools to develop, test, and distribute apps for Apple platforms, and includes Simulator for testing without a physical iPhone.

### 2. Install GitHub Desktop

1. Go to https://desktop.github.com/
2. Download GitHub Desktop for Mac.
3. Install it.
4. Sign in with the teammate's GitHub account.

The repository owner should add the teammate as a collaborator before she tries to push.

### 3. Accept GitHub Repository Invitation

The repository owner should:

1. Open the GitHub repository.
2. Go to `Settings`.
3. Go to `Collaborators`.
4. Invite the teammate's GitHub username or email.

The teammate should:

1. Open the invitation email or GitHub notification.
2. Accept the invitation.

This avoids fork confusion because the project decision is to work directly on `main`.

## Clone The Repository With GitHub Desktop

1. Open GitHub Desktop.
2. Choose `File > Clone Repository`.
3. Select the `URL` tab if the repository does not appear automatically.
4. Enter:

```text
https://github.com/RayChen0503/English-PLUS.git
```

5. Choose a local path, for example:

```text
~/Documents/English-PLUS
```

6. Click `Clone`.
7. Confirm the current branch is:

```text
main
```

If GitHub Desktop asks to fork the repository, that means the teammate probably does not have write access yet. Stop and ask the repository owner to add her as collaborator.

## Read Before Building

After cloning, read these documents in order:

```text
docs/ios-testflight/round-1-migration-master-spec.md
docs/ios-testflight/round-2-swiftui-screen-map.md
docs/ios-testflight/round-3-ios-data-format-spec.md
docs/ios-testflight/round-4-firebase-auth-firestore-schema.md
docs/ios-testflight/round-5-openrouter-cloud-functions-proxy.md
docs/ios-testflight/round-6-privacy-real-student-data-checklist.md
docs/ios-testflight/round-8-xcode-development-handoff.md
```

The most important one for screens is Round 2. The most important one for data models is Round 3.

## Create The Xcode Project

In Xcode:

1. Choose `Create New Project`.
2. Select `iOS`.
3. Select `App`.
4. Fill in:

| Xcode field | Value |
| --- | --- |
| Product Name | `EnglishPlus` |
| Team | leave blank until Apple Developer access is active, or select the Account Holder team if available |
| Organization Identifier | `tw.edu` |
| Bundle Identifier | `com.englishplus` |
| Interface | `SwiftUI` |
| Language | `Swift` |
| Storage | `None` for first local prototype |
| Include Tests | yes if comfortable; otherwise can add later |

Important:

- The Xcode product/project name should be `EnglishPlus`, without `+`.
- The app display name can still be `English+`.
- Bundle ID must be exactly `com.englishplus`.
- Do not use any other bundle ID.
- Do not use the Android package name for the iOS target.

If earlier migration notes mention a placeholder folder name such as `EnglishPlusIOS`, treat that as conceptual. The actual Xcode project name for this handoff is `EnglishPlus`.

## Where To Put The Xcode Project

Recommended folder:

```text
English-PLUS/
  ios/
    EnglishPlus/
      EnglishPlus.xcodeproj
      EnglishPlus/
```

If Xcode creates the project somewhere else, move it into:

```text
ios/EnglishPlus
```

Then commit that folder to GitHub.

## App Display Name

After the project exists:

1. Select the `EnglishPlus` project in Xcode.
2. Select the app target.
3. Open `Info`.
4. Set Bundle display name to:

```text
English+
```

If Xcode manages this through build settings, set:

```text
CFBundleDisplayName = English+
```

## First SwiftUI File Structure

Use this structure inside the Xcode target:

```text
EnglishPlus/
  App/
    EnglishPlusApp.swift
    AppState.swift
    AppRoute.swift
  Core/
    Models/
      UserRole.swift
      StudentProfile.swift
      Question.swift
      DailyMission.swift
      SupportThread.swift
    Services/
      AuthService.swift
      LocalSeedService.swift
      MissionEngine.swift
      AiProxyService.swift
      FirebaseClient.swift
    Theme/
      EPColors.swift
      EPTypography.swift
      EPSpacing.swift
  Features/
    Launch/
      RoleChoiceView.swift
      DemoLoginView.swift
      ConsentGateView.swift
    Student/
      StudentShellView.swift
      StudentHomeView.swift
      MoodCheckInView.swift
      DailyMissionView.swift
      PracticeCenterView.swift
      SupportView.swift
      LearningMapView.swift
    Teacher/
      TeacherShellView.swift
      TeacherHomeView.swift
      StudentQueueView.swift
      TeacherStudentDetailView.swift
    Volunteer/
      VolunteerShellView.swift
      VolunteerHomeView.swift
      AssignedSupportView.swift
  Resources/
    seed_questions.json
    seed_demo_users.json
```

Keep screens small. If a file gets too long, split it into subviews.

## First Local Prototype Scope

The first iOS build should work locally without Firebase:

1. Role choice screen.
2. Demo student login.
3. Demo teacher login.
4. Demo volunteer login.
5. Student mood check-in.
6. Student daily mission generated from local rule-based mock logic.
7. Practice center using local seed questions.
8. Teacher dashboard with mock assigned students.
9. Volunteer dashboard with mock assigned support queue.
10. Bottom navigation that does not show irrelevant internal/debug text.

The first iOS build does not need:

- Real Firebase Auth.
- Real Firestore sync.
- Real AI proxy.
- TestFlight upload.

But the code structure should leave clean service interfaces so Firebase and AI can be connected later.

## Firebase Setup Path

Firebase can be added as soon as the Firebase project and iOS app are ready.

### Firebase Decisions

| Item | Value |
| --- | --- |
| Firebase display name | `English+` |
| Fallback display name | `Englishplus` |
| Firebase project ID | `englishplus-testflight` |
| iOS Bundle ID | `com.englishplus` |
| Config file | `GoogleService-Info.plist` |

### Add Firebase App In Firebase Console

1. Open Firebase Console.
2. Create/select project `englishplus-testflight`.
3. Add Apple app.
4. Bundle ID:

```text
com.englishplus
```

5. Download:

```text
GoogleService-Info.plist
```

6. Put it in the root of the Xcode app target.

Do not rename it to:

```text
GoogleService-Info (2).plist
```

### Add Firebase SDKs In Xcode

1. Open Xcode project.
2. Go to `File > Add Packages`.
3. Enter:

```text
https://github.com/firebase/firebase-ios-sdk
```

4. Choose the default/latest version.
5. Add these products first:

```text
FirebaseAuth
FirebaseFirestore
FirebaseFunctions
FirebaseCore
```

Add later only if needed:

```text
FirebaseCrashlytics
FirebaseAnalytics
FirebaseAppCheck
```

### Configure Firebase In SwiftUI

Add a Firebase app delegate:

```swift
import FirebaseCore
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
```

Then attach it in `EnglishPlusApp.swift`:

```swift
import SwiftUI

@main
struct EnglishPlusApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RoleChoiceView()
        }
    }
}
```

If `GoogleService-Info.plist` is not ready yet, do not add Firebase code to the main app startup. Keep local/mock services active first.

## Service Interface Pattern

Use protocols so Firebase can be swapped in later:

```swift
protocol AuthProviding {
    var currentUser: DemoUser? { get }
    func signInDemo(role: UserRole) async throws -> DemoUser
}

protocol QuestionProviding {
    func loadQuestions() async throws -> [Question]
}

protocol MissionPlanning {
    func makeMission(from checkIn: MoodCheckIn, history: [AnswerEvent]) async throws -> DailyMission
}
```

First implementation:

```text
DemoAuthService
LocalSeedQuestionService
LocalMissionEngine
```

Later implementation:

```text
FirebaseAuthService
FirestoreQuestionService
CloudFunctionMissionEngine
```

## Student Flow To Build First

Build in this exact order:

1. `RoleChoiceView`
2. `DemoLoginView`
3. `ConsentGateView`
4. `StudentShellView`
5. `MoodCheckInView`
6. `DailyMissionView`
7. `PracticeCenterView`
8. `SupportView`
9. `LearningMapView`

Student flow rule:

```text
User chooses student -> signs in/demo login -> sees consent if needed -> mood check-in -> today's mission -> practice -> completion celebration -> optional free practice/support/map.
```

Do not show teacher/volunteer controls inside the student flow.

## Teacher Flow To Build First

Build in this order:

1. `TeacherShellView`
2. `TeacherHomeView`
3. `StudentQueueView`
4. `TeacherStudentDetailView`

Teacher flow rule:

```text
Teacher sees class overview -> priority students -> selected student detail -> can write feedback or assign volunteer support.
```

Do not show internal AI settings or backend implementation text to teachers.

## Volunteer Flow To Build First

Build in this order:

1. `VolunteerShellView`
2. `VolunteerHomeView`
3. `AssignedSupportView`

Volunteer flow rule:

```text
Volunteer sees assigned students/support threads only -> opens one assignment -> reads context -> writes helpful reply.
```

Do not show full class data to volunteers.

## Local Seed Data

Start with two resource files:

```text
seed_questions.json
seed_demo_users.json
```

Recommended minimum demo data:

```text
students: 3
teachers: 1
volunteers: 1
questions: 40 to 80 for first iOS local build
support threads: 3
daily mission examples: 3
```

Do not try to migrate all 1000+ Android questions on day one. First prove the SwiftUI flow works with a smaller clean seed set, then import the larger bank.

## GitHub Desktop Daily Workflow

At the start of each work session:

1. Open GitHub Desktop.
2. Select `English-PLUS`.
3. Make sure branch is `main`.
4. Click `Fetch origin`.
5. If there are remote changes, click `Pull origin`.

While working:

1. Make changes in Xcode.
2. Run in Simulator.
3. Save files.
4. Check GitHub Desktop changes.

Before committing:

1. Make sure the app builds.
2. Make sure the changed files are expected.
3. Write a short commit summary, for example:

```text
Add SwiftUI role choice and student shell
```

4. Click `Commit to main`.
5. Click `Push origin`.

If GitHub Desktop shows conflicts:

```text
Stop and ask before guessing.
```

## First Week Build Plan

### Day 1

- Install Xcode.
- Install GitHub Desktop.
- Clone repo.
- Create Xcode project under `ios/EnglishPlus`.
- Commit empty SwiftUI app.

### Day 2

- Add theme files.
- Add models.
- Add role choice and demo login.
- Commit.

### Day 3

- Add student shell.
- Add mood check-in.
- Add daily mission mock generation.
- Commit.

### Day 4

- Add practice center with local seed questions.
- Add answer feedback UI.
- Add mission completion celebration.
- Commit.

### Day 5

- Add teacher home and student queue.
- Add volunteer home and assigned support.
- Commit.

### Day 6

- Add Firebase package if `GoogleService-Info.plist` is ready.
- Keep local fallback if Firebase is not ready.
- Commit.

### Day 7

- Clean navigation.
- Test iPhone SE, iPhone 15/16 style simulator, and larger iPhone simulator.
- Fix visible text issues.
- Commit.

## Build Verification Checklist

Before saying the iOS prototype is ready for handoff back:

- App launches in Simulator.
- Role choice works.
- Student flow reaches daily mission.
- Student can answer at least 5 local questions.
- Correct/incorrect feedback is obvious.
- Mission completion state appears.
- Teacher view does not show student-only navigation.
- Volunteer view shows only assigned items.
- No debug/internal backend text is visible.
- App display name is `English+`.
- Bundle ID is `com.englishplus`.
- GitHub Desktop has pushed latest commit to `main`.

## Common Mistakes To Avoid

| Mistake | Why It Hurts |
| --- | --- |
| Project name includes `+` | May create awkward file/module names |
| Bundle ID differs from Firebase | Firebase config will not match |
| Work happens outside the repo folder | Changes will not be committed |
| Teammate works without collaborator access | Push may force a fork |
| Firebase is required before UI works | Blocks early progress |
| Real API key is put into Swift code | Unsafe and must not happen |
| Teacher/volunteer/student features mix together | Recreates the Android UX problem we just fixed |
| Large 1000+ question import happens before UI is stable | Makes debugging harder |

## When Apple Developer Enrollment Becomes Active

After Apple Developer is active:

1. Account Holder invites teammate to App Store Connect.
2. Teammate accepts invitation.
3. Xcode account can select the Developer Team.
4. Signing can be configured.
5. App Store Connect app can be created.
6. TestFlight upload can happen after the Round 8 signing, archive, and App Store Connect prerequisites are satisfied.

Until then, local Simulator development is enough.

## Sources

- Apple Xcode overview: https://developer.apple.com/xcode/
- Firebase Apple setup: https://firebase.google.com/docs/ios/setup
- GitHub Desktop clone workflow: https://docs.github.com/en/desktop/adding-and-cloning-repositories/cloning-and-forking-repositories-from-github-desktop
