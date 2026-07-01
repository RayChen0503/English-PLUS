import SwiftUI

struct PracticeCenterView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    @State private var selectedPracticeType: QuestionType?
    @State private var selectedPracticeLevel: QuestionLevel?
    @State private var practiceIndex = 0
    @State private var practiceAnswer = ""
    @State private var practiceResult: PracticeResult?
    @State private var practiceAIResponse: AiProxyResponse?
    @State private var wrongAnswerAIResponse: AiProxyResponse?
    @State private var isLoadingPracticeAI = false
    @State private var isLoadingWrongAnswerAI = false

    private let questionBankItems = SeedData.approvedQuestionBankItems

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard
                        filterCard
                        currentPracticeCard
                        aiRecommendationCard
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("練習中心")
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.title2)
                    .foregroundStyle(EPTheme.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("自由練習")
                        .font(.title3.bold())
                        .foregroundStyle(EPTheme.ink)
                    Text("這裡可以自行選題型與難度。自由練習不影響今日任務進度，但答錯時仍可請 AI 解釋。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                PracticeStatPill(title: "題庫", value: "\(questionBankItems.count) 題")
                PracticeStatPill(title: "目前篩選", value: filteredCountText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("選擇想練的題型與難度")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            VStack(alignment: .leading, spacing: 8) {
                Text("題型")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(typeFilterOptions) { option in
                        PracticeFilterChip(
                            title: option.title,
                            count: countText(for: option.type),
                            isSelected: selectedPracticeType == option.type
                        ) {
                            selectPracticeType(option.type)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("難度")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                    ForEach(levelFilterOptions) { option in
                        PracticeFilterChip(
                            title: option.title,
                            count: nil,
                            isSelected: selectedPracticeLevel == option.level
                        ) {
                            selectPracticeLevel(option.level)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var currentPracticeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("目前題目")
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Spacer()
                Text(positionText)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if let item = currentPracticeItem {
                questionMetaRow(item)

                Text(item.question.prompt)
                    .font(.title3.bold())
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if item.question.options.isEmpty {
                    TextField("輸入你的答案", text: $practiceAnswer, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                } else {
                    VStack(spacing: 8) {
                        ForEach(item.question.options, id: \.self) { option in
                            PracticeAnswerOptionButton(
                                option: option,
                                isSelected: option == practiceAnswer
                            ) {
                                practiceAnswer = option
                                practiceResult = nil
                                wrongAnswerAIResponse = nil
                            }
                        }
                    }
                }

                if let practiceResult {
                    PracticeResultCard(
                        result: practiceResult,
                        aiResponse: wrongAnswerAIResponse,
                        isLoadingAI: isLoadingWrongAnswerAI
                    )
                }

                HStack(spacing: 10) {
                    Button("送出答案") {
                        submitPracticeAnswer(for: item)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(normalizedPracticeAnswer(practiceAnswer).isEmpty)
                    .opacity(normalizedPracticeAnswer(practiceAnswer).isEmpty ? 0.45 : 1)

                    Button {
                        nextPracticeQuestion()
                    } label: {
                        Label("下一題", systemImage: "arrow.right.circle")
                            .font(.subheadline.bold())
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                PracticeEmptyState()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var aiRecommendationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(EPTheme.support)
                VStack(alignment: .leading, spacing: 4) {
                    Text("不知道要練什麼？")
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text("可以依照最近表現請 AI 推薦下一步。這是驗證 AI 是否連線的另一個入口。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                Task {
                    await requestPracticeRecommendation()
                }
            } label: {
                Label(isLoadingPracticeAI ? "AI 正在推薦..." : "請 AI 推薦練習", systemImage: "wand.and.stars")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoadingPracticeAI)

            if isLoadingPracticeAI {
                ProgressView()
                    .tint(EPTheme.primary)
            }

            if let practiceAIResponse {
                PracticeAIRecommendationView(response: practiceAIResponse)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.support.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var typeFilterOptions: [PracticeTypeFilter] {
        [PracticeTypeFilter(title: "全部", type: nil)]
            + QuestionType.allCases.map { PracticeTypeFilter(title: $0.title, type: $0) }
    }

    private var levelFilterOptions: [PracticeLevelFilter] {
        [PracticeLevelFilter(title: "全部", level: nil)]
            + QuestionLevel.allCases.map { PracticeLevelFilter(title: $0.uiTitle, level: $0) }
    }

    private var filteredPracticeItems: [QuestionBankItem] {
        questionBankItems.filter { item in
            let typeMatches = selectedPracticeType == nil || item.question.type == selectedPracticeType
            let levelMatches = selectedPracticeLevel == nil || item.level == selectedPracticeLevel
            return typeMatches && levelMatches
        }
    }

    private var currentPracticeItem: QuestionBankItem? {
        guard !filteredPracticeItems.isEmpty else { return nil }
        let index = min(practiceIndex, filteredPracticeItems.count - 1)
        return filteredPracticeItems[index]
    }

    private var filteredCountText: String {
        filteredPracticeItems.isEmpty ? "沒有題目" : "\(filteredPracticeItems.count) 題"
    }

    private var positionText: String {
        guard !filteredPracticeItems.isEmpty else { return "0 / 0" }
        return "\(min(practiceIndex + 1, filteredPracticeItems.count)) / \(filteredPracticeItems.count)"
    }

    private var preferredQuestionTypesForAI: [QuestionType] {
        if let selectedPracticeType {
            return [selectedPracticeType]
        }
        return learningRepository.defaultPreferredQuestionTypes
    }

    private var currentClassId: String {
        appState.currentProfile?.classId ?? "YILAN-CHENGZHI-8A"
    }

    private func questionMetaRow(_ item: QuestionBankItem) -> some View {
        HStack(spacing: 8) {
            Text(item.question.type.title)
            Text(item.level.uiTitle)
            Text(item.skill)
        }
        .font(.caption.bold())
        .foregroundStyle(EPTheme.primary)
    }

    private func count(for type: QuestionType?) -> Int {
        guard let type else { return questionBankItems.count }
        return questionBankItems.filter { $0.question.type == type }.count
    }

    private func countText(for type: QuestionType?) -> String {
        "\(count(for: type))"
    }

    private func selectPracticeType(_ type: QuestionType?) {
        selectedPracticeType = type
        resetPracticePosition()
    }

    private func selectPracticeLevel(_ level: QuestionLevel?) {
        selectedPracticeLevel = level
        resetPracticePosition()
    }

    private func resetPracticePosition() {
        practiceIndex = 0
        practiceAnswer = ""
        practiceResult = nil
        wrongAnswerAIResponse = nil
    }

    private func submitPracticeAnswer(for item: QuestionBankItem) {
        let normalizedAnswer = normalizedPracticeAnswer(practiceAnswer)
        let acceptedAnswers = ([item.question.answer] + item.question.acceptedAnswers)
            .map(normalizedPracticeAnswer)
        let isCorrect = acceptedAnswers.contains(normalizedAnswer)

        let result = PracticeResult(
            isCorrect: isCorrect,
            acceptedAnswer: item.question.answer,
            explanation: item.question.explanation,
            repairHint: item.question.repairHint
        )
        practiceResult = result
        wrongAnswerAIResponse = nil

        guard !isCorrect else { return }
        let attempt = MissionAttempt(
            id: "practice-\(UUID().uuidString)",
            missionId: "free-practice",
            questionId: item.id,
            prompt: item.question.prompt,
            selectedAnswer: practiceAnswer,
            acceptedAnswer: item.question.answer,
            isCorrect: false,
            attemptNumber: 1,
            explanation: item.question.explanation,
            repairHint: item.question.repairHint,
            createdAt: Date()
        )
        isLoadingWrongAnswerAI = true
        Task {
            let context = WrongAnswerAIContext(
                classId: currentClassId,
                studentUid: appState.currentUser?.id,
                attempt: attempt,
                questionItem: item
            )
            wrongAnswerAIResponse = await appState.explainWrongAnswerWithAI(context: context)
            isLoadingWrongAnswerAI = false
        }
    }

    private func nextPracticeQuestion() {
        guard !filteredPracticeItems.isEmpty else { return }
        practiceIndex = (practiceIndex + 1) % filteredPracticeItems.count
        practiceAnswer = ""
        practiceResult = nil
        wrongAnswerAIResponse = nil
    }

    private func normalizedPracticeAnswer(_ answer: String) -> String {
        answer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func requestPracticeRecommendation() async {
        isLoadingPracticeAI = true
        let context = PracticeRecommendationAIContext(
            classId: currentClassId,
            studentUid: appState.currentUser?.id,
            recentAccuracy: learningRepository.recentAccuracy,
            recentWeakSkills: learningRepository.recentWeakSkills,
            preferredQuestionTypes: preferredQuestionTypesForAI
        )
        practiceAIResponse = await appState.recommendPracticeWithAI(context: context)
        isLoadingPracticeAI = false
    }
}

private struct PracticeTypeFilter: Identifiable, Equatable {
    let title: String
    let type: QuestionType?

    var id: String {
        type?.rawValue ?? "all-types"
    }
}

private struct PracticeLevelFilter: Identifiable, Equatable {
    let title: String
    let level: QuestionLevel?

    var id: String {
        level?.rawValue ?? "all-levels"
    }
}

private struct PracticeResult: Equatable {
    let isCorrect: Bool
    let acceptedAnswer: String
    let explanation: String
    let repairHint: String
}

private struct PracticeStatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct PracticeFilterChip: View {
    let title: String
    let count: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                if let count {
                    Text(count)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? .white.opacity(0.22) : EPTheme.primary.opacity(0.10))
                        .clipShape(Capsule())
                }
            }
            .font(.caption.bold())
            .frame(maxWidth: .infinity, minHeight: 38)
            .foregroundStyle(isSelected ? .white : EPTheme.ink)
            .background(isSelected ? EPTheme.primary : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        }
        .buttonStyle(.plain)
    }
}

private struct PracticeAnswerOptionButton: View {
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

private struct PracticeResultCard: View {
    let result: PracticeResult
    let aiResponse: AiProxyResponse?
    let isLoadingAI: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                result.isCorrect ? "答對了" : "先修一下這題",
                systemImage: result.isCorrect ? "checkmark.circle.fill" : "lightbulb"
            )
            .font(.headline)
            .foregroundStyle(result.isCorrect ? EPTheme.support : EPTheme.warning)

            if !result.isCorrect {
                Text("正確答案：\(result.acceptedAnswer)")
                    .font(.subheadline.bold())
                    .foregroundStyle(EPTheme.ink)
            }

            Text(result.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if isLoadingAI {
                Label("AI 正在補充解釋...", systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(EPTheme.primary)
            } else if let aiResponse {
                PracticeAIStatusCard(response: aiResponse, title: "AI 錯題詳解")
            } else if !result.isCorrect {
                Text("提示：\(result.repairHint)")
                    .font(.footnote.bold())
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(result.isCorrect ? EPTheme.support.opacity(0.12) : EPTheme.warning.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct PracticeAIRecommendationView: View {
    let response: AiProxyResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PracticeAIStatusCard(response: response, title: "AI 練習建議")

            if let action = response.output.recommendedNextAction, !action.isEmpty {
                Text(action)
                    .font(.footnote.bold())
                    .foregroundStyle(EPTheme.support)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct PracticeAIStatusCard: View {
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
            if let whyWrong = response.output.whyWrong, !whyWrong.isEmpty {
                Text(whyWrong)
                    .font(.footnote)
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let hint = response.output.nextHint, !hint.isEmpty {
                Text("下一步：\(hint)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PracticeEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("目前沒有符合條件的題目", systemImage: "tray")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            Text("可以放寬題型或難度，再回來選題。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}
