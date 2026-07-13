from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PRACTICE = ROOT / "ios/EnglishPlus/EnglishPlus/Features/Practice/PracticeCenterView.swift"
TESTS = ROOT / "ios/EnglishPlus/EnglishPlusTests/AuthenticationFlowAcceptanceTests.swift"


def require(source: str, token: str, label: str, errors: list[str]) -> None:
    if token not in source:
        errors.append(f"missing {label}: {token}")


def main() -> int:
    practice = PRACTICE.read_text(encoding="utf-8-sig")
    tests = TESTS.read_text(encoding="utf-8-sig")
    errors: list[str] = []

    for token, label in [
        ("enum PracticeCenterPhase", "three-layer practice state"),
        ("case selection", "selection state"),
        ("case primary", "primary practice state"),
        ("case repair", "repair state"),
        ("UnfinishedPracticeSessionCard", "resume UI"),
        ("PracticeSessionDraftStore", "account-scoped persistence"),
        ("restorePracticeDraftIfNeeded", "draft restore"),
        ("persistPrimarySessionIfNeeded", "draft persistence"),
        ("suspendedPrimarySession = primarySnapshot", "primary suspension before repair"),
        ("restoreSuspendedPrimarySession", "return from repair"),
        ("practicePhase == .repair", "repair-specific completion"),
        ("practicePhase = .selection", "return to selector"),
        ("PostSubmissionAssistancePolicy.canRequestExplanation", "AI post-submit guard"),
        ("if let practiceResult", "post-submit support visibility"),
        (".disabled(practiceResult != nil)", "submitted answer lock"),
        ("practiceRecommendationRequestId", "stale recommendation response protection"),
        ("practiceQuestionAIRequestId", "stale question AI response protection"),
        ("supportRequestId", "stale support request protection"),
        (".id(practicePhase)", "top-aligned layer transitions"),
        ("guard practiceResult == nil,", "duplicate answer submission guard"),
    ]:
        require(practice, token, label, errors)

    if "startPracticeSession(" in practice:
        errors.append("legacy destructive practice session launcher still exists")
    if "private func explainPracticeWrongAnswer" in practice:
        errors.append("practice submission still starts the obsolete automatic AI request")

    for token, label in [
        ("PracticeSessionDraftAcceptanceTests", "draft acceptance suite"),
        ("testDraftRoundTripPreservesQuestionPositionAndSubmittedResult", "round-trip test"),
        ("testDraftsAreIsolatedBetweenAccounts", "account isolation test"),
        ("testClearingOneAccountDoesNotClearAnotherAccountDraft", "scoped clear test"),
        ("testMalformedDraftFailsClosed", "malformed draft test"),
    ]:
        require(tests, token, label, errors)

    if errors:
        print("FIX-B practice flow validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("FIX-B practice flow contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
