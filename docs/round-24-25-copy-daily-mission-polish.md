# Round 24-25 Copy And Daily Mission Polish

## Goal

Round 24-25 finishes the first two polish rounds:

- remove internal implementation language from user-facing app surfaces;
- make the student daily mission progress belong only to assigned question practice.

## User-Facing Copy Cleanup

The app now avoids showing implementation details such as local database wording, endpoint wording, backup-mode wording, API/key wording, JSON/HTTP transport wording, and prototype-stage labels in normal screens.

The replacement language focuses on what users actually need:

- records are saved;
- class data can be updated;
- school accounts can be connected;
- AI support can use online feedback or built-in hints;
- teachers and volunteers can update handoff records.

## Daily Mission Progress

Daily mission progress now has one tested source:

- progress appears only when the student is inside an assigned daily question mission;
- progress is based only on correctly answered assigned questions;
- wrong answers keep the same progress and return the student to hints/retry;
- free practice never changes the daily mission progress;
- the completion screen explicitly says the daily mission is complete and offers optional self-practice.

## Tests Added

- `DailyMissionContract.progressCopy(...)` produces student-facing progress copy and hides progress outside daily missions.
- `UserVisibleCopyContract.audit(...)` catches internal implementation terms before they leak into user-facing copy.

## Verification

Targeted test:

```powershell
.\gradlew.bat testDebugUnitTest --tests tw.edu.citizenaction.soracompanion.model.DailyMissionContractTest --tests tw.edu.citizenaction.soracompanion.model.UserVisibleCopyContractTest --console=plain
```

Full verification for this round:

```powershell
.\gradlew.bat test --rerun-tasks --console=plain
.\gradlew.bat assembleDebug --console=plain
.\gradlew.bat lintDebug --console=plain
```
