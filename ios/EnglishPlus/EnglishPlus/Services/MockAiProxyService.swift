import Foundation

struct MockAiProxyService: AiProxyService {
    private let seedSnapshot: SeedDataSnapshot

    init(seedSnapshot: SeedDataSnapshot = SeedData.current) {
        self.seedSnapshot = seedSnapshot
    }

    func run(_ request: AiProxyRequest, currentUser: DemoUser?) async -> AiProxyResponse {
        switch request.taskType {
        case .dailyMission:
            return dailyMissionResponse(for: request, currentUser: currentUser)
        case .wrongAnswerExplanation:
            return wrongAnswerResponse(for: request)
        case .progressSummary:
            return practiceRecommendationResponse(for: request)
        case .teacherFeedbackDraft:
            return staffDraftResponse(for: request, isTeacher: true)
        case .volunteerReplyCoach:
            return staffDraftResponse(for: request, isTeacher: false)
        case .emotionalSupport:
            return generalFallbackResponse(for: request)
        }
    }

    private func dailyMissionResponse(
        for request: AiProxyRequest,
        currentUser: DemoUser?
    ) -> AiProxyResponse {
        let minutes = recommendedMinutes(for: request.context.availableTimeLevel)
        let targetCorrect = targetCorrectCount(for: minutes)
        let track = missionTrack(for: request.context)
        let preferredTypes = request.context.preferredQuestionTypes
            ?? seedSnapshot.dailyMissionRules.defaultPreferredQuestionTypes.map(\.aiProxyValue)
        let plan = buildQuestionPlan(preferredTypes: preferredTypes, targetCorrect: targetCorrect)

        let displayName = currentUser?.displayName ?? "同學"
        return AiProxyResponse(
            ok: false,
            fallbackUsed: true,
            taskType: request.taskType,
            qualityMode: request.qualityMode,
            modelUsed: "local-seed-fallback",
            output: AiProxyOutput(
                summary: "\(displayName)，先做一個 \(minutes) 分鐘的低壓任務。",
                mission: AiMissionOutput(
                    track: track,
                    targetCorrectCount: targetCorrect,
                    recommendedMinutes: minutes,
                    questionPlan: plan
                )
            ),
            usage: AiProxyUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0),
            requestId: "local-\(UUID().uuidString)",
            errorCode: "LOCAL_AI_PROXY_NOT_CONNECTED"
        )
    }

    private func wrongAnswerResponse(for request: AiProxyRequest) -> AiProxyResponse {
        let nextHint = request.context.explanation ?? "先看題目問的是哪個文法或關鍵字，再試一次。"
        return AiProxyResponse(
            ok: false,
            fallbackUsed: true,
            taskType: request.taskType,
            qualityMode: request.qualityMode,
            modelUsed: "local-seed-fallback",
            output: AiProxyOutput(
                summary: "先把錯題拆小，再重試一次。",
                shortFeedback: "這題不是你完全不會，是有一個小規則卡住。",
                whyWrong: request.context.correctAnswer.map { "正確答案是 \($0)，先對照題目線索。" },
                nextHint: nextHint,
                tryAgain: true,
                staffEscalationNeeded: false
            ),
            usage: AiProxyUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0),
            requestId: "local-\(UUID().uuidString)",
            errorCode: "LOCAL_AI_PROXY_NOT_CONNECTED"
        )
    }

    private func generalFallbackResponse(for request: AiProxyRequest) -> AiProxyResponse {
        AiProxyResponse(
            ok: false,
            fallbackUsed: true,
            taskType: request.taskType,
            qualityMode: request.qualityMode,
            modelUsed: "local-seed-fallback",
            output: AiProxyOutput(
                summary: "先提供一個安全、簡短的下一步建議。",
                supportLevel: "humanSupport",
                recommendedNextAction: "請老師或志工確認下一步。"
            ),
            usage: AiProxyUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0),
            requestId: "local-\(UUID().uuidString)",
            errorCode: "LOCAL_AI_PROXY_NOT_CONNECTED"
        )
    }

    private func practiceRecommendationResponse(for request: AiProxyRequest) -> AiProxyResponse {
        let preferredTypes = request.context.preferredQuestionTypes ?? ["multipleChoice", "fillBlank"]
        let firstType = preferredTypes.first ?? "multipleChoice"
        let secondType = preferredTypes.dropFirst().first ?? "fillBlank"
        let focusSkills = Array((request.context.recentWeakSkills ?? []).prefix(3))
        let focusText = focusSkills.first ?? "最近卡點"

        return AiProxyResponse(
            ok: false,
            fallbackUsed: true,
            taskType: request.taskType,
            qualityMode: request.qualityMode,
            modelUsed: "local-seed-fallback",
            output: AiProxyOutput(
                summary: "先用一組短練習確認 \(focusText)，完成後再決定是否提高難度。",
                recommendedNextAction: "套用題組並直接開始作答。",
                practicePlan: AiPracticePlanOutput(
                    title: "\(focusText) 複習",
                    targetQuestionCount: 8,
                    focusSkills: focusSkills,
                    questionPlan: [
                        AiQuestionPlanItem(type: firstType, difficulty: "core", targetCorrect: 4),
                        AiQuestionPlanItem(type: secondType, difficulty: "exam", targetCorrect: 4),
                    ]
                )
            ),
            usage: AiProxyUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0),
            requestId: "local-\(UUID().uuidString)",
            errorCode: "LOCAL_AI_PROXY_NOT_CONNECTED"
        )
    }

    private func staffDraftResponse(for request: AiProxyRequest, isTeacher: Bool) -> AiProxyResponse {
        let roleText = isTeacher ? "老師" : "志工"
        let obstacle = request.context.explanation ?? request.context.supportReason ?? "這題的規則還不穩定"
        return AiProxyResponse(
            ok: false,
            fallbackUsed: true,
            taskType: request.taskType,
            qualityMode: request.qualityMode,
            modelUsed: "local-seed-fallback",
            output: AiProxyOutput(
                summary: isTeacher ? nil : "學生需要先釐清一個小規則，再重試原題。",
                teacherSummary: isTeacher ? "學生目前的卡點：\(obstacle)" : nil,
                studentFacingFeedback: "先別急，我們先找出題目的關鍵字，再把答案代回句子檢查一次。",
                recommendedNextAction: "請\(roleText)確認學生能否用自己的話說出規則。"
            ),
            usage: AiProxyUsage(promptTokens: 0, completionTokens: 0, totalTokens: 0),
            requestId: "local-\(UUID().uuidString)",
            errorCode: "LOCAL_AI_PROXY_NOT_CONNECTED"
        )
    }

    private func recommendedMinutes(for availableTimeLevel: Int?) -> Int {
        let scale = availableTimeLevel ?? 3
        return seedSnapshot.dailyMissionRules.timeScaleRules
            .first { $0.timeScale == scale }?
            .minutes ?? 5
    }

    private func targetCorrectCount(for minutes: Int) -> Int {
        seedSnapshot.dailyMissionRules.goalRules
            .first { rule in
                if let maxMinutes = rule.maxMinutes {
                    return rule.minMinutes <= minutes && minutes <= maxMinutes
                }
                return minutes >= rule.minMinutes
            }?
            .questionGoal ?? 3
    }

    private func missionTrack(for context: AiProxyContext) -> AiMissionTrack {
        if let moodScore = context.moodScore, moodScore <= 2 {
            return .repair
        }

        if context.wantsChallenge == true, let recentAccuracy = context.recentAccuracy, recentAccuracy >= 0.8 {
            return .challenge
        }

        return .steady
    }

    private func buildQuestionPlan(
        preferredTypes: [String],
        targetCorrect: Int
    ) -> [AiQuestionPlanItem] {
        let types = preferredTypes.isEmpty ? ["multipleChoice"] : preferredTypes
        let selectedTypes = Array(types.prefix(3))
        var remaining = max(targetCorrect, 1)

        return selectedTypes.enumerated().map { index, type in
            let slotsLeft = max(selectedTypes.count - index, 1)
            let count = max(1, Int(ceil(Double(remaining) / Double(slotsLeft))))
            remaining = max(remaining - count, 0)
            return AiQuestionPlanItem(
                type: type,
                difficulty: "foundation",
                targetCorrect: count
            )
        }
    }
}
