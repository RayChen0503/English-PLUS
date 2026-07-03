import SwiftUI

struct PracticeCenterView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    let onOpenSupport: () -> Void

    @State private var selectedPracticeType: QuestionType?
    @State private var selectedPracticeLevel: QuestionLevel?
    @State private var selectedPracticeSetId: String?
    @State private var practiceIndex = 0
    @State private var practiceAnswer = ""
    @State private var practiceResult: PracticeResult?
    @State private var practiceAIResponse: AiProxyResponse?
    @State private var recommendedPracticePlan: AIPracticeRecommendationPlan?
    @State private var practiceQuestionAIResponse: AiProxyResponse?
    @State private var wrongAnswerAIResponse: AiProxyResponse?
    @State private var practiceSupportConfirmation: String?
    @State private var activePracticeSourceTitle: String?
    @State private var practiceSelectionNote: String?
    @State private var practiceOptionOrderByQuestionId: [String: [String]] = [:]
    @State private var freePracticeSessionItems: [QuestionBankItem] = []
    @State private var freePracticeAnsweredCount = 0
    @State private var freePracticeCorrectCount = 0
    @State private var didCountCurrentPracticeAnswer = false
    @State private var isFreePracticeSessionComplete = false
    @State private var isLoadingPracticeAI = false
    @State private var isLoadingPracticeQuestionAI = false
    @State private var isLoadingWrongAnswerAI = false

    private let freePracticeSessionLimit = 10

    init(onOpenSupport: @escaping () -> Void = {}) {
        self.onOpenSupport = onOpenSupport
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard
                        filterCard
                        practiceSetSelectionCard
                        finitePracticeCard
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
                        .foregroundStyle(EPTheme.secondaryInk)
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
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var practiceSetSelectionCard: some View {
        PracticeSetSelectionCard(
            sets: visiblePracticeSets,
            selectedPracticeSetId: selectedPracticeSetId
        ) { setId in
            selectedPracticeSetId = setId
            resetPracticePosition()
        }
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("選擇想練的題型與難度")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            VStack(alignment: .leading, spacing: 8) {
                Text("題型")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.secondaryInk)
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
                    .foregroundStyle(EPTheme.secondaryInk)
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
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var finitePracticeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("這一組練習")
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Spacer()
                Text(positionText)
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.secondaryInk)
            }

            if let practiceSelectionNote, !practiceSelectionNote.isEmpty {
                Label(practiceSelectionNote, systemImage: "arrow.triangle.branch")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isFreePracticeSessionComplete {
                FreePracticeSessionSummaryCard(
                    answeredCount: freePracticeAnsweredCount,
                    correctCount: freePracticeCorrectCount,
                    totalCount: freePracticeSessionItems.count,
                    onPracticeAgain: startFreePracticeSession,
                    onReturnToMission: {
                        learningRepository.returnToMissionFlow()
                    }
                )
            } else if freePracticeSessionItems.isEmpty {
                PracticeSessionStartCard(
                    availableCount: filteredPracticeItems.count,
                    sessionLimit: min(freePracticeSessionLimit, filteredPracticeItems.count),
                    selectedSetTitle: activePracticeSourceTitle ?? selectedPracticeSet?.title ?? "全部題庫",
                    onStart: startFreePracticeSession
                )
            } else if let item = currentPracticeItem {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: freePracticeProgressFraction)
                        .tint(EPTheme.primary)
                    Text("答完 \(freePracticeSessionItems.count) 題就會結算，自由練習不會影響今日任務進度。")
                        .font(.caption)
                        .foregroundStyle(EPTheme.secondaryInk)
                }

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
                        ForEach(Array(shuffledAnswerOptions(for: item).enumerated()), id: \.offset) { _, option in
                            PracticeAnswerOptionButton(
                                option: option,
                                isSelected: option == practiceAnswer
                            ) {
                                practiceAnswer = option
                                practiceResult = nil
                                wrongAnswerAIResponse = nil
                                practiceQuestionAIResponse = nil
                                practiceSupportConfirmation = nil
                                didCountCurrentPracticeAnswer = false
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

                PracticeInlineSupportPanel(
                    aiResponse: practiceQuestionAIResponse,
                    supportConfirmation: practiceSupportConfirmation,
                    isLoadingAI: isLoadingPracticeQuestionAI,
                    onOpenSupport: onOpenSupport,
                    onAskAI: {
                        Task {
                            await askPracticeAI(for: item)
                        }
                    },
                    onSendTeacher: {
                        sendPracticeSupportRequest(for: item, target: .teacher)
                    },
                    onSendVolunteer: {
                        sendPracticeSupportRequest(for: item, target: .volunteer)
                    }
                )

                HStack(spacing: 10) {
                    Button("送出答案") {
                        submitPracticeAnswer(for: item)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(normalizedPracticeAnswer(practiceAnswer).isEmpty || practiceResult != nil)
                    .opacity((normalizedPracticeAnswer(practiceAnswer).isEmpty || practiceResult != nil) ? 0.45 : 1)

                    Button {
                        nextPracticeQuestion()
                    } label: {
                        Label(isLastFreePracticeQuestion ? "完成這組練習" : "下一題", systemImage: isLastFreePracticeQuestion ? "party.popper.fill" : "arrow.right.circle")
                            .font(.subheadline.bold())
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(practiceResult == nil)
                    .opacity(practiceResult == nil ? 0.45 : 1)
                }
            } else {
                PracticeEmptyState()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
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
                        .foregroundStyle(EPTheme.secondaryInk)
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
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isLoadingPracticeAI)

            if isLoadingPracticeAI {
                ProgressView()
                    .tint(EPTheme.primary)
            }

            if let practiceAIResponse {
                PracticeAIRecommendationView(
                    response: practiceAIResponse,
                    recommendedPracticePlan: recommendedPracticePlan,
                    onApplyRecommendation: applyAIRecommendedPracticePlan
                )
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
        let baseItems = selectedPracticeSet?.items ?? questionBankItems
        return baseItems.filter { item in
            let typeMatches = selectedPracticeType == nil || item.question.type == selectedPracticeType
            let levelMatches = selectedPracticeLevel == nil || item.level == selectedPracticeLevel
            return typeMatches && levelMatches
        }
    }

    private var selectedPracticeSet: QuestionPracticeSet? {
        guard let selectedPracticeSetId else { return nil }
        return visiblePracticeSets.first { $0.id == selectedPracticeSetId }
    }

    private var visiblePracticeSets: [QuestionPracticeSet] {
        Array(learningRepository.questionPracticeSets.prefix(18))
    }

    private var questionBankItems: [QuestionBankItem] {
        learningRepository.questionBankItems
    }

    private var currentPracticeItem: QuestionBankItem? {
        guard !freePracticeSessionItems.isEmpty else { return nil }
        let index = min(practiceIndex, freePracticeSessionItems.count - 1)
        return freePracticeSessionItems[index]
    }

    private var filteredCountText: String {
        filteredPracticeItems.isEmpty ? "沒有題目" : "\(filteredPracticeItems.count) 題"
    }

    private var positionText: String {
        guard !freePracticeSessionItems.isEmpty else { return "尚未開始" }
        return "\(min(practiceIndex + 1, freePracticeSessionItems.count)) / \(freePracticeSessionItems.count)"
    }

    private var freePracticeProgressFraction: Double {
        guard !freePracticeSessionItems.isEmpty else { return 0 }
        return Double(freePracticeAnsweredCount) / Double(freePracticeSessionItems.count)
    }

    private var isLastFreePracticeQuestion: Bool {
        !freePracticeSessionItems.isEmpty && practiceIndex >= freePracticeSessionItems.count - 1
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
        let baseItems = selectedPracticeSet?.items ?? questionBankItems
        guard let type else { return baseItems.count }
        return baseItems.filter { $0.question.type == type }.count
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
        practiceAIResponse = nil
        recommendedPracticePlan = nil
        wrongAnswerAIResponse = nil
        practiceQuestionAIResponse = nil
        practiceSupportConfirmation = nil
        activePracticeSourceTitle = nil
        practiceSelectionNote = nil
        practiceOptionOrderByQuestionId = [:]
        freePracticeSessionItems = []
        freePracticeAnsweredCount = 0
        freePracticeCorrectCount = 0
        didCountCurrentPracticeAnswer = false
        isFreePracticeSessionComplete = false
    }

    private func startFreePracticeSession() {
        let sessionSelection = buildPracticeSessionItems(from: filteredPracticeItems)
        let sessionItems = sessionSelection.items
        practiceSelectionNote = sessionSelection.note
        startPracticeSession(with: sessionItems, sourceTitle: selectedPracticeSet?.title ?? "自由練習")
    }

    private func startPracticeSession(with items: [QuestionBankItem], sourceTitle: String? = nil) {
        let sessionItems = QuestionGroupingEngine.balancedItems(from: items, limit: freePracticeSessionLimit)
        freePracticeSessionItems = sessionItems
        activePracticeSourceTitle = sourceTitle
        practiceOptionOrderByQuestionId = Dictionary(
            sessionItems.enumerated().map { index, item in
                (item.id, QuestionGroupingEngine.balancedOptions(for: item, sessionIndex: index))
            },
            uniquingKeysWith: { _, latest in latest }
        )
        practiceIndex = 0
        practiceAnswer = ""
        practiceResult = nil
        wrongAnswerAIResponse = nil
        practiceQuestionAIResponse = nil
        practiceSupportConfirmation = nil
        freePracticeAnsweredCount = 0
        freePracticeCorrectCount = 0
        didCountCurrentPracticeAnswer = false
        isFreePracticeSessionComplete = sessionItems.isEmpty
    }

    private func finishFreePracticeSession() {
        learningRepository.completeFreePracticeSession(
            correctCount: freePracticeCorrectCount,
            totalCount: freePracticeSessionItems.count
        )
        practiceAnswer = ""
        practiceResult = nil
        wrongAnswerAIResponse = nil
        practiceQuestionAIResponse = nil
        practiceSupportConfirmation = nil
        didCountCurrentPracticeAnswer = false
        isFreePracticeSessionComplete = true
    }

    private func buildAIRecommendationPlan(from response: AiProxyResponse) -> AIPracticeRecommendationPlan? {
        let searchText = recommendationSearchText(from: response)
        let inferredTypes = inferRecommendedQuestionTypes(from: searchText)
        let inferredLevels = inferRecommendedQuestionLevels(from: searchText)
        let skillHints = inferRecommendedSkillHints(from: searchText)

        let scoredItems = questionBankItems
            .map { item in
                (item: item, score: scoreAIRecommendedItem(
                    item,
                    searchText: searchText,
                    inferredTypes: inferredTypes,
                    inferredLevels: inferredLevels,
                    skillHints: skillHints
                ))
            }
            .filter { $0.score > 0 }
            .sorted { left, right in
                if left.score != right.score {
                    return left.score > right.score
                }
                return left.item.id < right.item.id
            }
            .map(\.item)
            .uniqued(by: \.id)

        let fallbackItems = fallbackAIRecommendationItems(
            inferredTypes: inferredTypes,
            inferredLevels: inferredLevels
        )
        let selection = QuestionGroupingEngine.practiceSelection(
            from: scoredItems,
            fallbackCandidates: fallbackItems,
            limit: freePracticeSessionLimit
        )
        let selectedItems = selection.items
        guard let firstItem = selectedItems.first else { return nil }

        let resolvedSkill = resolvedRecommendationSkill(from: selectedItems, skillHints: skillHints)
        let titleSkill = resolvedSkill.isEmpty ? firstItem.skill : resolvedSkill
        let title = "AI 推薦：\(firstItem.question.type.title) / \(titleSkill)"
        let subtitle = "\(selectedItems.count) 題，約 \(max(3, min(18, selectedItems.count * 2))) 分鐘"
        let note = recommendationMatchNote(
            inferredTypes: inferredTypes,
            inferredLevels: inferredLevels,
            skill: titleSkill,
            usedFallback: selection.fallbackUsed
        )

        return AIPracticeRecommendationPlan(
            id: "ai-\(firstItem.question.type.rawValue)-\(firstItem.level.rawValue)-\(selectedItems.map(\.id).joined(separator: "-"))",
            title: title,
            subtitle: subtitle,
            matchNote: note,
            type: firstItem.question.type,
            level: firstItem.level,
            skill: titleSkill,
            items: selectedItems
        )
    }

    private func recommendationSearchText(from response: AiProxyResponse) -> String {
        var parts = [
            response.output.summary,
            response.output.shortFeedback,
            response.output.whyWrong,
            response.output.nextHint,
            response.output.teacherSummary,
            response.output.studentFacingFeedback,
            response.output.recommendedNextAction,
        ].compactMap { $0 }

        if let mission = response.output.mission {
            parts.append(mission.track.rawValue)
            mission.questionPlan.forEach { planItem in
                parts.append("\(planItem.type) \(planItem.difficulty)")
            }
        }

        return parts.joined(separator: " ").lowercased()
    }

    private func inferRecommendedQuestionTypes(from searchText: String) -> [QuestionType] {
        var types: [QuestionType] = []

        func append(_ type: QuestionType, when keywords: [String]) {
            guard keywords.contains(where: { searchText.contains($0) }),
                  !types.contains(type)
            else { return }
            types.append(type)
        }

        append(.cloze, when: ["cloze", "克漏", "文意推論"])
        append(.grammar, when: ["grammar", "multiplechoice", "文法", "be 動詞", "be??", "be verb", "am is are"])
        append(.fillBlank, when: ["fillblank", "fill blank", "blank", "填空"])
        append(.reading, when: ["reading", "閱讀"])
        append(.translation, when: ["translation", "翻譯", "句子重組"])
        append(.dialogue, when: ["dialogue", "對話"])
        append(.vocabulary, when: ["vocabulary", "單字", "字彙"])

        if types.isEmpty, let selectedPracticeType {
            types.append(selectedPracticeType)
        }

        if types.isEmpty {
            types.append(contentsOf: preferredQuestionTypesForAI)
        }

        return types.uniqued()
    }

    private func inferRecommendedQuestionLevels(from searchText: String) -> [QuestionLevel] {
        var levels: [QuestionLevel] = []

        func append(_ level: QuestionLevel, when keywords: [String]) {
            guard keywords.contains(where: { searchText.contains($0.lowercased()) }),
                  !levels.contains(level)
            else { return }
            levels.append(level)
        }

        append(.a1, when: ["a1", "基礎", "低壓", "repair"])
        append(.a2, when: ["a2", "穩定", "steady"])
        append(.b1, when: ["b1", "會考", "挑戰"])
        append(.b2, when: ["b2", "進階", "高挑戰"])

        if levels.isEmpty, let selectedPracticeLevel {
            levels.append(selectedPracticeLevel)
        }

        return levels
    }

    private func inferRecommendedSkillHints(from searchText: String) -> [String] {
        let hardcodedHints = [
            "be 動詞",
            "be??",
            "be verb",
            "am",
            "is",
            "are",
            "was",
            "were",
            "克漏",
            "文意推論",
        ].filter { searchText.contains($0.lowercased()) }

        let bankSkills = questionBankItems
            .map(\.skill)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { searchText.contains($0.lowercased()) }

        let weakSkills = learningRepository.recentWeakSkills
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { searchText.contains($0.lowercased()) || searchText.isEmpty }

        return (hardcodedHints + bankSkills + weakSkills).uniqued()
    }

    private func scoreAIRecommendedItem(
        _ item: QuestionBankItem,
        searchText: String,
        inferredTypes: [QuestionType],
        inferredLevels: [QuestionLevel],
        skillHints: [String]
    ) -> Int {
        var score = 0
        let itemText = "\(item.skill) \(item.unit) \(item.question.concept) \(item.question.prompt) \(item.question.explanation)"
            .lowercased()

        if let typeIndex = inferredTypes.firstIndex(of: item.question.type) {
            score += max(70, 140 - (typeIndex * 30))
        } else if !inferredTypes.isEmpty {
            score -= 30
        } else if preferredQuestionTypesForAI.contains(item.question.type) {
            score += 16
        }

        if inferredLevels.contains(item.level) {
            score += 24
        } else if !inferredLevels.isEmpty {
            score -= 8
        }

        skillHints.forEach { hint in
            let normalizedHint = hint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !normalizedHint.isEmpty, itemText.contains(normalizedHint) {
                score += 34
            }
        }

        if !item.skill.isEmpty, searchText.contains(item.skill.lowercased()) {
            score += 48
        }

        let weakSkillMatches = learningRepository.recentWeakSkills.contains { weakSkill in
            let normalized = weakSkill.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !normalized.isEmpty && itemText.contains(normalized)
        }
        if weakSkillMatches {
            score += 28
        }

        if selectedPracticeType == item.question.type {
            score += 12
        }
        if selectedPracticeLevel == item.level {
            score += 8
        }

        return score
    }

    private func fallbackAIRecommendationItems(
        inferredTypes: [QuestionType],
        inferredLevels: [QuestionLevel]
    ) -> [QuestionBankItem] {
        QuestionGroupingEngine.balancedFallbackCandidates(
            preferredTypes: inferredTypes.isEmpty ? preferredQuestionTypesForAI : inferredTypes,
            preferredLevels: inferredLevels,
            from: questionBankItems.isEmpty ? filteredPracticeItems : questionBankItems
        )
    }

    private func buildPracticeSessionItems(from candidates: [QuestionBankItem]) -> PracticeSessionSelection {
        let selection = QuestionGroupingEngine.practiceSelection(
            from: candidates,
            fallbackCandidates: fallbackPracticeCandidates(),
            limit: freePracticeSessionLimit
        )
        let note = selection.items.isEmpty
            ? "目前題庫還沒有可用題目。"
            : (selection.fallbackUsed
                ? "目前條件題數不足，已自動放寬條件，先安排最接近的一組。"
                : nil)
        return PracticeSessionSelection(items: selection.items, note: note)
    }

    private func fallbackPracticeCandidates() -> [QuestionBankItem] {
        let allItems = questionBankItems
        let preferredTypes = selectedPracticeType.map { [$0] } ?? preferredQuestionTypesForAI
        let preferredLevels = selectedPracticeLevel.map { [$0] } ?? []
        return QuestionGroupingEngine.balancedFallbackCandidates(
            preferredTypes: preferredTypes,
            preferredLevels: preferredLevels,
            from: allItems
        )
    }

    private func balancedPracticeItems(from items: [QuestionBankItem]) -> [QuestionBankItem] {
        QuestionGroupingEngine.balancedItems(from: items, limit: freePracticeSessionLimit)
    }

    private func balancedAnswerOptions(for item: QuestionBankItem) -> [String] {
        QuestionGroupingEngine.balancedOptions(for: item)
    }

    private func shuffledAnswerOptions(for item: QuestionBankItem) -> [String] {
        practiceOptionOrderByQuestionId[item.id] ?? balancedAnswerOptions(for: item)
    }

    private func resolvedRecommendationSkill(from items: [QuestionBankItem], skillHints: [String]) -> String {
        if let matchingHint = skillHints.first(where: { hint in
            let normalizedHint = hint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !normalizedHint.isEmpty && items.contains { item in
                "\(item.skill) \(item.unit) \(item.question.concept) \(item.question.prompt)"
                    .lowercased()
                    .contains(normalizedHint)
            }
        }) {
            return matchingHint
        }

        return items.first?.skill ?? ""
    }

    private func recommendationMatchNote(
        inferredTypes: [QuestionType],
        inferredLevels: [QuestionLevel],
        skill: String,
        usedFallback: Bool
    ) -> String {
        let typeText = inferredTypes.first?.title ?? "目前條件"
        let levelText = inferredLevels.first?.uiTitle ?? "合適難度"
        let skillText = skill.isEmpty ? "最近卡點" : skill
        return usedFallback
            ? "找不到完全符合的題組，已改用最接近的 \(typeText) / \(levelText)。"
            : "依 AI 建議鎖定 \(typeText) / \(levelText)，優先練 \(skillText)。"
    }

    private func applyAIRecommendedPracticePlan(_ plan: AIPracticeRecommendationPlan) {
        selectedPracticeSetId = nil
        selectedPracticeType = plan.type
        selectedPracticeLevel = plan.level
        let sessionSelection = buildPracticeSessionItems(from: plan.items)
        startPracticeSession(with: sessionSelection.items, sourceTitle: plan.title)
        practiceSelectionNote = sessionSelection.note ?? plan.matchNote
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
        if !didCountCurrentPracticeAnswer {
            freePracticeAnsweredCount = min(freePracticeAnsweredCount + 1, freePracticeSessionItems.count)
            if isCorrect {
                freePracticeCorrectCount = min(freePracticeCorrectCount + 1, freePracticeSessionItems.count)
            }
            didCountCurrentPracticeAnswer = true
        }

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
        Task {
            await explainPracticeWrongAnswer(attempt: attempt, item: item)
        }
    }

    @MainActor
    private func explainPracticeWrongAnswer(attempt: MissionAttempt, item: QuestionBankItem) async {
        isLoadingWrongAnswerAI = true
        defer { isLoadingWrongAnswerAI = false }

        let context = WrongAnswerAIContext(
            classId: currentClassId,
            studentUid: appState.currentUser?.id,
            attempt: attempt,
            questionItem: item
        )
        wrongAnswerAIResponse = await appState.explainWrongAnswerWithAI(context: context)
    }

    @MainActor
    private func askPracticeAI(for item: QuestionBankItem) async {
        isLoadingPracticeQuestionAI = true
        defer { isLoadingPracticeQuestionAI = false }

        let answerText = normalizedPracticeAnswer(practiceAnswer).isEmpty ? "尚未作答" : practiceAnswer
        let attempt = MissionAttempt(
            id: "practice-ai-\(UUID().uuidString)",
            missionId: "free-practice",
            questionId: item.id,
            prompt: item.question.prompt,
            selectedAnswer: answerText,
            acceptedAnswer: item.question.answer,
            isCorrect: false,
            attemptNumber: 1,
            explanation: item.question.explanation,
            repairHint: item.question.repairHint,
            createdAt: Date()
        )
        let context = WrongAnswerAIContext(
            classId: currentClassId,
            studentUid: appState.currentUser?.id,
            attempt: attempt,
            questionItem: item
        )
        practiceQuestionAIResponse = await appState.explainWrongAnswerWithAI(context: context)
    }

    private func sendPracticeSupportRequest(for item: QuestionBankItem, target: PracticeSupportTarget) {
        let selectedAnswer = normalizedPracticeAnswer(practiceAnswer).isEmpty ? nil : practiceAnswer
        let option = practiceSupportOption(for: target)
        learningRepository.sendQuestionSupportRequest(
            from: appState.currentUser,
            profile: appState.currentProfile,
            option: option,
            questionItem: item,
            selectedAnswer: selectedAnswer,
            message: practiceSupportMessage(for: item, target: target)
        )
        practiceSupportConfirmation = target.confirmationText
    }

    private func practiceSupportOption(for target: PracticeSupportTarget) -> SupportOption {
        switch target {
        case .teacher:
            return SeedData.supportOptions.first { $0.id == "human-company" }
                ?? SupportOption(
                    id: "practice-teacher-help",
                    reason: "請老師協助",
                    studentText: "我想請老師看這題。",
                    platformAction: "請老師查看學生題目與答案。",
                    route: .humanHandoff
                )
        case .volunteer:
            return SeedData.supportOptions.first { $0.id == "reading-too-long" }
                ?? SupportOption(
                    id: "practice-volunteer-help",
                    reason: "請志工陪伴",
                    studentText: "我想請志工陪我看這題。",
                    platformAction: "請志工陪學生拆解題目。",
                    route: .readingBreakdown
                )
        }
    }

    private func practiceSupportMessage(for item: QuestionBankItem, target: PracticeSupportTarget) -> String {
        let answerText = normalizedPracticeAnswer(practiceAnswer).isEmpty ? "尚未作答" : practiceAnswer
        return """
        我在自由練習這題卡住，想請\(target.displayName)看一下。
        題型：\(item.question.type.title)
        難度：\(item.level.uiTitle)
        題目：\(item.question.prompt)
        我的答案：\(answerText)
        正確答案：\(item.question.answer)
        解析：\(item.question.explanation)
        """
    }

    private func nextPracticeQuestion() {
        guard !freePracticeSessionItems.isEmpty else { return }
        if isLastFreePracticeQuestion {
            finishFreePracticeSession()
            return
        }
        practiceIndex = min(practiceIndex + 1, freePracticeSessionItems.count - 1)
        practiceAnswer = ""
        practiceResult = nil
        wrongAnswerAIResponse = nil
        practiceQuestionAIResponse = nil
        practiceSupportConfirmation = nil
        didCountCurrentPracticeAnswer = false
    }

    private func normalizedPracticeAnswer(_ answer: String) -> String {
        answer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    @MainActor
    private func requestPracticeRecommendation() async {
        isLoadingPracticeAI = true
        defer { isLoadingPracticeAI = false }
        practiceAIResponse = nil
        recommendedPracticePlan = nil

        let context = PracticeRecommendationAIContext(
            classId: currentClassId,
            studentUid: appState.currentUser?.id,
            recentAccuracy: learningRepository.recentAccuracy,
            recentWeakSkills: learningRepository.recentWeakSkills,
            preferredQuestionTypes: preferredQuestionTypesForAI
        )
        let response = await appState.recommendPracticeWithAI(context: context)
        practiceAIResponse = response
        recommendedPracticePlan = buildAIRecommendationPlan(from: response)
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

private struct PracticeSessionSelection: Equatable {
    let items: [QuestionBankItem]
    let note: String?
}

private struct AIPracticeRecommendationPlan: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let matchNote: String
    let type: QuestionType
    let level: QuestionLevel
    let skill: String
    let items: [QuestionBankItem]

    var questionCount: Int {
        items.count
    }

    var estimatedMinutes: Int {
        max(3, min(18, items.count * 2))
    }
}

private enum PracticeSupportTarget {
    case teacher
    case volunteer

    var displayName: String {
        switch self {
        case .teacher:
            return "老師"
        case .volunteer:
            return "志工"
        }
    }

    var confirmationText: String {
        switch self {
        case .teacher:
            return "已送給老師，老師端會看到這一題與你的答案。"
        case .volunteer:
            return "已送給志工，志工端會看到這一題與你的答案。"
        }
    }
}

private struct PracticeStatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(EPTheme.secondarySurface)
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
                        .background(isSelected ? EPTheme.elevatedCard.opacity(0.24) : EPTheme.primary.opacity(0.10))
                        .clipShape(Capsule())
                }
            }
            .font(.caption.bold())
            .frame(maxWidth: .infinity, minHeight: 38)
            .foregroundStyle(isSelected ? .white : EPTheme.ink)
            .background(isSelected ? EPTheme.primary : EPTheme.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        }
        .buttonStyle(.plain)
    }
}

