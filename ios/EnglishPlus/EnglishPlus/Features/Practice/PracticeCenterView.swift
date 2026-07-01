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
    @State private var isLoadingPracticeAI = false

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
                    Text("這裡可以自由挑題，不會改變今日任務進度。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                PracticeStatPill(title: "題庫", value: "\(questionBankItems.count) 題")
                PracticeStatPill(title: "目前", value: filteredCountText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("選擇你想練的方向")
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
                Text("開始作答")
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
                        .onChange(of: practiceAnswer) { _ in
                            practiceResult = nil
                        }
                } else {
                    VStack(spacing: 8) {
                        ForEach(item.question.options, id: \.self) { option in
                            PracticeAnswerOptionButton(
                                option: option,
                                isSelected: option == practiceAnswer
                            ) {
                                practiceAnswer = option
                                practiceResult = nil
                            }
                        }
                    }
                }

                if let practiceResult {
                    PracticeResultCard(result: practiceResult)
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
                    Text("下一步練什麼")
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text("可以根據近期答題狀況，請 AI 給你一個簡短練習方向。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task {
                    await requestPracticeRecommendation()
                }
            } label: {
                Label(isLoadingPracticeAI ? "正在整理建議" : "取得練習建議", systemImage: "wand.and.stars")
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
    }

    private func submitPracticeAnswer(for item: QuestionBankItem) {
        let normalizedAnswer = normalizedPracticeAnswer(practiceAnswer)
        let acceptedAnswers = ([item.question.answer] + item.question.acceptedAnswers)
            .map(normalizedPracticeAnswer)
        let isCorrect = acceptedAnswers.contains(normalizedAnswer)

        practiceResult = PracticeResult(
            isCorrect: isCorrect,
            acceptedAnswer: item.question.answer,
            explanation: item.question.explanation,
            repairHint: item.question.repairHint
        )
    }

    private func nextPracticeQuestion() {
        guard !filteredPracticeItems.isEmpty else { return }
        practiceIndex = (practiceIndex + 1) % filteredPracticeItems.count
        practiceAnswer = ""
        practiceResult = nil
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                result.isCorrect ? "答對了" : "再修正一下",
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

            Text(result.repairHint)
                .font(.footnote.bold())
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
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
            Text(response.output.summary ?? "先選一個想練的題型，完成三題後再回來看建議。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let action = response.output.recommendedNextAction {
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

private struct PracticeEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("這個組合暫時沒有題目", systemImage: "tray")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            Text("換一個題型或難度，就可以繼續練習。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}
