# RELEASE-1 production Firebase foundation

Prepared locally on 2026-07-17 (Asia/Taipei).

## Objective

Create an isolated Firebase identity foundation for App Store candidates while
leaving the MAIC competition lane unchanged. RELEASE-1 does not deploy
Firestore data, Rules, indexes, Hosting, the production Worker or R2; those are
RELEASE-2 responsibilities.

## Production resources created

| Resource | Production identity |
| --- | --- |
| Firebase project | `englishplus-production` |
| Project number | `410725934322` |
| iOS Firebase app | `1:410725934322:ios:4eada3d210b1b4c923dc6b` |
| iOS bundle ID | `com.englishplus` |
| App Store ID | `6785041320` |
| Web Firebase app | `1:410725934322:web:f558ce818c91e0b123dc6b` |
| Auth / Hosting domain | `englishplus-production.firebaseapp.com` |

The competition project remains `englishplus-testflight`; no competition
provider, app, data, Hosting site, Worker, R2 bucket or TestFlight group was
changed.

## Authentication provider state

- Email/password: enabled.
- Email-link sign-in: disabled.
- Google: enabled, with public project name `English+` and support account
  `ray171505@gmail.com`.
- Apple: enabled in Firebase with Services ID
  `com.englishplus.firebaseauth`, Team ID `X7Y2V4D87G` and Key ID
  `WAU6QVCTR6`.

The Apple private key was read from the owner's local protected file and sent
directly to Firebase. Its contents were not printed, copied into documentation
or committed to Git.

The iOS app uses the native `ASAuthorizationAppleIDRequest` flow and exchanges
the resulting credential through `OAuthProvider.appleCredential`. Therefore
the native App Store login path does not depend on a Firebase Hosting web
redirect. The existing Services ID also contains the production domain and
return URL for any future web-based Apple flow:

- Domain: `englishplus-production.firebaseapp.com`
- Return URL: `https://englishplus-production.firebaseapp.com/__/auth/handler`

The Apple Developer portal was reopened after saving and showed all four
entries together: competition and production domains plus their matching
return URLs. The action is therefore recorded as
`configured-and-verified`; no competition value was removed.

## Local iOS configuration

The production `GoogleService-Info.plist` is present only at:

`ios/EnglishPlus/EnglishPlus/GoogleService-Info.plist`

Its verified identities are:

- `PROJECT_ID = englishplus-production`
- `BUNDLE_ID = com.englishplus`
- `GOOGLE_APP_ID = 1:410725934322:ios:4eada3d210b1b4c923dc6b`
- Google client and reversed-client URL scheme are present.

The file is ignored by `ios/**/GoogleService-Info.plist` and is not tracked by
Git. Xcode Cloud will receive the same configuration later through the
production-only secret `GOOGLE_SERVICE_INFO_PLIST_BASE64_PRODUCTION`; that
secret is deliberately not created or pushed in RELEASE-1.

## Isolation and safety status

- The release branch remains `codex/app-store-production-release`.
- Competition source tag and branch still resolve to
  `1207a359708b8d83bec867bfdec5a8bdd5d229ac`.
- Competition public TestFlight build remains build 53 in `English+公測`.
- Production candidates remain build 54 or later and must never be assigned to
  `English+公測`.
- No GitHub push or Xcode Cloud trigger was performed.
- No production backend data or AI resource was deployed.

## Completion boundary

The Firebase project, apps, local iOS configuration, Email/Google/Apple
providers and Apple production callback are complete. RELEASE-1 ends with a
local commit only; pushing and all production data/AI deployment remain later
release gates.
