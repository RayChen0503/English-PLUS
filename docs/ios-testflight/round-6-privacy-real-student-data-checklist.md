# Round 6 - Privacy And Real Student Data Checklist

This round documents how English+ should handle real student data for the future iOS/TestFlight version. It is not legal advice. It is a product and engineering checklist that should be reviewed by the school, project owner, and a qualified legal/privacy reviewer before real students use the app.

## Confirmed Product Decisions

| Question | Decision |
| --- | --- |
| Use real student names | Yes |
| Use class, school, and grade | Yes |
| Who can view mood check-in data | Teacher, volunteer, backend/admin system |
| Retention preference | No fixed expiry requested, but deletion must be available |
| Consent preference | In-app checkbox agreement if possible |
| Platform direction | iOS/TestFlight first |
| Bundle ID | `tw.edu.englishplus` |

## Privacy Position

Because this app will handle real student names, school/class/grade context, learning records, help requests, and mood check-in data, English+ should be treated as a high-privacy educational support system.

The app should not be presented as a casual practice game once real student data is enabled. It should clearly operate as:

```text
English+ - rural student English learning support and teacher/volunteer coordination system
```

## Important Answer To The User's Two Questions

### Can data be stored with no fixed time limit?

A pure "no time limit forever" policy is not recommended for real student data.

Safer product decision:

```text
Keep data while the account, class, school project, or learning-support purpose is active. Allow student-side deletion requests, teacher/admin deletion, volunteer/admin deletion where appropriate, and run an annual retention review. When the class/project ends, delete or de-identify data unless the school has explicitly approved continued retention.
```

This still gives the product flexibility, but it avoids saying that identifiable student data is kept forever.

### Is an app checkbox agreement enough?

An in-app checkbox is useful and should be implemented, but it should not be the only consent mechanism for real students.

Recommended consent model:

```text
1. School/project-level approval before onboarding a real class.
2. Parent/guardian or school-approved student consent where required.
3. In-app student-friendly agreement checkbox at first login.
4. Separate acknowledgement for mood check-in and AI support features.
5. Consent record stored in Firestore with timestamp, policy version, actor, and source.
```

For a classroom prototype with minors, the app checkbox should be treated as a visible product consent step, not as a complete legal solution by itself.

## Data Categories

### Identity And Account Data

| Data | Examples | Sensitivity | Used By |
| --- | --- | --- | --- |
| Student name | real name, preferred name | high | student, teacher, volunteer where assigned, admin |
| Account ID | Firebase Auth UID | high | system |
| Login email | school or test email | high | system, admin |
| Role | student, teacher, volunteer | medium | system |

### School Context Data

| Data | Examples | Sensitivity | Used By |
| --- | --- | --- | --- |
| School | school name or code | high when linked to student | teacher, admin |
| Class | class code, class name | high when linked to student | teacher, volunteer where assigned, admin |
| Grade | junior high grade | medium/high | teacher, admin |
| Teacher/volunteer assignment | assigned support person | high | teacher, volunteer, admin |

### Learning Data

| Data | Examples | Sensitivity | Used By |
| --- | --- | --- | --- |
| Question attempts | answer, correctness, time | medium/high | student, teacher, assigned volunteer, admin |
| Daily mission | assigned question types, progress | medium/high | student, teacher, admin |
| Skill profile | weak grammar, reading level | medium/high | student, teacher, assigned volunteer, admin |
| Reports | progress summary, risk level | high | teacher, admin |

### Mood And Support Data

| Data | Examples | Sensitivity | Used By |
| --- | --- | --- | --- |
| Mood score | 1-5 mood scale | high | student, teacher, assigned volunteer, admin |
| Available time | 1-5 time scale | medium | student, teacher, admin |
| Challenge preference | wants harder questions | medium | student, teacher, admin |
| Preferred question type | cloze, translation, reading | medium | student, teacher, admin |
| Support thread | help request and replies | high | student, teacher, assigned volunteer, admin |
| Staff-only notes | teacher/volunteer notes | very high | teacher, assigned volunteer, admin |

Mood data should be displayed only when it supports learning or care coordination. It should not be used for ranking, punishment, public comparison, or unrelated assessment.

### AI Data

| Data | Examples | Sensitivity | Used By |
| --- | --- | --- | --- |
| AI prompt context | mood score, recent weak skills, wrong answer context | high | backend only |
| AI output | mission plan, explanation, support text | medium/high | student, teacher, volunteer depending task |
| AI usage log | model used, token usage, task type | medium | admin/backend |

The OpenRouter API key must remain in the backend proxy only.

## Visibility Matrix

| Data | Student | Teacher | Volunteer | Admin/Backend |
| --- | --- | --- | --- | --- |
| Own name/profile | read/edit limited | read assigned class | read assigned student only | read/manage |
| Own class/grade/school | read | read assigned class | read assigned student only | read/manage |
| Own mood check-in | read/delete request | read assigned class | read assigned student only | read/manage/delete |
| Other students' mood | no | assigned class only | assigned student only | manage |
| Daily mission | own only | assigned class/student | assigned student only | manage |
| Answer events | own only | assigned class/student | assigned student only | manage |
| Support messages | own thread only | assigned class/student | assigned thread only | manage |
| Staff-only notes | no | assigned class/student | assigned thread only | manage |
| Reports | own summary only | assigned class/student | no by default | manage |

## Consent Records

Store consent in:

```text
users/{uid}/consents/{consentVersion}
classes/{classId}/students/{studentUid}/consents/{consentVersion}
```

Recommended fields:

