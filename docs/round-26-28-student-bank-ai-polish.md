# Round 26-28 Student Mission, Question Bank, And AI Polish

## Goal

Round 26-28 continues the product-readiness polish after the copy and daily progress cleanup:

- stabilize the student daily mission flow;
- rebuild the formal question bank seed data with clean Traditional Chinese labels and enough item volume;
- keep AI support useful without exposing setup or credential details on normal user screens.

## Round 26: Student Daily Mission Flow

- Daily mission progress copy now comes from one tested contract.
- Progress remains tied only to assigned daily questions.
- Wrong answers do not advance the mission.
- Completion copy clearly tells the student that today's question mission is complete.
- Check-in, role, bottom navigation, support-route, and question-type labels were restored to clean user-facing Traditional Chinese.

## Round 27: Formal Question Bank

- The seed repository was rebuilt to remove mojibake text from student-facing content.
- The practice bank now contains more than 1,000 unique prompts.
- Each current practice mode has at least 180 items:
  - 選擇題
  - 填空題
  - 克漏字
  - 閱讀理解
  - 翻譯/句子重組
- Question metadata now keeps level, unit, skill, source, review state, and stable IDs.
- Session selection continues to avoid recently seen prompts before falling back to repeated material.

## Round 28: AI Product Workflow

- AI local daily mission planning now returns clean route labels, recommended types, and student messages.
- OpenRouter request/parse fallback copy was cleaned so empty or partial model responses still produce usable feedback.
- AI Lab no longer shows service URL or credential input cards in the normal support flow.
- The visible AI status now explains whether online feedback or built-in feedback is available without exposing setup details.

## Tests Added Or Updated

- `UserFlowContractTest` protects role labels, bottom navigation, check-in questions, support routing, and question types.
- `DailyMissionContractTest` protects mission progress, summary, and completion copy.
- `QuestionBankContractTest` protects question bank recommendations and session de-duplication.
- `PrototypeRepositoryTest` and `PrototypeRepositoryContentTest` protect item count, type coverage, metadata, and clean visible text.
- `AiLearningPlanContractTest` and `OpenRouterClientTest` protect AI planning and fallback messages.
- `UserVisibleCopyContract` now catches both internal implementation terms and common mojibake fragments.

## Verification

Targeted red-green tests were run first. Full verification for this round:

```powershell
.\gradlew.bat test --rerun-tasks --console=plain
.\gradlew.bat assembleDebug --console=plain
.\gradlew.bat lintDebug --console=plain
```