private struct PracticeSetSelectionCard: View {
    let sets: [QuestionPracticeSet]
    let selectedPracticeSetId: String?
    let onSelect: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("小題組")
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Spacer()
                Text(selectedTitle)
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    setButton(title: "全部題目", subtitle: "自由挑戰", setId: nil)
                    ForEach(sets.prefix(18)) { set in
                        setButton(
                            title: set.title,
                            subtitle: set.subtitle,
                            setId: set.id
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var selectedTitle: String {
        guard let selectedPracticeSetId,
              let set = sets.first(where: { $0.id == selectedPracticeSetId })
        else { return "未選題組" }
        return set.questionCount > 0 ? "\(set.questionCount) 題" : "題組"
    }

    private func setButton(title: String, subtitle: String, setId: String?) -> some View {
        let isSelected = selectedPracticeSetId == setId
        return Button {
            onSelect(setId)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .lineLimit(2)
            }
            .foregroundStyle(isSelected ? .white : EPTheme.ink)
            .frame(width: 160, alignment: .leading)
            .frame(minHeight: 74, alignment: .leading)
            .padding(12)
            .background(isSelected ? EPTheme.primary : EPTheme.secondarySurface)
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
                    .foregroundStyle(isSelected ? EPTheme.primary : EPTheme.secondaryInk)
                Text(option)
                    .foregroundStyle(EPTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(12)
            .background(isSelected ? EPTheme.primary.opacity(0.12) : EPTheme.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        }
        .buttonStyle(.plain)
    }
}

private struct PracticeSessionStartCard: View {
    let availableCount: Int
    let sessionLimit: Int
    let selectedSetTitle: String
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("先完成一小組", systemImage: "flag.checkered")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text(selectedSetTitle)
                .font(.title3.bold())
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(availableCount > 0
                ? "這一輪會從目前條件中安排 \(sessionLimit) 題。做完就會看到結算，再決定要不要繼續。"
                : "目前條件下沒有可練習的題目，換一個題型或難度試試。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onStart) {
                Label("開始這組練習", systemImage: "play.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(availableCount == 0)
            .opacity(availableCount == 0 ? 0.45 : 1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct FreePracticeSessionSummaryCard: View {
    let answeredCount: Int
    let correctCount: Int
    let totalCount: Int
    let onPracticeAgain: () -> Void
    let onReturnToMission: () -> Void

    private var accuracyText: String {
        guard answeredCount > 0 else { return "0%" }
        return "\(Int((Double(correctCount) / Double(answeredCount) * 100).rounded()))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("這組練習完成了", systemImage: "checkmark.seal.fill")
                .font(.title3.bold())
                .foregroundStyle(EPTheme.support)

            Text("你已經完成一個可結束的小回合。可以再練一組，也可以回今日任務看下一步。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                summaryMetric(title: "完成", value: "\(answeredCount)/\(max(totalCount, answeredCount))")
                summaryMetric(title: "答對", value: "\(correctCount)")
                summaryMetric(title: "正確率", value: accuracyText)
            }

            HStack(spacing: 10) {
                Button(action: onPracticeAgain) {
                    Label("再練一組", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button(action: onReturnToMission) {
                    Label("回今日任務", systemImage: "target")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.support.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(EPTheme.secondaryInk)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(EPTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct PracticeInlineSupportPanel: View {
    let aiResponse: AiProxyResponse?
    let supportConfirmation: String?
    let isLoadingAI: Bool
    let onOpenSupport: () -> Void
    let onAskAI: () -> Void
    let onSendTeacher: () -> Void
    let onSendVolunteer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("卡住時可以直接求助", systemImage: "lifepreserver")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text("AI 會立刻解題；老師或志工會收到這一題、你的答案與解析。送出後到「支持」查看回覆。")
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(action: onAskAI) {
                    Label("問 AI 解題", systemImage: "sparkles")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(isLoadingAI)

                Button(action: onSendTeacher) {
                    Label("送給老師", systemImage: "person.text.rectangle")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button(action: onSendVolunteer) {
                    Label("送給志工", systemImage: "hands.sparkles")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            if isLoadingAI {
                Label("AI 正在看這一題...", systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(EPTheme.primary)
            }

            if let aiResponse {
                PracticeAIStatusCard(response: aiResponse, title: "AI 解題提示")
            }

            if let supportConfirmation {
                VStack(alignment: .leading, spacing: 8) {
                    Label("\(supportConfirmation) 已送出。", systemImage: "paperplane.fill")
                        .font(.footnote.bold())
                        .foregroundStyle(EPTheme.support)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: onOpenSupport) {
                        Label("前往支持查看回覆", systemImage: "heart.text.square")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private extension Array {
    func uniqued<ID: Hashable>(by keyPath: KeyPath<Element, ID>) -> [Element] {
        var seen = Set<ID>()
        return filter { element in
            seen.insert(element[keyPath: keyPath]).inserted
        }
    }
}

private extension Array where Element: Equatable {
    func uniqued() -> [Element] {
        var result: [Element] = []
        for element in self where !result.contains(element) {
            result.append(element)
        }
        return result
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
                .foregroundStyle(EPTheme.secondaryInk)
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
    let recommendedPracticePlan: AIPracticeRecommendationPlan?
    let onApplyRecommendation: (AIPracticeRecommendationPlan) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PracticeAIStatusCard(response: response, title: "AI 練習建議")

            if let action = response.output.recommendedNextAction, !action.isEmpty {
                Text(action)
                    .font(.footnote.bold())
                    .foregroundStyle(EPTheme.support)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let recommendedPracticePlan {
                PracticeAIRecommendationActionCard(plan: recommendedPracticePlan) {
                    onApplyRecommendation(recommendedPracticePlan)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct PracticeAIRecommendationActionCard: View {
    let plan: AIPracticeRecommendationPlan
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("推薦題組")
                .font(.caption.bold())
                .foregroundStyle(EPTheme.primary)
            Text(plan.title)
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(plan.questionCount) 題，約 \(plan.estimatedMinutes) 分鐘")
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
            Text(plan.matchNote)
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                Label("套用並開始這組練習", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(12)
        .background(EPTheme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct PracticeAIStatusCard: View {
    let response: AiProxyResponse
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(response.fallbackUsed ? "內建提示" : "AI 建議", systemImage: response.fallbackUsed ? "exclamationmark.triangle.fill" : "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(response.fallbackUsed ? EPTheme.warning : EPTheme.support)
            Text(response.fallbackUsed
                ? "先用內建提示陪你修這一題。"
                : "已整理成下一個可執行的小步驟。")
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
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
                    .foregroundStyle(EPTheme.secondaryInk)
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
                .foregroundStyle(EPTheme.secondaryInk)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}
