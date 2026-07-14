# English+ App Store hardening

This directory records the production-hardening work that starts from the
current iOS baseline without changing `main` on every round.

## Read order

1. [Current state](CURRENT_STATE.md) for the compact source of truth.
2. [Decision register](DECISIONS.md) for confirmed and pending product choices.
3. The relevant `round-*.md` report only when its implementation or evidence
   is needed.

The current-state document is intentionally short. It prevents each new round
from repeatedly re-reading the full project history while keeping the detailed
evidence in the round reports.

## Working agreement

- Baseline branch: `main`
- Current Block D branch: `codex/app-store-hardening-d`
- Stable main baseline: `d41aa0e` after the FIX-A through FIX-G repair block
- Xcode Cloud gate: merge to `main` only after the agreed checkpoints.
- Verification cadence: focused checks every round, mini regression every two
  rounds, and full audits after rounds 4, 8, 12, 16, and 20.
- A round is not complete until its report, checks, and Git state agree.

## Round index

| Round | Status | Evidence |
| --- | --- | --- |
| 1 - Baseline audit and freeze | Complete | `round-01-baseline-audit.md` |
| 2 - Personal mode and class-mode domain model | Complete | `round-02-personal-and-class-domain.md` |
| 3 - Google/Apple/Email role onboarding | Complete | `round-03-multi-provider-role-onboarding.md` |
| 4 - Provider UI and private volunteer review | Complete | `round-04-provider-ui-private-volunteer-review.md` |
| 5 - Personal learning mode | Complete | `round-05-personal-learning-mode.md` |
| 6 - Classroom lifecycle | Complete | `round-06-classroom-lifecycle.md` |
| 7 - Teacher class management | Complete | `round-07-teacher-class-management.md` |
| 8 - Firestore synchronization and Block B audit | Complete | `round-08-firestore-sync-audit.md` |
| 9 - Authenticated AI gateway, quota and monitoring | Complete | `round-09-ai-gateway-hardening.md` |
| 10 - Executable AI learning and staff actions | Complete | `round-10-executable-ai-actions.md` |
| 11 - Account deletion and explicit human help | Complete | `round-11-account-deletion-human-help.md` |
| 12 - Privacy, support and Block C audit | Complete | `round-12-privacy-support-block-c-audit.md` |
| 13 - Repository decomposition and sync recovery | Complete | `round-13-reliability-decomposition.md` |
| 14 - Automated quality gates | Complete | `round-14-automated-quality-gates.md` |
| 15 - Question-bank taxonomy and set quality | Complete | `round-15-question-bank-quality.md` |
| 16 - Mastery, spaced review and Block D audit | Awaiting final macOS gate | `round-16-mastery-spaced-review-block-d-audit.md` |

## Main-branch safety

Block D commits are made on `codex/app-store-hardening-d`. Round 16 becomes a
release candidate only after its current branch commit passes the full macOS
gate. One deliberate merge to `main` then triggers Xcode Cloud; no intermediate
round or documentation-only work may trigger it.
