# Round 19 - Appearance, accessibility and observability

Status: Passed locally

Date: 2026-07-14

Branch: `codex/app-store-hardening-e`

Release boundary: this round remains isolated from `main`. It does not trigger
Xcode Cloud. Rounds 17 through 20 merge only after the complete Block E audit
passes.

## Goal

Keep the real English+ experience readable and operable in light mode, dark
mode, large Dynamic Type and narrow iPhone layouts, while making loading,
offline and failure behavior predictable. Production failures must become
diagnosable without sending student content or other direct identifiers.

## Implementation

- Extended the existing adaptive theme with semantic success, warning and
  failure surfaces. The app remains a real system-controlled dark theme; it
  does not force light mode.
- Updated shared action styles to preserve a 48-point minimum target and use a
  restrained pressed-state animation that is disabled when Reduce Motion is
  enabled.
- Added one reusable loading, empty and failure state component with stable
  accessibility labels, identifiers and retry behavior. Teacher roster and
  volunteer class loading now use the same language and recovery hierarchy.
- Made the staff handoff metric strip adapt from a row to a vertical layout
  when text or device width no longer fits. Teacher and volunteer tab bars now
  share the product tint.
- Added Firebase Crashlytics through the existing Firebase Swift package,
  including the official dSYM upload build phase. Symbol upload is restricted
  to Release builds so local and CI simulator builds never upload placeholder
  diagnostics.
- Crash reporting is disabled by default. Consent includes a separate optional
  stability-diagnostics choice, and the account screen keeps a persistent
  on/off control. Turning it off also discards unsent reports.
- The privacy manifest declares crash data as unlinked, non-tracking diagnostic
  data used only for app functionality.
- Diagnostic reports contain only a bounded operation category, Swift error
  type, current role and coarse app route. They do not set a Crashlytics user
  identifier and do not include names, email addresses, class names, question
  content or mood scores.
- Root-level observation records non-fatal authentication, consent, classroom,
  roster, volunteer, support and assignment failures without copying visible
  error text into Crashlytics.
- Added UI journeys for dark appearance plus accessibility text and a CI matrix
  that runs those journeys on an available small iPhone and Pro Max device.
  Result bundles are retained with the existing diagnostics artifact.

## Behavioral acceptance

- Light and dark appearance use semantic foreground and surface colors.
- Primary actions remain reachable with accessibility text sizes.
- Staff metrics reflow instead of clipping or shrinking important text.
- A loading, empty or failed data section states what happened and, when
  possible, provides one retry action.
- A user can decline stability reporting without losing any product feature,
  and can change that choice later.
- Crashlytics receives symbol files for diagnosable TestFlight crashes only
  when the user has enabled collection.

## Verification evidence

- `validate_app_store_hardening_round19.py` passes all appearance,
  accessibility, state, privacy and Crashlytics contracts.
- The current release regression set passes 25 of 25 validators, covering
  Rounds 5-19, onboarding, Xcode source membership, FIX-A through FIX-G and
  the Block E reported-regression contracts.
- Xcode source membership validation passes with 67 Swift sources.
- Round 17 student and Round 18 staff regressions pass.
- `Info.plist` parses successfully and defaults Crashlytics collection to off.
- Cloudflare Worker syntax validation and Firebase Functions TypeScript build
  pass. The administrator portal passes all 7 Vitest cases.
- Cloudflare Worker Vitest cannot start its workerd pool on this Windows host
  because `cloudflare:test-internal` is unavailable; the same test command is
  retained as a required macOS CI gate.
- `git diff --check` passes.
- Swift compilation and the two-device UI matrix require the macOS CI runner
  and will run as part of the final Block E gate rather than triggering an
  intermediate Xcode Cloud release build.
