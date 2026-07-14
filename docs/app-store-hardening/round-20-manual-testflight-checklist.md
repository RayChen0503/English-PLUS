# Round 20 TestFlight Manual Acceptance Checklist

This checklist is the final real-device acceptance pass for English+ 1.0. Run it on the newest TestFlight build after the automated macOS gate is green. Use separate student, teacher, volunteer and administrator accounts. For cross-device checks, keep the student on one device and staff on another.

## 1. Test Record

Record these before testing:

```text
Build number:
Test date and time:
iPhone/iPad model and iOS version:
Student account/provider:
Teacher account/provider:
Volunteer account/provider:
Network used:
Tester:
```

For every failure, capture the role, screen, exact action, expected result, actual result, screenshot or recording and whether the issue still occurs after relaunch.

## 2. Installation, First Launch And Account Identity

- Install or update from TestFlight and launch from a clean state.
- Confirm the first screen offers Student, Teacher and Volunteer without exposing IDs, endpoints, mock labels or debug controls.
- Open the privacy policy and support page; confirm both load and show the English+ contact address.
- Test first-time Email registration for each role. Confirm password guidance and errors are understandable.
- Test first-time Google sign-in from the login screen. A new user must continue into role onboarding rather than receive a missing-profile dead end.
- Test first-time Apple sign-in from the login screen, including Hide My Email if available.
- Relaunch after successful sign-in. The same account and role should be restored without repeating consent.
- Sign out and sign in with another provider linked to the same email. Confirm it does not create a silent duplicate account.
- Confirm a personal student can use learning features without joining a class.

Pass condition: every provider has a complete first-use path, consent is requested once per consent version, and session restoration never skips an unfinished onboarding step.

## 3. Student Personal Learning Journey

- Complete the four-question mood check-in. Confirm time, challenge preference and selected question types affect the generated mission.
- Generate a mission while online. Confirm the recommended types match the questions that open.
- Retry mission generation with the AI gateway unavailable or the device offline. Confirm a usable local mission and a calm recovery message appear.
- Submit one correct and one wrong answer. Mission progress must increase only for the correct answer.
- Confirm AI explanation is unavailable before submission and appears only after the answer result.
- Start three-question remedial practice after a wrong answer. Complete or exit it and confirm the original practice set resumes at the same position.
- Finish the daily mission. Confirm an explicit completion state and optional free-practice action.
- Start free practice, exit midway and start again. Confirm no infinite session and no accidental daily-mission progress.
- Finish a free-practice set. Confirm the learning-map state changes once, without duplicate completion.
- Relaunch mid-session and verify saved progress does not become corrupt or jump to another question set.

Pass condition: the journey has one obvious next action, no crash or dead end, no answer leak and no mismatch between selected and delivered questions.

## 4. Classroom And Assignment Journey

- Teacher creates a class, copies its code, resets the code and confirms the old code stops working.
- Student joins by code, switches between multiple classes and returns to personal mode.
- Teacher assigns a question set to one student and then to a class.
- Student receives the assignment in the Class tab with a red badge and opens the exact assigned set.
- Answer on the student device while the teacher watches progress on another device. Correct/wrong and completion state should update without relaunch.
- Complete the assignment. The student badge and pending item should clear; the teacher should see the final result.
- Teacher retracts a pending assignment. It must disappear from the student device and badge count.
- Student leaves a class. New assignments and protected class data must no longer be available.
- Teacher deletes a class. Students and volunteers must be removed and all three roles must return to a valid empty/personal state.

Pass condition: classroom membership determines access, personal learning remains usable and all assignment state changes synchronize across devices.

## 5. Question-Specific Human Support

- Student submits an answer, then sends that exact question to teacher/volunteer support.
- Confirm the request includes the question, options, submitted answer, correct answer and learning context, but no unrelated student history.
- Teacher replies on a second device. The student must receive the reply without signing in on the teacher device.
- Volunteer replies to an authorized request. Teacher and volunteer should see the shared conversation state.
- Student reads all replies. Waiting/unread badges and learning-map support state must update correctly.
- Student withdraws an unanswered request. It must disappear from staff queues and all associated badges.
- Staff archives a request without replying. Student must still be able to archive the completed/no-response item.
- Repeat with offline/reconnect on the student device and verify queued writes are eventually synchronized once, not duplicated.

Pass condition: request, reply, read, withdraw and archive transitions are consistent on all devices and each badge equals the actual pending count.

## 6. Teacher Journey

- Confirm Home, Class, Relay and Report each open a distinct, purposeful workspace.
- Create, rename, switch and delete classes; copy/reset join codes.
- Search or select a student, inspect only post-join data and assign/retract work.
- Review live assignment progress and completed answer details.
- Reply to, archive and refresh support requests.
- Create a volunteer invitation, approve or reject a join request and remove an approved volunteer.
- Confirm a removed volunteer immediately loses the class queue.
- Open reports in empty, loading, populated and offline states.

Pass condition: no control is decorative, destructive actions require confirmation and teacher access never crosses class boundaries.

## 7. Volunteer And Administrator Journey

- Register a volunteer and confirm it remains pending until reviewed.
- Upload up to five evidence files; confirm total-size guidance, file names and submission status.
- In the administrator portal, preview each evidence file, request supplementation with a reason, reject with a reason and approve an eligible resubmission.
- Confirm the applicant sees the exact review reason and a clear next action.
- Approved volunteer enters a class invitation code and remains pending until the teacher approves.
- Confirm Home, Class, Relay and Records each open correctly.
- Reply only to requests in approved service classes, then archive and inspect the record.
- Leave a class and confirm its requests and badges disappear immediately.

Pass condition: platform approval and class approval are separate; evidence remains private; unauthorized volunteers see no student records.

## 8. Privacy, Data And Safety

- Verify privacy policy, support URL and `englishplus.tw@gmail.com` on the consent and account screens.
- Confirm AI disclosure explains external processing and that AI failure never blocks core practice.
- Turn crash diagnostics on and off. It must default off and mention that learning content and identity are not sent.
- Export or inspect account data if available, then request account deletion.
- Confirm deletion signs the user out and removes personal access while retaining only the disclosed anonymous statistics.
- Enter a high-risk emotional message. Confirm the app presents human-help choices without claiming medical care or silently notifying staff.

Pass condition: data use is understandable, optional processing is truly optional and sensitive controls do not overpromise safety services.

## 9. Appearance, Accessibility And Reliability

- Repeat primary journeys in Light and Dark appearance.
- Repeat at Accessibility Extra Extra Extra Large text on the smallest supported iPhone and a Pro Max-sized device.
- Check VoiceOver labels and reading order for role choice, authentication, question options, progress, badges and destructive confirmations.
- Check Reduce Motion, landscape interruption, background/foreground and network loss/recovery.
- Rapidly switch tabs and repeatedly open/close sheets. Confirm there is no crash, doubled tab bar, stale overlay or scroll jump.
- Confirm loading, empty, offline and failure screens always offer a useful recovery action.

Pass condition: text remains readable, primary actions remain hittable and no layout or state becomes unusable under supported settings.

## 10. Release Decision

Do not promote the build when any of these remain:

- Crash, data loss, unauthorized access or cross-account data exposure.
- Broken Google/Apple/Email first-use sign-in.
- Assignment or support state that disagrees across devices after reconnect.
- AI answer leakage before submission or a bundled provider key.
- Unreadable Dark Mode, blocked accessibility text or an unreachable primary action.
- Privacy/support links, account deletion or volunteer evidence review failure.

Release only when all critical and high-severity findings are fixed and rerun, all other findings have an owner and the final TestFlight regression is recorded.
