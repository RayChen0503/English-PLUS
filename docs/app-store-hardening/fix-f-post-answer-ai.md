# FIX-F post-submission AI assistance

Date: 2026-07-14

## Problem

Question-level AI assistance looked like part of the answer submission area and
could be mistaken for the primary action. Older practice behavior also started
an AI request automatically after a wrong answer, while still presenting a
second `ask AI` control. That duplicated quota use and made it unclear whether
the learner or the app had requested an explanation.

## Product flow

1. Before submission, the learner sees only the question, answer controls and
   one primary `submit answer` action.
2. Selecting an option does not reveal or enable question-specific AI help.
3. After submission, local correct/wrong feedback appears first. No AI request
   is made automatically.
4. The primary continuation action stays above optional help. A wrong answer
   then offers explicit AI explanation and, when the student has an active
   class, teacher/volunteer support.
5. AI results remain attached to the submitted question. Starting or leaving a
   three-question repair set keeps the original free-practice session intact.
6. Daily missions, free practice and repair practice use the same eligibility
   rule.

## Defense in depth

- `PostSubmissionAssistancePolicy` rejects missing, placeholder and zero-attempt
  answer contexts in iOS.
- `AppState` does not call an AI service for an ineligible context.
- The Cloudflare Worker rejects incomplete wrong-answer requests with
  `AI_ANSWER_SUBMISSION_REQUIRED` before quota reservation or Groq invocation.
- The legacy Functions proxy applies the equivalent precondition for contract
  parity.

## Acceptance requirements

- AI help is absent before submission, including after merely selecting an
  option.
- Wrong-answer submission itself does not spend AI quota.
- AI help appears only in post-answer feedback and requires an explicit tap.
- The continue/finish action is visually primary; optional help cannot be
  mistaken for answer submission.
- Human support carries a real submitted answer and cannot create an empty
  question snapshot.
- Worker and Swift tests cover rejected and accepted assistance contexts.
