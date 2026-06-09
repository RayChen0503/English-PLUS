# English+ Perfect Product Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raise English+ from a high-fidelity classroom prototype to the strongest launch-ready internal-test product this codebase can support.

**Architecture:** Stabilize the product by separating role flows, state, content, AI, persistence, synchronization, and release artifacts into explicit boundaries. Every round must preserve a runnable Android app, keep GitHub updated, and leave a verifiable rollback point.

**Tech Stack:** Native Android Kotlin, Android Views, Gradle, SQLite/local repositories, Firebase-ready auth/cloud interfaces, OpenRouter-ready AI client boundaries, JVM tests, Android lint.

---

## Non-Negotiable Completion Gate

Every round is incomplete until all of these are true:

- [ ] The round's user-facing flow has been walked through from entry to exit.
- [ ] Student, teacher, and volunteer access rules are checked when the round touches shared data or navigation.
- [ ] No user-facing debug labels, API setup details, prototype disclaimers, or internal architecture text appear in normal app screens.
- [ ] Duplicate bottom navigation, stale prototype cards, repeated question loops, and role-mixed actions are actively checked.
- [ ] Targeted tests are added or updated before production behavior is changed.
- [ ] Fresh verification passes:

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$env:PATH="$env:JAVA_HOME\bin;$env:PATH"
.\gradlew.bat test --rerun-tasks
.\gradlew.bat assembleDebug
.\gradlew.bat lintDebug
```

- [ ] `git status --short` is reviewed.
- [ ] The work is committed and pushed to GitHub.
- [ ] The completion report includes changed behavior, verification evidence, and commit hash.

## Rollback Protection

The current pre-rebuild baseline must be protected before any large changes:

- Existing tag: earlier preserved prototype baseline
- Required new tag: `pre-perfect-rebuild-2026-06-09`
- Protected baseline commit: `fe49a855b15def6c3eb7c1f0249958492232b7b9`

If a later round breaks the app beyond repair, restore from:

```powershell
git checkout main
git reset --hard pre-perfect-rebuild-2026-06-09
```

Only run the reset command when the user explicitly asks to roll back.

## Round 1: Architecture And State Boundaries

**Files:**
- Modify: `app/src/main/java/tw/edu/citizenaction/soracompanion/MainActivity.kt`
- Create or modify focused contracts under `app/src/main/java/tw/edu/citizenaction/soracompanion/model/`
- Test: `app/src/test/java/tw/edu/citizenaction/soracompanion/model/`

- [ ] Identify UI flow decisions currently embedded directly in `MainActivity.kt`.
- [ ] Move role routing, daily mission status, support-thread status, and bottom-nav rules into tested model contracts.
- [ ] Keep rendering behavior visually equivalent unless a flow bug is found.
- [ ] Add tests proving student, teacher, and volunteer state cannot cross into the wrong route.
- [ ] Verify the app still builds and existing flows still open.

## Round 2: Role Information Architecture

**Files:**
- Modify: `MainActivity.kt`
- Modify: `model/UserFlowContract.kt`
- Test: `model/UserFlowContractTest.kt`

- [ ] Student first sees role choice, then student login, then check-in or free-practice path.
- [ ] Teacher first sees class priority, student roster, handoff, question bank, and reports.
- [ ] Volunteer first sees handoff queue, script, assigned students, and sync status.
- [ ] Teacher-only functions are not shown to volunteers.
- [ ] Volunteer-only helper language is not shown to teachers.

## Round 3: Student Daily Mission Flow

**Files:**
- Modify: `MainActivity.kt`
- Modify: `model/DailyMissionContract.kt` or create it if missing.
- Test: `model/DailyMissionContractTest.kt`

- [ ] The four-question check-in creates one clear daily mission.
- [ ] The mission progress bar counts only correctly completed assigned practice items.
- [ ] Wrong answers do not increase mission progress.
- [ ] The old check-in progress card is removed from student screens.
- [ ] Completion produces a clear reward/finish state and then offers optional free practice.

## Round 4: Formal Question Bank

**Files:**
- Modify: question bank model and seed data under `data/`, `model/`, or `storage/`
- Test: question bank tests

- [ ] Question items include type, CEFR-like level, exam difficulty, skill, source label, and unit tags.
- [ ] Practice sessions avoid immediate repetition.
- [ ] Daily missions draw from the user's selected type preferences and challenge willingness.
- [ ] Harder students can select harder sections.
- [ ] Basic students still have accessible entry-level items.

## Round 5: AI Product Workflow

**Files:**
- Modify: `ai/`
- Modify: student feedback, support, and teacher summary flows
- Test: AI routing/model contract tests

- [ ] AI setup/internal key details are removed from normal user screens.
- [ ] If a real AI key/proxy is configured, daily mission generation can use it.
- [ ] If AI is unavailable, local fallback is clearly useful but not advertised as fake AI.
- [ ] Wrong-answer explanations use AI or the fallback explanation engine.
- [ ] Teacher summaries use AI when available and degrade gracefully when offline.

## Round 6: Production-Grade Login Boundary

**Files:**
- Modify: `auth/`
- Modify: account center and login screens
- Test: auth contract tests

- [x] Demo accounts remain available for classroom testing.
- [x] Firebase/Google/school auth boundary is explicit and ready for real credentials.
- [x] Roles are assigned by account claims or local demo profile, not loose UI text.
- [x] The UI does not expose implementation details.

## Round 7: Cloud Data And Sync

**Files:**
- Modify: `cloud/`, `storage/`, `data/`
- Test: cloud/sync contract tests

- [x] Local SQLite remains the offline source of truth.
- [x] Sync queue has retry, conflict, and last-success state.
- [x] Student help requests, replies, learning events, and mission completions can map to cloud payloads.
- [x] Network unavailable states are readable and actionable.

## Round 8: Student-Teacher Closed Loop

**Files:**
- Modify: collaboration contracts and UI
- Test: collaboration flow tests

- [x] Student help requests appear in teacher queue.
- [x] Teachers can write custom replies.
- [x] Students see teacher replies in the correct support thread.
- [x] Status moves from pending to replied/read without duplicate cards.
- [x] Teacher and volunteer queues do not overwrite each other's meaning.

## Round 9: Volunteer Handoff System

**Files:**
- Modify: handoff board and mentor script flows
- Test: volunteer workflow tests

- [x] Volunteers see only support/handoff work, not teacher admin tools.
- [x] Each volunteer action has a next step, script, and completion state.
- [x] Handoff notes are visible to teachers but do not become student-facing unless intended.

## Round 10: Teacher Workspace

**Files:**
- Modify: teacher dashboard, roster, report, and question bank screens
- Test: teacher workflow tests

- [x] Teacher home prioritizes class risk and next action.
- [x] Student detail shows progress, help requests, recent answers, and teacher reply actions.
- [x] Reports and question bank are reachable but not mixed with volunteer scripts.

## Round 11: Reports And Export

**Files:**
- Modify: report/export contracts
- Test: report/export tests

- [x] Student report, class report, and pilot report are separate.
- [x] Exported text is polished and does not include internal prototype labels.
- [x] PDF/Word-ready content boundaries are prepared even if final renderer stays local.

## Round 12: Design System Hardening

**Files:**
- Modify: `ui/`
- Modify: shared button/card/bottom-nav rendering
- Test: model-level layout rules where possible

- [x] One bottom navigation bar per screen.
- [x] Buttons have consistent hierarchy.
- [x] Cards use consistent spacing, border, color, and typography.
- [x] Mobile screens avoid text overflow on common emulator sizes.
- [x] Success, loading, empty, and error states are visually consistent.

## Round 13: Safety, Privacy, And Data Governance

**Files:**
- Modify: docs, auth/cloud contracts, report text
- Test: privacy/safety guardrail tests

- [x] Student emotional-support data is treated as sensitive.
- [x] No public ranking language is shown.
- [x] Data deletion/export policy copy is prepared.
- [x] API keys are not committed.
- [x] Firebase/security rules requirements are documented.

## Round 14: Full QA

**Files:**
- Modify tests and QA docs

- [x] Run student happy path, free-practice path, support path, teacher path, and volunteer path.
- [x] Capture issues and fix all high-impact ones found.
- [x] Run full Gradle verification.
- [x] Confirm GitHub status is clean after push.

## Round 15: Store/Internal-Test Readiness

**Files:**
- Modify: README, release docs, Gradle release metadata if needed

- [x] Prepare AAB/APK instructions.
- [x] Prepare Play Console internal-test checklist.
- [x] Prepare app description, privacy copy, and screenshot plan.
- [x] Confirm what still needs external credentials or accounts.
