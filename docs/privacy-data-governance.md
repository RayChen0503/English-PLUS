# English+ Privacy And Data Governance

This document records the current safety boundary for the English+ internal-test Android app.

## Sensitive Student Data

English+ treats emotional-support and learning-support records as sensitive data. This includes:

- Mood check-in results.
- Student help requests.
- Wrong-answer repair notes.
- Teacher and volunteer handoff notes.
- AI support context used to generate low-pressure explanations or daily tasks.

These records must not be visible to other students, used for public ranking, or presented as failure.

## Data Rights

Students or guardians can ask the teacher or course team to:

- Export the student's learning records.
- Delete internal-test records.
- Stop using English+.

The app now exposes this policy in the student profile screen, and the pilot consent notice includes the same rights.

## API Key Policy

Production AI keys must stay on a secure backend proxy. The Android app must not commit, store, or ship production OpenAI or OpenRouter keys.

Allowed:

- HTTPS backend proxy endpoint.
- Local classroom demonstration without a production key.

Not allowed:

- Production API key in source code.
- Production API key in Android resources.
- Production API key saved on the device for public or long-term use.

## Firebase Or School Backend Requirements

A production backend should enforce:

- Firebase Auth or school-account role claims for student, teacher, volunteer, and admin roles.
- `classId` scoping on every learning record, support thread, report, and collaboration note.
- Student read rules that deny access to other students' emotional-support and answer-history data.
- Teacher and volunteer write audit trails with actor id, role, target student, and timestamp.
- Cloud Function or school backend proxy for AI calls, so API keys remain server-held.

## Report Boundary

English+ now separates student, class, and pilot reports. Text and HTML exports are local, while PDF, Word, and teacher-dashboard rendering can use the same report sections:

- learning
- support
- handoff
- nextActions

The reports should describe evidence and next steps, not rank students.
