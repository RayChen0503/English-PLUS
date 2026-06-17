# App Store Connect TestFlight Test Information

## App Information

| Item | Value |
| --- | --- |
| App name | English+ |
| SKU suggestion | `englishplus-ios-testflight` |
| Bundle ID | `tw.edu.englishplus` |
| Version | `1.0` |
| Build | `1` |
| Primary language | Traditional Chinese |
| Category suggestion | Education |
| Target testers | Students, teachers, volunteers, project staff |

## Internal Test Groups

Create these groups first:

| Group | Purpose |
| --- | --- |
| `English+ Core Team` | Account Holder, developer, product owner, reviewer |
| `Student Flow Testers` | Students or adults checking the student learning flow |
| `Teacher Flow Testers` | Teachers checking triage, support, and feedback flow |
| `Volunteer Flow Testers` | Volunteers checking relay and encouragement flow |

## Tester Email Collection

Use a spreadsheet with these columns:

```text
email
name
role_to_test
school_or_group
guardian_or_staff_contact_required
consent_ready
notes
```

Only upload testers who have consent/permission appropriate for their role.

## Beta App Review Notes

Suggested notes for the first internal/external review:

```text
English+ is an educational support prototype for student English practice and teacher/volunteer accompaniment. This TestFlight build uses demo/local data for the first test cycle. Firebase and AI proxy interfaces are prepared, but production student data and production AI keys are not bundled in the app.

Please test with the in-app demo role flows:
- Student: choose student, accept privacy consent, complete mood check-in, finish a daily mission, try free practice, send a support request.
- Teacher: choose teacher, review priority students and support requests, send a feedback reply.
- Volunteer: choose volunteer, review assigned support items, send an encouragement reply.
```

## Upload Preconditions

- Apple Developer Program membership active.
- App Store Connect app exists for `tw.edu.englishplus`.
- Account Holder has accepted all agreements, tax, banking, and compliance prompts if required.
- Xcode can use an Apple Distribution signing certificate or automatically create one.
- App Store Connect upload permission is available to the signed-in Xcode account.
- `GoogleService-Info.plist` is ready before any Firebase-backed TestFlight build that touches real backend data.
- Privacy policy URL and support URL are ready before external testing.
