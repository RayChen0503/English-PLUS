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
                        Text("早安，\(appState.currentUser?.displayName ?? "同學")")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

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
            .onAppear(perform: initializePreferredTypes)
        }
    }

    private var checkInCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("今日任務")
                    .font(.headline)
                Text("先用四題確認今天的狀態，再產生適合你的英文練習。")
                    .foregroundStyle(.secondary)
            }

            ScaleSelector(
                title: "1. 今天的心情量表",
                lowLabel: "需要陪伴",
                highLabel: "很有精神",
                value: $moodScore
            )

            ScaleSelector(
                title: "2. 今天有足夠的時間練習英文嗎",
                lowLabel: "很少",
                highLabel: "很充足",
                value: $timeLevel
            )

            ChallengeSelector(wantsChallenge: $wantsChallenge)

            QuestionTypePicker(
                types: learningRepository.supportedQuestionTypes,
                selectedTypes: $selectedTypes
            )

            Button("產生今日任務") {
                Task {
                    await generateMissionAfterAI()
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(preferredTypesInDisplayOrder.isEmpty || isGeneratingMissionWithAI)
            .opacity(preferredTypesInDisplayOrder.isEmpty || isGeneratingMissionWithAI ? 0.45 : 1)

            if isGeneratingMissionWithAI {
                Label("正在安排今天的練習", systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(EPTheme.primary)
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
                    Text("今日任務")
                        .font(.headline)
                    Text("\(mission.track.uiTitle) · 約 \(mission.recommendedMinutes) 分鐘")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress.progressFraction)
                    .tint(EPTheme.primary)
                Text(progress.progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
            Text("練習中心可以隨時進入，不會影響今日任務進度。")
                .foregroundStyle(.secondary)
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
            }

            Text(item.question.prompt)
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if item.question.options.isEmpty {
                TextField("輸入你的答案", text: $selectedAnswer, axis: .vertical)
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
        guard !attempt.isCorrect else {
            latestWrongAnswerAIResponse = nil
            return
        }

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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { item in
                    Button {
                        value = item
                    } label: {
                        Text("\(item)")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .foregroundStyle(value == item ? .white : EPTheme.ink)
                            .background(value == item ? EPTheme.primary : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
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
        VStack(alignment: .leading, spacing: 8) {
            Text("3. 今天會想要挑戰更難的題目嗎")
                .font(.subheadline.bold())
            HStack(spacing: 8) {
                ChallengeButton(title: "先穩定", isSelected: !wantsChallenge) {
                    wantsChallenge = false
                }
                ChallengeButton(title: "想挑戰", isSelected: wantsChallenge) {
                    wantsChallenge = true
                }
            }
        }
    }
}

private struct ChallengeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(isSelected ? .white : EPTheme.ink)
                .background(isSelected ? EPTheme.support : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        }
        .buttonStyle(.plain)
    }
}

private struct QuestionTypePicker: View {
    let types: [QuestionType]
    @Binding var selectedTypes: Set<QuestionType>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("4. 想要多練習哪幾種題型")
                .font(.subheadline.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
                ForEach(types) { type in
                    Button {
                        if selectedTypes.contains(type) {
                            selectedTypes.remove(type)
                        } else {
                            selectedTypes.insert(type)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selectedTypes.contains(type) ? "checkmark.circle.fill" : "circle")
                            Text(type.checkInLabel)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .foregroundStyle(selectedTypes.contains(type) ? .white : EPTheme.ink)
                        .background(selectedTypes.contains(type) ? EPTheme.primary : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AnswerOptionButton: View {
    let option: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? EPTheme.primary : .secondary)
                Text(option)
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(12)
            .background(isSelected ? EPTheme.primary.opacity(0.12) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        }
        .buttonStyle(.plain)
    }
}

private struct FeedbackCard: View {
    let attempt: MissionAttempt
    let aiResponse: AiProxyResponse?
    let isLoadingAI: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                attempt.isCorrect ? "答對了" : "再試一次",
                systemImage: attempt.isCorrect ? "checkmark.circle.fill" : "lightbulb"
            )
            .font(.headline)
            .foregroundStyle(attempt.isCorrect ? EPTheme.support : EPTheme.warning)

            if !attempt.isCorrect {
                Text("正確答案：\(attempt.acceptedAnswer)")
                    .font(.subheadline.bold())
                    .foregroundStyle(EPTheme.ink)
            }

            Text(attempt.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(attempt.repairHint)
                .font(.footnote)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if isLoadingAI {
                Label("正在整理更清楚的提示", systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(EPTheme.primary)
            }

            if let aiResponse, !attempt.isCorrect {
                AIExplanationCard(response: aiResponse)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct AIExplanationCard: View {
    let response: AiProxyResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("AI 補充說明", systemImage: "sparkles")
                .font(.caption.bold())
                .foregroundStyle(EPTheme.primary)

            if let shortFeedback = response.output.shortFeedback {
                Text(shortFeedback)
                    .font(.footnote)
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let summary = response.output.summary {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let whyWrong = response.output.whyWrong {
                Text(whyWrong)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let nextHint = response.output.nextHint {
                Text(nextHint)
                    .font(.footnote.bold())
                    .foregroundStyle(EPTheme.support)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct CompletionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("今日任務完成", systemImage: "star.circle.fill")
                .font(.headline)
                .foregroundStyle(EPTheme.support)
            Text("你已經完成今天的正確題數，可以去自由練習，或先休息一下。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.support.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}
