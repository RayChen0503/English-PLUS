# English+ App Store hardening

This directory records the production-hardening work that starts from the
current iOS baseline without changing `main` on every round.

## Working agreement

- Baseline branch: `main`
- Hardening branch: `codex/app-store-hardening`
- Baseline commit: `cf5381fea1c595632a897b2fa38076358870ff39`
- Xcode Cloud gate: merge to `main` only after the agreed checkpoints.
- Verification cadence: focused checks every round, mini regression every two
  rounds, and full audits after rounds 4, 8, 12, 16, and 20.
- A round is not complete until its report, checks, and Git state agree.

## Round index

| Round | Status | Evidence |
| --- | --- | --- |
| 1 - Baseline audit and freeze | Complete | `round-01-baseline-audit.md` |
| 2 - Personal mode and class-mode domain model | Waiting for decisions | - |

## Main-branch safety

Commits in this directory are made on `codex/app-store-hardening`. They do not
represent a TestFlight release until the hardening branch is deliberately
merged into `main` and Xcode Cloud passes.
