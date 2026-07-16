# STORE-4 Final Submission Gate

No merge, remote push, Xcode Cloud run or App Store submission is authorized by
this document. Every external action still requires the product owner's explicit approval.

## Automated gates

- [x] Generate and validate the 1,080-record prompt-free provenance manifest.
- [x] Validate App Store metadata character and UTF-8 byte limits.
- [x] Validate age-rating answers against the shipping communication and
      wellbeing features.
- [x] Run the complete existing validator sweep (`99/99`).
- [x] Run Firebase Emulator rules and indexes tests (`40/40`, JDK 21),
      including STORE-2 managed-account and STORE-3 class-transfer paths.
- [x] Run Worker native tests (`41/41`), Worker Node tests (`35/35`) and
      Firebase Functions typecheck/production build.
- [x] Run administrator portal tests (`10/10`) and the competition build.
- [x] Lock the competition Worker to the `internal` AI quota and the isolated
      production Worker to the stricter `public` quota.
- [x] Confirm the public privacy and support pages are online and disclose
      account deletion, minor/managed-account consent, AI subprocessors,
      volunteer evidence retention and the public support address.
- [ ] Run Swift unit, integration and UI tests on macOS/Xcode Cloud.
- [ ] Archive a Production release candidate with no mock/debug route.
- [x] Confirm no API key, service-account key, review password or evidence file is bundled.

Windows note: the current Cloudflare Vitest pool and Vite/Rollup process exit
without a useful diagnostic when run under the repository's non-ASCII parent
path. The same locked source and dependencies pass in an isolated ASCII-only
temporary path. This is a host-tooling path limitation, not an application test
failure; macOS/Xcode Cloud remains the release-authoritative build environment.

## Human and device gates

- [ ] Product owner signs the question-origin attestation and discloses any external source.
- [ ] Product owner confirms launch settings: free, no ads, no IAP, Taiwan only,
      public App Store, Education, manual release.
- [x] STORE-2 decision is locked to public self-registration for users aged
      13 or older, with a separate school/guardian-managed path for under-13
      users; implementation and local rules tests are complete.
- [x] STORE-3 decision is locked to transfer owned classes to an eligible
      co-teacher before deletion, with archive fallback only when no eligible
      co-teacher exists; implementation and local lifecycle tests are complete.
- [x] False offline warnings are separated from listener/auth/permission/config
      failures; transient retries, permanent-failure stopping, stale-callback
      rejection and recovery confirmation pass the dedicated local gate.
- [x] Student report/block controls are connected to an authenticated private
      administrator queue with finite moderation states and append-only audit events.
- [x] Support text is length-limited and screened for direct abuse, threats and
      private contact details before it reaches Firestore.
- [x] Apple-linked accounts must reauthenticate in the deletion flow; English+
      revokes the Apple authorization code before the backend removes the account.
- [ ] Production Firebase/Worker/R2/admin portal are isolated and online.
- [ ] Student, teacher and volunteer review accounts work on clean devices without approval.
- [ ] Historical demo passwords are rotated and no production review account reuses them.
- [ ] New user, returning user, offline/retry, cross-device sync, AI consent/refusal,
      report, block, account deletion, dark mode and Dynamic Type are tested.
- [ ] App Privacy answers match policy, Xcode privacy report, SDK manifests and packet capture.
- [ ] Screenshots contain only fictional data and match the current release UI.
- [ ] The live age-rating result and any 13+ override are recorded after the
      owner confirms the public-account policy.

## Competition isolation

- [x] `maic-competition-build-52` still resolves to `1207a35`.
- [x] The public TestFlight link resolves to the English+ beta invitation.
- [ ] Confirm on an enrolled device that the public group `English+公測` still
      installs build 52.
- [ ] Candidate build number is 53 or higher and belongs only to `AppStore RC`.
- [ ] Candidate points to production services; competition build points only to
      `englishplus-testflight` and the competition Worker.
- [ ] No deployment modifies competition Firestore, Worker, R2 or admin hosting.

## Submission sequence

1. Owner approves one final branch push and one Xcode Cloud candidate build.
2. Verify the uploaded build in `AppStore RC`; do not add it to `English+公測`.
3. Enter privacy, metadata, age rating, content rights and export-compliance answers.
4. Enter review credentials securely and paste the finalized Review Notes.
5. Select the candidate build and choose manual release.
6. Add for Review, inspect the draft, then Submit for Review.
7. If accepted, owner makes the separate final release decision.

## Current blockers

- The public privacy and support pages are online with the finalized minor and
  managed-account wording. STORE-2 still needs macOS UI/build and real-device
  verification before submission; its implementation and local rules tests are complete.
- STORE-3 class-transfer/archive implementation and local verification are
  complete (`35/35` Worker Node tests and `40/40` Firestore Emulator tests);
  macOS UI/build verification remains part of the final release-candidate gate.
- Network-status hardening is complete locally; macOS Swift compilation and a
  real-device reconnect/listener-failure scenario remain release-candidate gates.
- UGC safety moderation is complete locally; production administrator access,
  a real report-to-resolution smoke test and App Review disclosure remain
  release-candidate gates.
- Apple account deletion and authorization revocation are complete locally;
  a real-device Apple reauthentication/deletion test remains a release-candidate gate.
- Recommended launch settings have not yet been confirmed by the owner.
- No external-source attestation has yet been signed.
- Production review accounts cannot be provisioned until the isolated production
  backend is deployed.
- Final screenshots and real-device release-candidate testing are pending.
