import SwiftUI

struct StudentHomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    @State private var moodScore = 3
    @State private var timeLevel = 3
    @State private var wantsChallenge = false
    @State private var selectedTypes = Set<QuestionType>()
    @State private var selectedAnswer = ""
    @State private var isGeneratingMissionWithAI = false
    @State private var isExplainingWrongAnswer = false
    @State private var latestWrongAnswerAIResponse: AiProxyResponse?

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        if learningRepository.currentMission == nil {
                            checkInCard
                        } else {
                            missionCard
                        }

                        freePracticeCard
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("首頁")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.signOut()
                    } label: {
                        Label("登出", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .onAppear(perform: initializePreferredTypes)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("嗨，\(appState.currentUser?.displayName ?? "同學")")
                .font(.title.bold())
                .foregroundStyle(EPTheme.ink)
            Text(learningRepository.currentMission == nil
                ? "先做一個短短的心情檢測，English+ 會用 AI 幫你排今天最適合的任務。"
                : "照著今日任務前進。答對才會增加進度，完成後可以自由練習。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var checkInCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("開始心情檢測")
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Text("這裡只問四題。系統會依照你的狀態、時間與想練的題型，產生今日任務。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScaleSelector(
                title: "1. 今天的心情量表",
                lowLabel: "1 很低落",
                highLabel: "5 很不錯",
                value: $moodScore
            )

            ScaleSelector(
                title: "2. 今天有足夠的時間練習英文嗎？",
                lowLabel: "1 很少",
                highLabel: "5 很充足",
                value: $timeLevel
            )

            ChallengeSelector(wantsChallenge: $wantsChallenge)

            QuestionTypePicker(
                types: learningRepository.supportedQuestionTypes,
                selectedTypes: $selectedTypes
            )

            Button(isGeneratingMissionWithAI ? "AI 正在安排任務..." : "產生今日任務") {
                Task {
                    await generateMissionAfterAI()
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(preferredTypesInDisplayOrder.isEmpty || isGeneratingMissionWithAI)
            .opacity(preferredTypesInDisplayOrder.isEmpty || isGeneratingMissionWithAI ? 0.45 : 1)

            if isGeneratingMissionWithAI {
                Label("正在請 AI 判斷今天適合先修復、穩定練習，還是挑戰更難題。", systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(EPTheme.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var missionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let mission = learningRepository.currentMission,
               let progress = learningRepository.progressSnapshot {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("今日任務")
                                .font(.headline)
                                .foregroundStyle(EPTheme.ink)
                            Text("\(mission.track.uiTitle) · 約 \(mission.recommendedMinutes) 分鐘")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(progress.correctCount)/\(progress.targetCorrectCount)")
                            .font(.headline.bold())
                            .foregroundStyle(EPTheme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(EPTheme.primary.opacity(0.10))
                            .clipShape(Capsule())
                    }

                    ProgressView(value: progress.progressFraction)
                        .tint(EPTheme.primary)
                    Text(progress.progressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let response = appState.latestAIResponse, response.taskType == .dailyMission {
                    AIStatusCard(response: response, title: "AI 任務安排")
                }

                Text("答對才會增加進度。答錯時會保留這題，先看提示再重試。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if progress.status == .completed {
                    CompletionCard()
                } else if let item = learningRepository.nextMissionQuestion {
                    missionQuestionView(item)
                }

                if let attempt = learningRepository.latestMissionAttempt {
                    FeedbackCard(
                        attempt: attempt,
                        aiResponse: latestWrongAnswerAIResponse,
                        isLoadingAI: isExplainingWrongAnswer
                    )
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var freePracticeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("自由練習")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            Text("完成今日任務後，可以到練習中心自由挑題。自由練習不會影響今日任務進度。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private func missionQuestionView(_ item: QuestionBankItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.question.type.title)
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.primary)
                Text(item.level.uiTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(item.question.prompt)
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if item.question.options.isEmpty {
                TextField("輸入答案", text: $selectedAnswer, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
            } else {
                VStack(spacing: 8) {
                    ForEach(item.question.options, id: \.self) { option in
                        AnswerOptionButton(
                            option: option,
                            isSelected: option == selectedAnswer
                        ) {
                            selectedAnswer = option
                        }
                    }
                }
            }

            Button("送出答案") {
                submitMissionAnswerWithAI(for: item)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(selectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(selectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
    }

    private var preferredTypesInDisplayOrder: [QuestionType] {
        QuestionType.allCases.filter { selectedTypes.contains($0) }
    }

    private var currentClassId: String {
        appState.currentProfile?.classId ?? "YILAN-CHENGZHI-8A"
    }

    private func initializePreferredTypes() {
        guard selectedTypes.isEmpty else { return }
        selectedTypes = Set(learningRepository.defaultPreferredQuestionTypes)
    }

    private func generateMissionAfterAI() async {
        guard !preferredTypesInDisplayOrder.isEmpty else { return }
        isGeneratingMissionWithAI = true
        let aiContext = DailyMissionAIContext(
            classId: currentClassId,
            studentUid: appState.currentUser?.id,
            moodScore: moodScore,
            availableTimeLevel: timeLevel,
            wantsChallenge: wantsChallenge,
            preferredQuestionTypes: preferredTypesInDisplayOrder,
            recentAccuracy: learningRepository.recentAccuracy,
            recentWeakSkills: learningRepository.recentWeakSkills
        )
        let aiResponse = await appState.generateDailyMissionWithAI(context: aiContext)
        learningRepository.generateMission(
            for: appState.currentUser,
            profile: appState.currentProfile,
            moodScore: moodScore,
            availableTimeLevel: timeLevel,
            wantsChallenge: wantsChallenge,
            preferredQuestionTypes: preferredTypesInDisplayOrder,
            aiMission: aiResponse.output.mission
        )
        selectedAnswer = ""
        latestWrongAnswerAIResponse = nil
        isGeneratingMissionWithAI = false
    }

    private func submitMissionAnswerWithAI(for item: QuestionBankItem) {
        guard let attempt = learningRepository.submitMissionAnswer(selectedAnswer) else { return }
        selectedAnswer = ""
        latestWrongAnswerAIResponse = nil

        guard !attempt.isCorrect else { return }
        isExplainingWrongAnswer = true
        Task {
            let aiContext = WrongAnswerAIContext(
                classId: currentClassId,
                studentUid: appState.currentUser?.id,
                attempt: attempt,
                questionItem: item
            )
            latestWrongAnswerAIResponse = await appState.explainWrongAnswerWithAI(context: aiContext)
            isExplainingWrongAnswer = false
        }
    }
}

private struct ScaleSelector: View {
    let title: String
    let lowLabel: String
    let highLabel: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.ink)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { score in
                    Button {
                        value = score
                    } label: {
                        Text("\(score)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(value == score ? .white : EPTheme.primary)
                            .background(value == score ? EPTheme.primary : EPTheme.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text(lowLabel)
                Spacer()
                Text(highLabel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct ChallengeSelector: View {
    @Binding var wantsChallenge: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("3. 今天會想要挑戰更難的題目嗎？")
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.ink)
            HStack(spacing: 10) {
                challengeButton(title: "想挑戰", value: true)
                challengeButton(title: "先穩定練", value: false)
            }
        }
    }

    private func challengeButton(title: String, value: Bool) -> some View {
        Button {
            wantsChallenge = value
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(wantsChallenge == value ? .white : EPTheme.primary)
                .background(wantsChallenge == value ? EPTheme.primary : EPTheme.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct QuestionTypePicker: View {
    let types: [QuestionType]
    @Binding var selectedTypes: Set<QuestionType>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("4. 想要多練習哪幾種題型？")
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.ink)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 124), spacing: 8)], spacing: 8) {
                ForEach(types) { type in
                    Button {
                        toggle(type)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selectedTypes.contains(type) ? "checkmark.circle.fill" : "circle")
                            Text(type.checkInLabel)
                        }
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(selectedTypes.contains(type) ? .white : EPTheme.primary)
                        .background(selectedTypes.contains(type) ? EPTheme.primary : EPTheme.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggle(_ type: QuestionType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
    }
}

private struct AnswerOptionButton: View {
    let option: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(option)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .foregroundStyle(isSelected ? .white : EPTheme.ink)
                .background(isSelected ? EPTheme.primary : EPTheme.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct FeedbackCard: View {
    let attempt: MissionAttempt
    let aiResponse: AiProxyResponse?
    let isLoadingAI: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                attempt.isCorrect ? "答對了" : "這題還可以再修一次",
                systemImage: attempt.isCorrect ? "checkmark.circle.fill" : "lightbulb.fill"
            )
            .font(.headline)
            .foregroundStyle(attempt.isCorrect ? EPTheme.support : EPTheme.warning)

            Text(attempt.isCorrect ? "進度已增加。繼續完成今天的小任務。" : "進度不會增加。先看提示，再重試這題。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(attempt.explanation)
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if isLoadingAI {
                Label("AI 正在產生更像老師的補充說明...", systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(EPTheme.primary)
            } else if let aiResponse {
                AIExplanationCard(response: aiResponse)
            } else if !attempt.isCorrect {
                Text("提示：\(attempt.repairHint)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background((attempt.isCorrect ? EPTheme.support : EPTheme.warning).opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct AIExplanationCard: View {
    let response: AiProxyResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AIStatusCard(response: response, title: "AI 錯題詳解")

            if let whyWrong = response.output.whyWrong, !whyWrong.isEmpty {
                Text(whyWrong)
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let hint = response.output.nextHint, !hint.isEmpty {
                Text("下一步：\(hint)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AIStatusCard: View {
    let response: AiProxyResponse
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: response.fallbackUsed ? "exclamationmark.triangle.fill" : "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(response.fallbackUsed ? EPTheme.warning : EPTheme.primary)

            Text(response.fallbackUsed
                ? "目前使用內建提示，沒有連到線上 AI。"
                : "線上 AI 已回應")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let summary = response.output.summary, !summary.isEmpty {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(EPTheme.primary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct CompletionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("今日任務完成", systemImage: "star.circle.fill")
                .font(.headline)
                .foregroundStyle(EPTheme.support)
            Text("做得很好。今天的必要任務已經完成，接下來可以休息，或到練習中心自由挑戰。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(EPTheme.support.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}
