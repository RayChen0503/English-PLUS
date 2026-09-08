# RELEASE-0 baseline and competition guard

Completed locally on 2026-07-17 (Asia/Taipei).

## Objective

Establish one truthful release baseline before any production resource is
created. Preserve the MAIC judging build and make accidental reuse of the
competition Firebase, Worker, R2 bucket or TestFlight group detectable.

## Verified starting state

- Frozen competition source: `1207a359708b8d83bec867bfdec5a8bdd5d229ac`
- Frozen source tag: `maic-competition-build-52`
- Frozen source branch: `release/maic-2026-build-52`
- Judge-facing external TestFlight build: `1.0 (53)`
- Judge-facing group: `English+公測`
- Judge-facing public link: `https://testflight.apple.com/join/xTWGUg3f`
- Completed STORE source on GitHub: `5ec3f9f981ab615697c52fcb2e9924ad7e678c93`
- Current local release branch: `codex/app-store-production-release`
- First permitted production candidate: build 54

The authenticated Firebase project listing contained only
`englishplus-testflight`. The production Worker query returned Cloudflare
error `10007` because `englishplus-ai-proxy-production` does not exist. The R2
bucket listing contained only `englishplus-volunteer-evidence`.

## Installed safeguards

1. `release-environment-lock.json` is the machine-readable identity lock for
   both environments.
2. `validate_release0_competition_guard.py` verifies Git refs, build numbers,
   TestFlight group/link, Firebase aliases, Worker/R2 bindings, Xcode Cloud
   plist isolation, Hosting targets and untracked secret files.
3. The existing STORE-0 and STORE-4 validators now distinguish the frozen
   build-52 source marker from the public judging build 53.
4. The release gate requires build 54 or later and prohibits assigning a
   production candidate to `English+公測`.

## Validation evidence

- `validate_release0_competition_guard.py`: passed
- `validate_store0_environment_isolation.py`: passed
- `validate_store4_release_submission.py`: passed for all 1,080 provenance records
- `git diff --check`: passed
- Stale public-build-52 release wording search: no matches

## External actions deliberately not performed

- No GitHub push
- No Xcode Cloud trigger
- No Firebase project creation or deployment
- No Cloudflare Worker, R2 or secret mutation
- No App Store Connect or TestFlight group mutation

RELEASE-1 may begin only after the owner confirms the launch settings and is
available for Firebase/Apple authentication or 2FA when the provider rejects
an automated session.
