# Network and Realtime Synchronization Status Hardening

The reported false "poor network" behavior was confirmed in source before any
product change was made.

## Confirmed root cause

- One repository session owns several Firestore listeners.
- Any listener error previously changed the whole App to `offlineFallback`,
  even when `NWPathMonitor` still reported a satisfied network path.
- A healthy sibling listener could immediately change the state back to
  listening, while the failing listener changed it back again.
- Every failure was retried with the same backoff, including permission,
  authentication, missing-index and configuration failures that a retry cannot
  repair.
- Teacher and volunteer listeners also used fixed "check your network" copy for
  every raw Firestore failure.

## Shipping behavior

- Only an unsatisfied `NWPathMonitor` path is presented as offline mode.
- A satisfied path plus a listener failure is a scoped synchronization issue,
  not a network diagnosis.
- URL transport timeouts and transient Firestore server codes retry with the
  existing bounded backoff.
- Authentication, permission, quota, index/configuration and unknown failures
  do not enter an automatic retry loop.
- Repeated equal states are deduplicated, and automatic retries keep one stable
  banner instead of alternating between failure and progress states.
- A recovered listener must remain stable through a short confirmation window
  before the warning disappears.
- A callback from a cancelled or replaced listener generation is ignored even
  when the replacement uses the same class and user scope.
- Firestore listener health is tracked by a stable component source, including
  each individual support-message thread. One failed thread no longer cancels
  or recreates the class, assignment, mastery and other support listeners.
- A healthy sibling snapshot cannot clear another component's warning. The
  warning clears only after the same source reports recovery, or after an
  explicit user retry creates a fresh listener generation.
- Component transport recovery is left to Firestore's listener transport. It
  does not enter the repository's whole-session automatic retry loop; that
  bounded backoff is reserved for failures that prevent the repository session
  itself from starting.
- Teacher and volunteer listener messages clear only after their own listener
  succeeds, so they cannot erase unrelated operation feedback.

## Release verification

- Static contract gate: `scripts/validate_network_sync_status_hardening.py`.
- Swift acceptance coverage distinguishes real disconnection, transient
  recovery, permission denial, repeated permanent failure, stale callbacks and
  component isolation. It verifies that a support-message failure does not
  restart the listener bundle or disappear after an unrelated snapshot.
- Final Swift compilation and UI execution remain part of the macOS/Xcode Cloud
  release-candidate gate. No push, deployment or Xcode Cloud run was performed
  for this local repair.
