# Rounds 14-15 - Full QA And Internal-Test Readiness

This round moves English+ from feature-complete local prototype toward an internal-test candidate. It does not claim that Firebase, a production backend, or Play Console credentials are already connected.

## Round 14 Full QA Matrix

The required QA paths are now represented in `ValidationContract.fullQaMatrix()`:

1. `student-happy-path`
   - Role choice and student login.
   - Four-question check-in.
   - Daily mission.
   - Practice answer feedback.
   - Mission completion encouragement.

2. `student-free-practice`
   - Student opens practice center without being forced through check-in.
   - Chooses level or question type.
   - Answers one item.
   - Can move to support or map without losing context.

3. `student-support-path`
   - Student opens support center.
   - Sends a low-pressure help request.
   - Sees teacher reply thread.
   - Returns to one small practice item.

4. `teacher-path`
   - Teacher opens class priority dashboard.
   - Reviews roster and student detail.
   - Replies or reviews pending help.
   - Opens question bank and class report.

5. `volunteer-path`
   - Volunteer opens handoff queue.
   - Reviews one student request.
   - Uses mentor script.
   - Leaves internal handoff note.
   - Returns to volunteer home.

Each path is expected to avoid internal copy, duplicate bottom navigation, and role-mixed actions.

## High-Impact Issue Gate

`ValidationContract.fullQaCompletionGate()` blocks completion if:

- Required role flows were not walked.
- Any high-impact issue remains open.
- Full Gradle verification has not passed.
- GitHub status is not clean after push.

## Round 15 Build Artifact Instructions

Use these commands from `D:\SoraCompanion`:

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$env:PATH="$env:JAVA_HOME\bin;$env:PATH"
.\gradlew.bat :app:assembleDebug --console=plain
.\gradlew.bat :app:assembleRelease --console=plain
.\gradlew.bat :app:bundleRelease --console=plain
```

Expected artifacts:

- Debug APK: `app/build/outputs/apk/debug/app-debug.apk`
- Unsigned release APK: `app/build/outputs/apk/release/app-release-unsigned.apk`
- Release AAB: `app/build/outputs/bundle/release/app-release.aab`

The AAB still requires a real release keystore before Play Console upload.

## Play Console Internal-Test Checklist

Before an internal-test upload, prepare:

- Signed Android App Bundle.
- Internal tester email list.
- Privacy policy URL.
- Data Safety draft.
- App description.
- Student, teacher, and volunteer screenshots.
- Release notes.
- Contact email.

## Screenshot And Recording Plan

Use role-specific folders and filenames:

```text
student/student_01_login.png
student/student_02_check_in.png
student/student_03_daily_mission.png
student/student_04_answer_feedback.png
student/student_05_support_thread.png
teacher/teacher_01_home.png
teacher/teacher_02_roster.png
teacher/teacher_03_student_detail.png
teacher/teacher_04_report.png
volunteer/volunteer_01_home.png
volunteer/volunteer_02_handoff_queue.png
volunteer/volunteer_03_mentor_script.png
```

Videos should show actual use, not just the login screen:

- Student: one video for check-in to daily mission completion, one video for free practice and support.
- Teacher: priority dashboard to reply/report.
- Volunteer: handoff queue to script and internal note.

## External Gaps That Still Need Real Credentials Or Deployment

These items are not completed by local code changes:

- Firebase Auth or school account integration.
- `google-services.json`.
- Secure AI backend proxy.
- Release signing keystore.
- Public privacy policy URL.
- Formal question bank license and content source.

These gaps are tracked in `StoreReleaseContract.externalCredentialGaps()` so later work can separate "Codex can implement now" from "user/school must provide credentials or decisions."
