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
- Current Block B branch: `codex/app-store-hardening-b`
- Block B baseline commit: `9bb6307`
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

## Main-branch safety

Block B commits are made on `codex/app-store-hardening-b`. They do not
represent a TestFlight release until the hardening branch is deliberately
merged into `main` and Xcode Cloud passes.
