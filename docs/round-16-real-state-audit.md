# Round 16 Real State Audit

This round prevents English+ from looking more complete than it really is. It separates what is working inside the Android app from what still requires external credentials, school decisions, hosted services, or legal/content ownership.

## What Is Now Locked By Tests

- `ValidationContract.productRealityInventory()` lists the real status of major product capabilities.
- Implemented local capabilities are separate from external launch dependencies.
- Normal app screens are scanned so they do not expose prototype/setup copy such as local fallback labels, backend setup language, or debug-style readiness text.
- Store listing copy must be readable and mention the English+ value: rural English practice, emotional support, teachers, and volunteers.
- Auth role labels must remain readable: student, teacher, and volunteer.

## Completed Inside The App

- Local learning records are saved on the device.
- Student support, teacher replies, and volunteer handoff can form a same-device loop.
- Classroom accounts remain usable for internal testing.
- Sync, auth, AI, and release boundaries are explicit enough for later external integration.

## Not Claimed As Complete

These are not marked as implemented inside the app because they require external setup or policy decisions:

- Firebase Auth or school account integration.
- Cross-device cloud sync.
- Secure AI proxy with server-held production keys.
- Formal question-bank license and content owner.
- Store signing credentials and public privacy policy URL.

## User-Facing Copy Rule

Students, teachers, and volunteers should see what they can do next, not engineering status. Internal setup details belong in docs, contracts, and readiness checklists instead of normal role flows.

Examples of replacement language:

- Use "班級帳號可用" instead of setup/debug wording.
- Use "等待同步連線" instead of backend URL wording.
- Use "內建回饋" instead of local fallback wording.
- Use "接力紀錄已保存" instead of database/backend wording.

## Verification Added

- `ValidationContractTest.round16RealityInventorySeparatesDoneWorkFromExternalDependencies`
- `ValidationContractTest.round16NormalAppScreensDoNotExposePrototypeOrSetupCopy`
- `StoreReleaseContractTest.playStoreListingContainsRequiredEnglishPlusMetadata`
- `AuthContractTest.authBoundaryStatusStaysUserFacing`