```json
{
  "version": "privacy-v1-2026-06",
  "accepted": true,
  "acceptedAt": "serverTimestamp",
  "acceptedByUid": "firebase-auth-uid",
  "actorRole": "student",
  "consentSource": "inAppCheckbox",
  "schoolApprovalRef": "school-approval-2026-06",
  "guardianConsentStatus": "required | received | schoolApproved | notRequiredForDemo",
  "policyUrl": "https://example.edu/englishplus/privacy",
  "categoriesAccepted": [
    "identity",
    "schoolContext",
    "learningRecords",
    "moodCheckIn",
    "supportThreads",
    "aiAssistance"
  ]
}
```

## Consent UX Requirements

At first login, show:

1. Short student-facing explanation.
2. Link to full privacy notice.
3. Required checkbox:

```text
我已了解 English+ 會使用我的姓名、班級/學校/年級、學習紀錄、心情檢測與求助紀錄，提供英文練習、老師/志工協助與 AI 學習建議。
```

4. Separate checkbox for mood/AI:

```text
我同意 English+ 使用我的心情檢測結果與作答狀況，幫我安排今日任務，並讓老師、志工與後台系統在需要時協助我。
```

5. Clear refusal path:

```text
如果不同意，請告訴老師或專案負責人；你仍可以詢問是否有不記名或紙本練習方式。
```

## Deletion And Correction Rights

The app should support:

- Student requests to delete mood check-ins.
- Student requests to delete support messages when appropriate.
- Teacher/admin deletion of student records.
- Volunteer deletion only through assigned support/admin workflow.
- Correction of wrong names, class, grade, or school.
- Full account deletion only through teacher/admin review if school records need coordination.

Recommended deletion levels:

| Level | Meaning | Use Case |
| --- | --- | --- |
| Soft hide | Hide from normal UI, keep audit trail | mistaken support note |
| Delete content | Remove body, keep event shell | sensitive message removal |
| Full delete | Remove document | mood check-in deletion |
| De-identify | Replace name/uid link with anonymous ID | old class analytics |

## Retention Policy Draft

Recommended wording:

```text
English+ retains identifiable student data while the account, class, school project, or learning-support purpose remains active. Students, teachers, volunteers, or admins may request deletion through the app or project contact. When a class or project ends, identifiable data should be deleted or de-identified unless the school/project owner has a documented reason and approval to retain it. Retention status should be reviewed at least once per school year.
```

Do not use any wording that promises unconditional permanent retention of identifiable student data.

## Firestore Security Implications

Round 4 rules should be extended later to include:

```text
classes/{classId}/aiUsage/{usageId}
classes/{classId}/aiEvents/{eventId}
users/{uid}/consents/{consentVersion}
classes/{classId}/students/{studentUid}/consents/{consentVersion}
classes/{classId}/students/{studentUid}/deletionRequests/{requestId}
classes/{classId}/privacyAuditLogs/{eventId}
```

Access principle:

- Students can create consent and deletion requests for themselves.
- Teachers can review records for assigned classes.
- Volunteers can see only assigned students/support threads.
- Admin/backend can process deletion and audit logs.
- No role should have broad access unless required for the product workflow.

## App Store / TestFlight Privacy Label Draft

If English+ reaches TestFlight/App Store Connect privacy forms, expect to disclose collected data as linked to the user:

| Apple-style category | English+ examples |
| --- | --- |
| Contact Info | name, email if used |
| Identifiers | Firebase UID, app account ID |
| User Content | help requests, support messages |
| Usage Data | lesson progress, question attempts, app interactions |
| Diagnostics | crash logs if enabled |
| Sensitive Info | mood check-in/support context should be reviewed carefully |

Tracking:

```text
Do not track users across apps/websites.
```

Third-party sharing:

```text
Firebase stores backend data. OpenRouter receives minimized AI prompt context through the backend proxy only. Do not send real names unless a future privacy review approves it.
```

## Risk Register

| Risk | Severity | Mitigation |
| --- | --- | --- |
| Real student names linked to mood data | high | role-based access, minimized display, deletion tools |
| Volunteer sees too much class data | high | assignment-scoped access only |
| AI prompt includes unnecessary personal data | high | backend prompt minimization |
| Consent checkbox treated as complete legal consent | high | school/guardian approval plus in-app record |
| No retention limit becomes indefinite archive | high | active-purpose retention plus annual review |
| Teacher/admin deletes data accidentally | medium/high | audit log and confirmation |
| Student cannot understand consent text | medium/high | short student wording plus full policy |

## Must-Have Before Real Student TestFlight

1. School/project owner approves the real-data pilot.
2. Consent text and privacy notice are reviewed.
3. Guardian/school consent pathway is decided.
4. Firestore rules are emulator-tested.
5. Mood data is visible only to allowed roles.
6. Volunteer access is assignment-scoped.
7. Delete/correct/export request workflow exists.
8. AI proxy strips real names before OpenRouter.
9. App Store Connect privacy answers match actual data flow.
10. A breach response contact/process exists.

## Official Sources Checked

- Taiwan Personal Data Protection Act, Article 2: defines personal data and collection/processing/use.
- Taiwan Personal Data Protection Act, Article 3: data subject rights to inquiry, copy, correction, cessation, and erasure.
- Taiwan Personal Data Protection Act, Article 5: purpose limitation, necessity, good faith, and reasonable connection.
- Taiwan Personal Data Protection Act, Article 7: informed consent and data collector burden of proof.
- Taiwan Personal Data Protection Act, Article 8: required notice items, including purpose, categories, period, recipients, methods, rights, and effect of refusal.
- Taiwan Personal Data Protection Act, Article 11: correction, cessation, erasure when purpose no longer exists or period expires.
- Taiwan Personal Data Protection Act, Article 12: breach notification and response.

References:

- https://law.moj.gov.tw/ENG/LawClass/LawAll.aspx?pcode=I0050021
- https://law.moj.gov.tw/LawClass/LawAll.aspx?pcode=I0050021
