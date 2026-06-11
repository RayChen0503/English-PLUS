# GitHub Desktop Main-Branch Workflow

This workflow is for the English+ iOS teammate. The project decision is to work directly on `main`.

## First Setup

1. Install GitHub Desktop.
2. Sign in with your GitHub account.
3. Make sure the repository owner has added you as a collaborator.
4. Clone:

```text
https://github.com/RayChen0503/English-PLUS.git
```

5. Local path suggestion:

```text
~/Documents/English-PLUS
```

6. Confirm branch:

```text
main
```

## Start Of Every Work Session

1. Open GitHub Desktop.
2. Select `English-PLUS`.
3. Click `Fetch origin`.
4. If a `Pull origin` button appears, click it.
5. Open the Xcode project after pulling latest changes.

## Commit Rule

Commit small, working chunks:

```text
Add EnglishPlus Xcode project
Add SwiftUI role choice flow
Add local seed question loader
Add student daily mission screen
Add teacher dashboard shell
```

Avoid vague messages:

```text
update
fix
stuff
new
```

## Push Rule

After every commit:

```text
Push origin
```

This keeps the Windows side and Mac side aligned.

## If GitHub Desktop Shows A Fork Prompt

Stop.

This means the teammate probably does not have write access to the repository. Ask the repository owner to add collaborator access before continuing.

## If GitHub Desktop Shows A Conflict

Do not guess.

Send the conflict screenshot to the repository owner or project lead. Resolve conflicts only after understanding which version should win.

## Files That Should Not Be Committed

Do not commit:

```text
GoogleService-Info.plist
functions/.secret.local
OpenRouter API keys
personal notes with real student data
DerivedData
```

The real Firebase config can be added later if the repository privacy model is reviewed, but it should not be committed by accident during early handoff.
