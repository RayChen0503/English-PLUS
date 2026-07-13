# Round 10 - executable AI learning and staff actions

Status: Complete.

## Product contract

AI output is useful only when the learner or staff member can turn it into a
real, reviewable action. Round 10 therefore replaces prose-only handoffs with
three explicit action contracts:

1. A practice recommendation includes a bounded structured practice plan and
   starts the exact real question set selected from the approved bank.
2. A wrong-answer explanation can open a three-question repair set matched by
   question type, level and skill, with a finite progress bar and completion
   summary.
3. Teacher and volunteer assistance is presented as a staff-only summary, an
   editable student-facing draft and one next action. Staff must explicitly
   adopt and send it; AI never overwrites or sends a human reply by itself.

## Defects found and corrected

1. Practice recommendations were inferred by searching natural-language AI
   text for keywords. The Worker and iOS app now share a `practicePlan`
   contract containing title, target count, focus skills and typed question
   plan items.
2. Even after selecting an AI plan, the generic practice builder silently
   filled an eight-question plan to ten questions. Applying a validated plan
   now preserves its exact size and selected IDs.
3. Daily missions read AI question types but ignored per-type counts and
   difficulty. Mission selection now follows each structured plan item and
   uses a controlled same-type fallback only when the exact bank slice is
   short.
4. Wrong-answer AI ended in an explanation card. Daily mission and free
   practice now both create a real same-skill repair selection; the cross-tab
   handoff carries question IDs rather than a loose filter suggestion.
5. Staff AI replaced text already entered in the reply field. Teacher and
   volunteer cards now preview the summary, editable draft and next action,
   then require explicit adoption and a separate send action.
6. Provider fallback responses lacked task-specific fields. The Worker and
   local iOS fallback now retain executable practice, repair and staff-draft
   shapes even when Groq is unavailable.
7. Student-facing practice copy exposed a diagnostic AI connection check.
   It now explains the learning outcome only, and non-button recommendations
   no longer use button-like accent styling.

## Safety and quality boundaries

- The Worker accepts only seven supported question types and four difficulty
  bands, clamps plans to 6-10 questions and caps focus skills at three.
- The sum of plan item counts is normalized before iOS receives the response.
- iOS resolves the plan only against approved question-bank items and removes
  duplicate IDs before a session starts.
- The approved bank contains 1,080 unique items. Every current
  type/level/skill group contains at least 20 items, so a source question plus
  three distinct repair questions is available without inventing content.
- Staff AI is assistive: preview, adopt, edit, then send. The model cannot
  publish a teacher or volunteer message directly.

## Verification evidence

- Cloudflare Workers runtime: 19/19 Vitest checks passed, including malformed,
  oversized and missing structured practice plans.
- Complete Python validator sweep: 70/70 passed after obsolete validators were
  updated to reject the old generic plan-filling behavior.
- Functions TypeScript build passed.
- Production Worker version:
  `8db50781-98b4-4ef7-89e4-a8ff4e9319a6`.
- Authenticated production Firebase/Groq smoke suite: 36/36 passed. The real AI
  returned a non-fallback structured practice plan with target 8 and planned
  total 8, plus a non-fallback wrong-answer repair response with `tryAgain`.
- Isolated macOS compile evidence is recorded in `CURRENT_STATE.md` after the
  branch-only GitHub Actions gate completes.
- No Xcode Cloud or TestFlight release was triggered. The work remains on
  `codex/app-store-hardening-c` until the Block C checkpoint after Round 12.

## Next round

Round 11 implements decision D-19 account deletion and retention, and decision
D-20 human-help escalation without pretending English+ is a continuously
monitored crisis service.
