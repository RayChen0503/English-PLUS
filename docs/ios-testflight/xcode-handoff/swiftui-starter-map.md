# SwiftUI Starter Map

This is a compact starter map for the teammate building English+ in Xcode.

## App Root

```text
EnglishPlusApp
  AppState
  RoleChoiceView
```

`AppState` should hold:

```text
selectedRole
currentUser
hasAcceptedConsent
currentStudentMission
```

## Role Choice

```text
RoleChoiceView
  Student button
  Teacher button
  Volunteer button
```

After role selection:

```text
DemoLoginView
```

## Student

```text
StudentShellView
  StudentHomeView
  MoodCheckInView
  DailyMissionView
  PracticeCenterView
  SupportView
  LearningMapView
```

Student navigation:

```text
Home -> Mood Check-In -> Daily Mission -> Practice -> Completion
```

After mission completion:

```text
Free Practice
Support
Learning Map
```

## Teacher

```text
TeacherShellView
  TeacherHomeView
  StudentQueueView
  TeacherStudentDetailView
```

Teacher navigation:

```text
Today -> Students -> Support -> Reports
```

## Volunteer

```text
VolunteerShellView
  VolunteerHomeView
  AssignedSupportView
```

Volunteer navigation:

```text
Today -> Assigned Students -> Reply Support
```

## Reusable Components

Create reusable views:

```text
PrimaryButton
RoleCard
MissionProgressBar
QuestionCard
AnswerFeedbackBanner
SupportThreadCard
StudentRiskBadge
```

## Visual Rules

- Keep screens action-first.
- Do not show internal backend or AI settings to normal users.
- Keep student, teacher, and volunteer navigation separate.
- Use one clear next action per screen.
- Make correct/incorrect answer feedback obvious.
- Show daily mission completion with a clear celebration state.

## Data Rules

Use local data first:

```text
seed_questions.json
seed_demo_users.json
```

Add Firebase later behind service protocols.
