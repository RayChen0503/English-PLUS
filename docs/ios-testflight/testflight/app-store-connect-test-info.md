# App Store Connect TestFlight Test Information

## App Information

| Item | Value |
| --- | --- |
| App name | English+ |
| SKU suggestion | `englishplus-ios-testflight` |
| Bundle ID | `com.englishplus` |
| Version | `1.0` |
| Build | Assigned automatically by Xcode Cloud |
| Primary language | Traditional Chinese |
| Category suggestion | Education |
| Target testers | Students, teachers, volunteers, project staff |
| Privacy policy | `https://sites.google.com/view/englishplus-privacy/%E9%9A%B1%E7%A7%81%E6%94%BF%E7%AD%96` |
| Support URL | `https://sites.google.com/view/englishplus-privacy/%E6%94%AF%E6%8F%B4%E8%88%87%E8%81%AF%E7%B5%A1` |
| Support email | `englishplus.tw@gmail.com` |

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
English+ is an English-learning app with optional classroom collaboration. Students can learn without joining a class, or join a teacher-created class to receive assignments and request question-specific human help. Firebase provides authentication and synchronized data. AI requests use an authenticated Cloudflare gateway and Groq with minimized learning context; no AI key is bundled in the app.

Please test these role flows with the private review accounts supplied in App Store Connect:
- Student: choose student, sign in, accept the current privacy consent, complete a mood check-in, finish a daily mission, try free practice and send a question-specific support request.
- Teacher: choose teacher, sign in, select a class, assign work and reply to a student's request.
- Volunteer: choose volunteer, sign in with an approved account, review an authorized support item and send an editable response.

The student explicitly chooses whether to contact a person. Mood scores do not automatically notify staff, and English+ is not a medical or emergency service.
```

## Upload Preconditions

- Apple Developer Program membership active.
- App Store Connect app exists for `com.englishplus`.
- Account Holder has accepted all agreements, tax, banking, and compliance prompts if required.
- Xcode can use an Apple Distribution signing certificate or automatically create one.
- App Store Connect upload permission is available to the signed-in Xcode account.
- `GoogleService-Info.plist` is ready before any Firebase-backed TestFlight build that touches real backend data.
- Privacy policy URL, support URL and `englishplus.tw@gmail.com` match the in-app links.
- App Privacy answers include Firebase, Cloudflare, R2 and Groq processing.
- Review credentials are entered only in App Store Connect, not this repository.
