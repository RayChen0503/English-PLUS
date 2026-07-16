# STORE-4 App Review Notes

Paste the final version into App Store Connect after replacing the three email
placeholders there. Passwords must be entered only in App Store Connect's secure
sign-in fields, never in this repository.

## Review Notes draft

English+ is an English-learning and scoped classroom-collaboration app. It is not
a medical, counselling or emergency service. Students can use personal learning
without joining a class. Human support is asynchronous and begins only when a
student explicitly sends a question-specific request.

Use the private Email/password accounts supplied in App Review Information. They
contain fictional demonstration data and do not require Google/Apple 2FA or any
manual approval.

### Student reviewer

1. Choose Student and sign in with the Student reviewer account.
2. Complete the short daily check-in, then open the generated mission.
3. Submit an answer. AI explanation appears only after answer submission.
4. Open Free Practice to test filters and a finite question set.
5. Open Class to start the preloaded teacher assignment.
6. From a submitted question, send a support request. Open Support to view the
   preloaded teacher/volunteer reply and archive it.
7. Open the reply menu in Support to report a reply or block its author. A
   blocked reply is hidden immediately and later replies from that author stay
   hidden for the reporting student.
8. Account, privacy choices and in-app account deletion are available from the
   profile/account area. For an Apple-linked account, the deletion screen asks
   for Sign in with Apple again and revokes the app authorization before deletion.

### Teacher reviewer

1. Choose Teacher and sign in with the Teacher reviewer account.
2. Open Class, select `English+ App Review Demo`, inspect the fictional roster
   and assign a question group to Review Student.
3. Open Relay, inspect the complete question snapshot and send a reply.
4. Class ownership, teacher membership and assignment controls are available
   from the Class workspace. Teachers do not receive students' blocked-author
   lists or private moderation history.

### Volunteer reviewer

1. Choose Volunteer and sign in with the Volunteer reviewer account.
2. The account is already approved and authorized for the review class.
3. Open Relay, select the pending question, optionally edit the AI-generated
   draft, then send the reply.
4. The volunteer can see only student-submitted support context, not full student
   learning, mood or class-management records.

### Technical and privacy context

- Firebase provides Email, Google and Apple authentication plus synchronized data.
- AI requests use an authenticated Cloudflare Worker and Groq. No AI key is in the app.
- Volunteer evidence uses private Cloudflare R2 storage and is administrator-only.
- Students can report or block a teacher/volunteer reply. Reports enter a
  private administrator queue with reviewing, resolved and dismissed states;
  each moderation decision requires a note and retains an audit event.
- Support requests and staff replies are length-limited and screened before
  upload for direct abuse, threats and private contact details.
- Crash diagnostics is optional and may be disabled in the app.
- No advertising, tracking, in-app purchase or paid subscription is present.

If review data was changed during testing, sign out and back in before retrying.
Contact: englishplus.tw@gmail.com
