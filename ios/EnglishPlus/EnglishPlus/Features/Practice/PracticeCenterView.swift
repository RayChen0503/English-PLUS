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
    @State private var practiceSupportSentQuestionIds: Set<String> = []
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
    @State private var wrongAnswerRepairItems: [QuestionBankItem] = []
    @State private var practicePhase: PracticeCenterPhase = .selection
    @State private var suspendedPrimarySession: PracticeSessionMemorySnapshot?
    @State private var pendingSessionProposal: PracticeSessionProposal?
    @State private var showReplaceSessionConfirmation = false
    @State private var showDiscardSessionConfirmation = false
    @State private var sessionReturnMessage: String?
    @State private var didRestorePracticeDraft = false
    @State private var practiceRecommendationRequestId: UUID?
    @State private var practiceQuestionAIRequestId: UUID?
    @State private var wrongAnswerAIRequestId: UUID?
    @State private var supportRequestId: UUID?

    private let freePracticeSessionLimit = 10
    private let practiceDraftStore = PracticeSessionDraftStore()

    init(onOpenSupport: @escaping () -> Void = {}) {
        self.onOpenSupport = onOpenSupport
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch practicePhase {
                        case .selection:
                            selectionContent
                        case .primary, .repair:
                            if let sessionReturnMessage {
                                PracticeFlowNoticeCard(message: sessionReturnMessage)
                            }
                            practiceSessionNavigationCard
                            finitePracticeCard
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
                .id(practicePhase)
            }
            .navigationTitle("練習中心")
        }
        .onAppear {
            restorePracticeDraftIfNeeded()
            launchPendingPracticeIfNeeded()
        }
        .onDisappear {
            persistPrimarySessionIfNeeded()
        }
        .confirmationDialog(
            "要改用新的題組嗎？",
            isPresented: $showReplaceSessionConfirmation,
            titleVisibility: .visible
        ) {
            Button("改用新題組", role: .destructive) {
                startPendingSessionProposal()
            }
            Button("繼續原題組") {
                resumePrimarySession()
            }
            Button("取消", role: .cancel) {
                pendingSessionProposal = nil
            }
        } message: {
            Text("目前題組的進度還在。改用新題組會清除舊進度；選擇繼續則會回到原本那一題。")
        }
        .confirmationDialog(
            "要捨棄這組進度嗎？",
            isPresented: $showDiscardSessionConfirmation,
            titleVisibility: .visible
        ) {
            Button("捨棄進度", role: .destructive) {
                discardPrimarySession()
            }
            Button("保留", role: .cancel) {}
        } message: {
            Text("捨棄後無法回復，但不會影響今日任務或已完成的學習紀錄。")
        }
    }

    @ViewBuilder
    private var selectionContent: some View {
        headerCard

        if let sessionReturnMessage {
            PracticeFlowNoticeCard(message: sessionReturnMessage)
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
        }

        if hasUnfinishedPrimarySession {
            UnfinishedPracticeSessionCard(
                title: activePracticeSourceTitle ?? "尚未完成的自由練習",
                progressText: primarySessionProgressText,
                onResume: resumePrimarySession,
                onDiscard: {
                    showDiscardSessionConfirmation = true
                }
            )
        }

        filterCard
        practiceSetSelectionCard
        PracticeSessionStartCard(
            availableCount: filteredPracticeItems.count,
            sessionLimit: min(freePracticeSessionLimit, filteredPracticeItems.count),
            selectedSetTitle: selectedPracticeSet?.title ?? "全部題庫",
            onStart: startFreePracticeSession
        )
        aiRecommendationCard
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
            resetSelectionState()
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

    private var practiceSessionNavigationCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                leaveCurrentPracticeLayer()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.bold())
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .accessibilityLabel(practicePhase == .repair ? "離開加練" : "離開練習")

            VStack(alignment: .leading, spacing: 3) {
                Text(practicePhase == .repair ? "同類題加練" : "自由練習")
                    .font(.caption.bold())
                    .foregroundStyle(practicePhase == .repair ? EPTheme.warning : EPTheme.primary)
                Text(activePracticeSourceTitle ?? "這一組練習")
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                    .lineLimit(2)
            }

            Spacer()

            Text(positionText)
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(EPTheme.secondaryInk)
        }
        .padding(12)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var finitePracticeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(practicePhase == .repair ? "加練題組" : "這一組練習")
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

            if let item = currentPracticeItem {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: freePracticeProgressFraction)
                        .tint(EPTheme.primary)
                    Text(practicePhase == .repair
                        ? "這組加練不計入學習地圖；完成或離開後會回到原本題組。"
                        : "答完 \(freePracticeSessionItems.count) 題就會結算，自由練習不會影響今日任務進度。")
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
                        .disabled(practiceResult != nil)
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
                            .disabled(practiceResult != nil)
                        }
                    }
                }

                if let practiceResult {
                    PracticeResultCard(
                        result: practiceResult,
                        aiResponse: wrongAnswerAIResponse,
                        isLoadingAI: isLoadingWrongAnswerAI,
                        repairQuestionCount: practicePhase == .primary ? wrongAnswerRepairItems.count : 0,
                        onStartRepair: startWrongAnswerRepair
                    )

                    PracticeInlineSupportPanel(
                        aiResponse: practiceQuestionAIResponse,
                        supportConfirmation: practiceSupportConfirmation,
                        supportRequestSent: practiceSupportSentQuestionIds.contains(practiceSupportSentKey(for: item)),
                        canRequestHumanSupport: appState.currentProfile?.activeClassId != nil,
                        isLoadingAI: isLoadingPracticeQuestionAI,
                        onOpenSupport: onOpenSupport,
                        onAskAI: {
                            Task {
                                await askPracticeAI(for: item)
                            }
                        },
                        onSendSupport: {
                            Task {
                                await sendPracticeSupportRequest(for: item)
                            }
                        }
                    )
                }

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
                    Text("AI 會依最近表現整理成一組可以直接開始的題目。")
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

    private var hasUnfinishedPrimarySession: Bool {
        if practicePhase == .repair {
            return suspendedPrimarySession?.items.isEmpty == false
        }
        return !freePracticeSessionItems.isEmpty && !isFreePracticeSessionComplete
    }

    private var primarySessionProgressText: String {
        let snapshot = practicePhase == .repair ? suspendedPrimarySession : captureCurrentSession()
        guard let snapshot, !snapshot.items.isEmpty else { return "尚未開始" }
        let current = min(snapshot.index + 1, snapshot.items.count)
        return "第 \(current) / \(snapshot.items.count) 題 · 已作答 \(snapshot.answeredCount) 題"
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
        resetSelectionState()
    }

    private func selectPracticeLevel(_ level: QuestionLevel?) {
        selectedPracticeLevel = level
        resetSelectionState()
    }

    private func resetSelectionState() {
        practiceRecommendationRequestId = nil
        isLoadingPracticeAI = false
        practiceAIResponse = nil
        recommendedPracticePlan = nil
        sessionReturnMessage = nil
    }

    private func startFreePracticeSession() {
        let sessionSelection = buildPracticeSessionItems(from: filteredPracticeItems)
        requestPrimarySessionStart(
            PracticeSessionProposal(
                items: sessionSelection.items,
                sourceTitle: selectedPracticeSet?.title ?? "自由練習",
                note: sessionSelection.note
            )
        )
    }

    private func configureActiveSession(
        with items: [QuestionBankItem],
        sourceTitle: String?,
        note: String?,
        phase: PracticeCenterPhase
    ) {
        let sessionItems = QuestionGroupingEngine.balancedItems(from: items, limit: freePracticeSessionLimit)
        freePracticeSessionItems = sessionItems
        activePracticeSourceTitle = sourceTitle
        practiceSelectionNote = note
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
        wrongAnswerRepairItems = []
        practiceQuestionAIResponse = nil
        practiceSupportConfirmation = nil
        practiceSupportSentQuestionIds = []
        practiceQuestionAIRequestId = nil
        wrongAnswerAIRequestId = nil
        supportRequestId = nil
        isLoadingPracticeQuestionAI = false
        isLoadingWrongAnswerAI = false
        freePracticeAnsweredCount = 0
        freePracticeCorrectCount = 0
        didCountCurrentPracticeAnswer = false
        isFreePracticeSessionComplete = sessionItems.isEmpty
        practicePhase = sessionItems.isEmpty ? .selection : phase

        if phase == .primary, !sessionItems.isEmpty {
            persistPrimarySessionIfNeeded()
        }
    }

    private func finishFreePracticeSession() {
        guard practicePhase == .primary else {
            finishRepairSession()
            return
        }
        learningRepository.completeFreePracticeSession(
            correctCount: freePracticeCorrectCount,
            totalCount: freePracticeSessionItems.count
        )
        practiceAnswer = ""
        practiceResult = nil
        wrongAnswerAIResponse = nil
        wrongAnswerRepairItems = []
        practiceQuestionAIResponse = nil
        practiceSupportConfirmation = nil
        didCountCurrentPracticeAnswer = false
        isFreePracticeSessionComplete = true
        practicePhase = .selection
        suspendedPrimarySession = nil
        sessionReturnMessage = "這組練習已完成。你可以重新選題，也可以再開始一組。"
        clearPersistedPrimarySession()
    }

    private func requestPrimarySessionStart(_ proposal: PracticeSessionProposal) {
        guard !proposal.items.isEmpty else {
            practiceSelectionNote = proposal.note ?? "目前條件下沒有可用題目。"
            return
        }
        if hasUnfinishedPrimarySession {
            pendingSessionProposal = proposal
            showReplaceSessionConfirmation = true
            return
        }
        beginPrimarySession(proposal)
    }

    private func startPendingSessionProposal() {
        guard let proposal = pendingSessionProposal else { return }
        pendingSessionProposal = nil
        clearPersistedPrimarySession()
        beginPrimarySession(proposal)
    }

    private func beginPrimarySession(_ proposal: PracticeSessionProposal) {
        pendingSessionProposal = nil
        suspendedPrimarySession = nil
        sessionReturnMessage = nil
        isFreePracticeSessionComplete = false
        configureActiveSession(
            with: proposal.items,
            sourceTitle: proposal.sourceTitle,
            note: proposal.note,
            phase: .primary
        )
    }

    private func resumePrimarySession() {
        guard !freePracticeSessionItems.isEmpty, !isFreePracticeSessionComplete else { return }
        pendingSessionProposal = nil
        sessionReturnMessage = nil
        practicePhase = .primary
        persistPrimarySessionIfNeeded()
    }

    private func discardPrimarySession() {
        pendingSessionProposal = nil
        suspendedPrimarySession = nil
        clearActiveSessionState()
        practicePhase = .selection
        sessionReturnMessage = "未完成的題組已捨棄，你可以重新選一組。"
        clearPersistedPrimarySession()
    }

    private func leaveCurrentPracticeLayer() {
        if practicePhase == .repair {
            restoreSuspendedPrimarySession(message: "已離開加練，原本題組與作答進度都保留。")
            return
        }
        persistPrimarySessionIfNeeded()
        practicePhase = .selection
        sessionReturnMessage = "原本題組已保留，想繼續時按「回到原題組」。"
    }

    private func finishRepairSession() {
        restoreSuspendedPrimarySession(message: "三題加練完成，已回到原本題組。")
    }

    private func restoreSuspendedPrimarySession(message: String) {
        guard let snapshot = suspendedPrimarySession else {
            practicePhase = .selection
            sessionReturnMessage = "原本題組已結束，請重新選一組。"
            return
        }
        restoreSession(from: snapshot)
        suspendedPrimarySession = nil
        practicePhase = .primary
        sessionReturnMessage = message
        persistPrimarySessionIfNeeded()
    }

    private func captureCurrentSession() -> PracticeSessionMemorySnapshot? {
        guard !freePracticeSessionItems.isEmpty else { return nil }
        return PracticeSessionMemorySnapshot(
            items: freePracticeSessionItems,
            index: practiceIndex,
            answer: practiceAnswer,
            result: practiceResult,
            questionAIResponse: practiceQuestionAIResponse,
            wrongAnswerAIResponse: wrongAnswerAIResponse,
            wrongAnswerRepairItems: wrongAnswerRepairItems,
            supportConfirmation: practiceSupportConfirmation,
            supportSentQuestionIds: practiceSupportSentQuestionIds,
            sourceTitle: activePracticeSourceTitle,
            selectionNote: practiceSelectionNote,
            optionOrderByQuestionId: practiceOptionOrderByQuestionId,
            answeredCount: freePracticeAnsweredCount,
            correctCount: freePracticeCorrectCount,
            didCountCurrentAnswer: didCountCurrentPracticeAnswer,
            isComplete: isFreePracticeSessionComplete
        )
    }

    private func restoreSession(from snapshot: PracticeSessionMemorySnapshot) {
        freePracticeSessionItems = snapshot.items
        practiceIndex = min(max(snapshot.index, 0), max(snapshot.items.count - 1, 0))
        practiceAnswer = snapshot.answer
        practiceResult = snapshot.result
        practiceQuestionAIResponse = snapshot.questionAIResponse
        wrongAnswerAIResponse = snapshot.wrongAnswerAIResponse
        wrongAnswerRepairItems = snapshot.wrongAnswerRepairItems
        practiceSupportConfirmation = snapshot.supportConfirmation
        practiceSupportSentQuestionIds = snapshot.supportSentQuestionIds
        activePracticeSourceTitle = snapshot.sourceTitle
        practiceSelectionNote = snapshot.selectionNote
        practiceOptionOrderByQuestionId = snapshot.optionOrderByQuestionId
        freePracticeAnsweredCount = snapshot.answeredCount
        freePracticeCorrectCount = snapshot.correctCount
        didCountCurrentPracticeAnswer = snapshot.didCountCurrentAnswer
        isFreePracticeSessionComplete = snapshot.isComplete
    }

    private func clearActiveSessionState() {
        practiceIndex = 0
        practiceAnswer = ""
        practiceResult = nil
        practiceQuestionAIResponse = nil
        wrongAnswerAIResponse = nil
        wrongAnswerRepairItems = []
        practiceSupportConfirmation = nil
        practiceSupportSentQuestionIds = []
        practiceQuestionAIRequestId = nil
        wrongAnswerAIRequestId = nil
        supportRequestId = nil
        isLoadingPracticeQuestionAI = false
        isLoadingWrongAnswerAI = false
        activePracticeSourceTitle = nil
        practiceSelectionNote = nil
        practiceOptionOrderByQuestionId = [:]
        freePracticeSessionItems = []
        freePracticeAnsweredCount = 0
        freePracticeCorrectCount = 0
        didCountCurrentPracticeAnswer = false
        isFreePracticeSessionComplete = false
    }

    private var practiceDraftOwnerId: String? {
        appState.currentProfile?.id ?? appState.currentUser?.id
    }

    private func persistPrimarySessionIfNeeded(snapshot providedSnapshot: PracticeSessionMemorySnapshot? = nil) {
        guard let ownerId = practiceDraftOwnerId else { return }
        let snapshot = providedSnapshot
            ?? (practicePhase == .repair ? suspendedPrimarySession : captureCurrentSession())
        guard let snapshot, !snapshot.items.isEmpty, !snapshot.isComplete else {
            practiceDraftStore.clear(ownerId: ownerId)
            return
        }

        practiceDraftStore.save(
            PracticeSessionDraft(
                questionIds: snapshot.items.map(\.id),
                index: snapshot.index,
                answer: snapshot.answer,
                result: snapshot.result,
                sourceTitle: snapshot.sourceTitle,
                selectionNote: snapshot.selectionNote,
                optionOrderByQuestionId: snapshot.optionOrderByQuestionId,
                answeredCount: snapshot.answeredCount,
                correctCount: snapshot.correctCount,
                didCountCurrentAnswer: snapshot.didCountCurrentAnswer
            ),
            ownerId: ownerId
        )
    }

    private func restorePracticeDraftIfNeeded() {
        guard !didRestorePracticeDraft else { return }
        didRestorePracticeDraft = true
        guard let ownerId = practiceDraftOwnerId,
              let draft = practiceDraftStore.load(ownerId: ownerId)
        else { return }

        let itemsById = Dictionary(
            questionBankItems.map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        let restoredItems = draft.questionIds.compactMap { itemsById[$0] }
        guard !restoredItems.isEmpty else {
            practiceDraftStore.clear(ownerId: ownerId)
            return
        }

        let optionOrders = Dictionary(
            restoredItems.enumerated().map { index, item in
                let saved = draft.optionOrderByQuestionId[item.id]
                let resolvedOrder = (saved?.isEmpty == false ? saved : nil)
                    ?? QuestionGroupingEngine.balancedOptions(for: item, sessionIndex: index)
                return (
                    item.id,
                    resolvedOrder
                )
            },
            uniquingKeysWith: { _, latest in latest }
        )
        let restoredIndex = min(max(draft.index, 0), restoredItems.count - 1)
        let restoredItem = restoredItems[restoredIndex]
        let repairItems = draft.result?.isCorrect == false
            ? QuestionGroupingEngine.repairSelection(
                after: restoredItem,
                from: questionBankItems,
                excluding: Set(restoredItems.map(\.id)),
                limit: 3
            ).items
            : []

        restoreSession(
            from: PracticeSessionMemorySnapshot(
                items: restoredItems,
                index: restoredIndex,
                answer: draft.answer,
                result: draft.result,
                questionAIResponse: nil,
                wrongAnswerAIResponse: nil,
                wrongAnswerRepairItems: repairItems,
                supportConfirmation: nil,
                supportSentQuestionIds: [],
                sourceTitle: draft.sourceTitle,
                selectionNote: draft.selectionNote,
                optionOrderByQuestionId: optionOrders,
                answeredCount: min(draft.answeredCount, restoredItems.count),
                correctCount: min(draft.correctCount, restoredItems.count),
                didCountCurrentAnswer: draft.didCountCurrentAnswer,
                isComplete: false
            )
        )
        practicePhase = .selection
        sessionReturnMessage = "找到一組尚未完成的練習，可以從原本進度繼續。"
    }

    private func clearPersistedPrimarySession() {
        guard let ownerId = practiceDraftOwnerId else { return }
        practiceDraftStore.clear(ownerId: ownerId)
    }

    private func buildAIRecommendationPlan(from response: AiProxyResponse) -> AIPracticeRecommendationPlan? {
        let searchText = recommendationSearchText(from: response)
        let structuredPlan = response.output.practicePlan
        let structuredTypes = structuredPlan?.questionPlan.compactMap { questionType(fromAIValue: $0.type) } ?? []
        let structuredLevels = structuredPlan?.questionPlan.flatMap { questionLevels(fromAIDifficulty: $0.difficulty) } ?? []
        let inferredTypes = structuredTypes.isEmpty
            ? inferRecommendedQuestionTypes(from: searchText)
            : structuredTypes.uniqued()
        let inferredLevels = structuredLevels.isEmpty
            ? inferRecommendedQuestionLevels(from: searchText)
            : structuredLevels.uniqued()
        let skillHints = ((structuredPlan?.focusSkills ?? []) + inferRecommendedSkillHints(from: searchText)).uniqued()

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

        let targetCount = min(
            freePracticeSessionLimit,
            max(1, structuredPlan?.targetQuestionCount ?? freePracticeSessionLimit)
        )
        let selection = structuredPlan.map {
            structuredRecommendationSelection(
                plan: $0,
                fallbackScoredItems: scoredItems,
                targetCount: targetCount
            )
        } ?? QuestionGroupingEngine.practiceSelection(
            from: scoredItems,
            fallbackCandidates: fallbackAIRecommendationItems(
                inferredTypes: inferredTypes,
                inferredLevels: inferredLevels
            ),
            limit: targetCount
        )
        let selectedItems = selection.items
        guard let firstItem = selectedItems.first else { return nil }

        let resolvedSkill = resolvedRecommendationSkill(from: selectedItems, skillHints: skillHints)
        let titleSkill = resolvedSkill.isEmpty ? firstItem.skill : resolvedSkill
        let providedTitle = structuredPlan?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = providedTitle.isEmpty
            ? "AI 推薦：\(firstItem.question.type.title) / \(titleSkill)"
            : providedTitle
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

    private func structuredRecommendationSelection(
        plan: AiPracticePlanOutput,
        fallbackScoredItems: [QuestionBankItem],
        targetCount: Int
    ) -> QuestionPracticeSelection {
        var selected: [QuestionBankItem] = []
        var usedFallback = false
        let focusSkills = plan.focusSkills
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        for planItem in plan.questionPlan where selected.count < targetCount {
            guard let type = questionType(fromAIValue: planItem.type) else {
                usedFallback = true
                continue
            }
            let levels = questionLevels(fromAIDifficulty: planItem.difficulty)
            let selectedIds = Set(selected.map(\.id))
            let typeAndLevel = questionBankItems.filter { item in
                !selectedIds.contains(item.id)
                    && item.question.type == type
                    && (levels.isEmpty || levels.contains(item.level))
            }
            let skillMatches = typeAndLevel.filter { item in
                guard !focusSkills.isEmpty else { return true }
                let itemText = "\(item.skill) \(item.unit) \(item.question.concept)".lowercased()
                return focusSkills.contains { itemText.contains($0) }
            }
            let exactCandidates = skillMatches.isEmpty ? typeAndLevel : skillMatches
            let requestedCount = min(
                max(1, planItem.targetCorrect),
                targetCount - selected.count
            )
            let segment = QuestionGroupingEngine.practiceSelection(
                from: exactCandidates,
                fallbackCandidates: QuestionGroupingEngine.balancedFallbackCandidates(
                    preferredTypes: [type],
                    preferredLevels: levels,
                    from: questionBankItems.filter { !selectedIds.contains($0.id) }
                ),
                limit: requestedCount
            )
            usedFallback = usedFallback || segment.fallbackUsed
            selected.append(contentsOf: segment.items.filter { item in
                !selected.contains(where: { $0.id == item.id })
            })
        }

        if selected.count < targetCount {
            let selectedIds = Set(selected.map(\.id))
            let fill = QuestionGroupingEngine.practiceSelection(
                from: fallbackScoredItems.filter { !selectedIds.contains($0.id) },
                fallbackCandidates: questionBankItems.filter { !selectedIds.contains($0.id) },
                limit: targetCount - selected.count
            )
            selected.append(contentsOf: fill.items)
            usedFallback = true
        }

        return QuestionPracticeSelection(
            items: QuestionGroupingEngine.balancedItems(from: selected, limit: targetCount),
            fallbackUsed: usedFallback
        )
    }

    private func questionType(fromAIValue value: String) -> QuestionType? {
        switch value {
        case "vocabulary": return .vocabulary
        case "multipleChoice", "grammar", "choice": return .grammar
        case "fillBlank": return .fillBlank
        case "cloze": return .cloze
        case "reading": return .reading
        case "translation", "sentenceReorder": return .translation
        case "dialogue": return .dialogue
        default: return nil
        }
    }

    private func questionLevels(fromAIDifficulty value: String) -> [QuestionLevel] {
        switch value.lowercased() {
        case "foundation", "a1": return [.a1]
        case "core", "a2": return [.a2]
        case "exam", "challenge", "b1": return [.b1]
        case "advanced", "highschool", "b2": return [.b2]
        default: return []
        }
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
        requestPrimarySessionStart(
            PracticeSessionProposal(
                items: plan.items,
                sourceTitle: plan.title,
                note: plan.matchNote
            )
        )
    }

    private func submitPracticeAnswer(for item: QuestionBankItem) {
        guard practiceResult == nil,
              currentPracticeItem?.id == item.id
        else { return }
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

        if practicePhase == .primary {
            persistPrimarySessionIfNeeded()
        }

        guard !isCorrect else { return }
        wrongAnswerRepairItems = QuestionGroupingEngine.repairSelection(
            after: item,
            from: questionBankItems,
            excluding: Set(freePracticeSessionItems.map(\.id)),
            limit: 3
        ).items
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
        guard practicePhase == .primary,
              currentPracticeItem?.id == item.id,
              practiceResult?.isCorrect == false
        else { return }
        let requestId = UUID()
        wrongAnswerAIRequestId = requestId
        isLoadingWrongAnswerAI = true
        defer {
            if wrongAnswerAIRequestId == requestId {
                isLoadingWrongAnswerAI = false
            }
        }

        let context = WrongAnswerAIContext(
            classId: currentClassId,
            studentUid: appState.currentUser?.id,
            attempt: attempt,
            questionItem: item
        )
        let response = await appState.explainWrongAnswerWithAI(context: context)
        guard wrongAnswerAIRequestId == requestId else { return }
        guard practicePhase == .primary,
              currentPracticeItem?.id == item.id,
              practiceResult?.isCorrect == false
        else { return }
        wrongAnswerAIResponse = response
    }

    private func startWrongAnswerRepair() {
        guard practicePhase == .primary,
              let source = currentPracticeItem,
              !wrongAnswerRepairItems.isEmpty,
              let primarySnapshot = captureCurrentSession()
        else { return }

        suspendedPrimarySession = primarySnapshot
        persistPrimarySessionIfNeeded(snapshot: primarySnapshot)
        configureActiveSession(
            with: wrongAnswerRepairItems,
            sourceTitle: "錯題回練：\(source.skill.isEmpty ? source.question.concept : source.skill)",
            note: "這是暫時加練。完成或離開後會回到原本題組，不會改變學習地圖進度。",
            phase: .repair
        )
        sessionReturnMessage = nil
    }

    private func launchPendingPracticeIfNeeded() {
        guard let launch = learningRepository.takePendingPracticeLaunch() else { return }
        let itemsById = Dictionary(
            questionBankItems.map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        let items = launch.questionIds.compactMap { itemsById[$0] }
        guard !items.isEmpty else {
            practiceSelectionNote = "原本的錯題練習暫時找不到題目，請重新選一組練習。"
            return
        }
        selectedPracticeSetId = nil
        selectedPracticeType = items.first?.question.type
        selectedPracticeLevel = items.first?.level
        beginPrimarySession(
            PracticeSessionProposal(
                items: items,
                sourceTitle: launch.title,
                note: "已接續 AI 錯題詳解，先完成這組相似題。"
            )
        )
    }

    @MainActor
    private func askPracticeAI(for item: QuestionBankItem) async {
        guard practiceResult != nil,
              currentPracticeItem?.id == item.id
        else { return }
        let requestPhase = practicePhase
        let requestId = UUID()
        practiceQuestionAIRequestId = requestId
        isLoadingPracticeQuestionAI = true
        defer {
            if practiceQuestionAIRequestId == requestId {
                isLoadingPracticeQuestionAI = false
            }
        }

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
        let response = await appState.explainWrongAnswerWithAI(context: context)
        guard practiceQuestionAIRequestId == requestId else { return }
        guard practicePhase == requestPhase,
              currentPracticeItem?.id == item.id,
              practiceResult != nil
        else { return }
        practiceQuestionAIResponse = response
    }

    @MainActor
    private func sendPracticeSupportRequest(for item: QuestionBankItem) async {
        guard practiceResult != nil,
              appState.currentProfile?.activeClassId != nil,
              currentPracticeItem?.id == item.id
        else { return }
        let requestPhase = practicePhase
        let requestId = UUID()
        supportRequestId = requestId
        let selectedAnswer = normalizedPracticeAnswer(practiceAnswer).isEmpty ? nil : practiceAnswer
        let option = practiceSupportOption()
        let didSend = await learningRepository.sendQuestionSupportRequest(
            from: appState.currentUser,
            profile: appState.currentProfile,
            option: option,
            questionItem: item,
            selectedAnswer: selectedAnswer,
            message: practiceSupportMessage(for: item)
        )
        guard supportRequestId == requestId,
              didSend,
              practicePhase == requestPhase,
              currentPracticeItem?.id == item.id,
              practiceResult != nil
        else { return }
        practiceSupportSentQuestionIds.insert(practiceSupportSentKey(for: item))
        practiceSupportConfirmation = "已送給老師與志工，兩邊都會看到這一題與你的答案。"
    }

    private func practiceSupportOption() -> SupportOption {
        SeedData.supportOptions.first { $0.id == "human-company" }
            ?? SupportOption(
                id: "practice-shared-help",
                reason: "請老師與志工協助",
                studentText: "我想請老師或志工看這題。",
                platformAction: "請老師與志工查看學生題目與答案。",
                route: .humanHandoff
            )
    }

    private func practiceSupportMessage(for item: QuestionBankItem) -> String {
        let answerText = normalizedPracticeAnswer(practiceAnswer).isEmpty ? "尚未作答" : practiceAnswer
        return """
        我在自由練習這題卡住，想請老師或志工看一下。
        題型：\(item.question.type.title)
        難度：\(item.level.uiTitle)
        題目：\(item.question.prompt)
        我的答案：\(answerText)
        正確答案：\(item.question.answer)
        解析：\(item.question.explanation)
        """
    }

    private func practiceSupportSentKey(for item: QuestionBankItem) -> String {
        "\(item.id)-shared"
    }

    private func nextPracticeQuestion() {
        guard !freePracticeSessionItems.isEmpty,
              practiceResult != nil
        else { return }
        if isLastFreePracticeQuestion {
            if practicePhase == .repair {
                finishRepairSession()
            } else {
                finishFreePracticeSession()
            }
            return
        }
        practiceIndex = min(practiceIndex + 1, freePracticeSessionItems.count - 1)
        practiceAnswer = ""
        practiceResult = nil
        wrongAnswerAIResponse = nil
        practiceQuestionAIResponse = nil
        practiceSupportConfirmation = nil
        practiceQuestionAIRequestId = nil
        wrongAnswerAIRequestId = nil
        supportRequestId = nil
        isLoadingPracticeQuestionAI = false
        isLoadingWrongAnswerAI = false
        didCountCurrentPracticeAnswer = false
        sessionReturnMessage = nil
        if practicePhase == .primary {
            persistPrimarySessionIfNeeded()
        }
    }

    private func normalizedPracticeAnswer(_ answer: String) -> String {
        answer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    @MainActor
    private func requestPracticeRecommendation() async {
        guard practicePhase == .selection else { return }
        let requestId = UUID()
        practiceRecommendationRequestId = requestId
        isLoadingPracticeAI = true
        defer {
            if practiceRecommendationRequestId == requestId {
                isLoadingPracticeAI = false
            }
        }
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
        guard practiceRecommendationRequestId == requestId,
              practicePhase == .selection
        else { return }
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

enum PracticeCenterPhase: String, Equatable {
    case selection
    case primary
    case repair
}

struct PracticeResult: Codable, Equatable {
    let isCorrect: Bool
    let acceptedAnswer: String
    let explanation: String
    let repairHint: String
}

struct PracticeSessionDraft: Codable, Equatable {
    let questionIds: [String]
    let index: Int
    let answer: String
    let result: PracticeResult?
    let sourceTitle: String?
    let selectionNote: String?
    let optionOrderByQuestionId: [String: [String]]
    let answeredCount: Int
    let correctCount: Int
    let didCountCurrentAnswer: Bool
}

struct PracticeSessionDraftStore {
    private let defaults: UserDefaults
    private let keyPrefix = "englishplus.practice.primary.v1."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ draft: PracticeSessionDraft, ownerId: String) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        defaults.set(data, forKey: storageKey(ownerId: ownerId))
    }

    func load(ownerId: String) -> PracticeSessionDraft? {
        guard let data = defaults.data(forKey: storageKey(ownerId: ownerId)) else { return nil }
        guard let draft = try? JSONDecoder().decode(PracticeSessionDraft.self, from: data) else {
            clear(ownerId: ownerId)
            return nil
        }
        return draft
    }

    func clear(ownerId: String) {
        defaults.removeObject(forKey: storageKey(ownerId: ownerId))
    }

    private func storageKey(ownerId: String) -> String {
        keyPrefix + ownerId
    }
}

private struct PracticeSessionProposal {
    let items: [QuestionBankItem]
    let sourceTitle: String?
    let note: String?
}

private struct PracticeSessionMemorySnapshot {
    let items: [QuestionBankItem]
    let index: Int
    let answer: String
    let result: PracticeResult?
    let questionAIResponse: AiProxyResponse?
    let wrongAnswerAIResponse: AiProxyResponse?
    let wrongAnswerRepairItems: [QuestionBankItem]
    let supportConfirmation: String?
    let supportSentQuestionIds: Set<String>
    let sourceTitle: String?
    let selectionNote: String?
    let optionOrderByQuestionId: [String: [String]]
    let answeredCount: Int
    let correctCount: Int
    let didCountCurrentAnswer: Bool
    let isComplete: Bool
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

private struct PracticeFlowNoticeCard: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.subheadline.bold())
            .foregroundStyle(EPTheme.support)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EPTheme.support.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct UnfinishedPracticeSessionCard: View {
    let title: String
    let progressText: String
    let onResume: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("上次練到一半", systemImage: "bookmark.fill")
                .font(.headline)
                .foregroundStyle(EPTheme.primary)

            Text(title)
                .font(.title3.bold())
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(progressText)
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)

            HStack(spacing: 10) {
                Button(action: onResume) {
                    Label("回到原題組", systemImage: "play.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button(action: onDiscard) {
                    Image(systemName: "trash")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityLabel("捨棄未完成題組")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.primary.opacity(0.08))
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
    let supportRequestSent: Bool
    let canRequestHumanSupport: Bool
    let isLoadingAI: Bool
    let onOpenSupport: () -> Void
    let onAskAI: () -> Void
    let onSendSupport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("卡住時可以直接求助", systemImage: "lifepreserver")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text(canRequestHumanSupport
                ? "AI 會立刻解題；也可以把題目送給班級老師與志工，回覆會集中在「支持」。"
                : "AI 會立刻解題。加入班級後，這裡也會開啟老師與志工協助。")
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

                if canRequestHumanSupport {
                    Button(action: onSendSupport) {
                        Label(supportRequestSent ? "已送出" : "送給老師與志工", systemImage: "paperplane.fill")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(supportRequestSent)
                }
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
    let repairQuestionCount: Int
    let onStartRepair: () -> Void

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

            if !result.isCorrect, !isLoadingAI, repairQuestionCount > 0 {
                Button(action: onStartRepair) {
                    Label("練 \(repairQuestionCount) 題同類題", systemImage: "target")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Text("會直接開啟相同題型、難度與能力點的短練習，不必重新篩選題庫。")
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
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
                VStack(alignment: .leading, spacing: 3) {
                    Text("建議下一步")
                        .font(.caption.bold())
                        .foregroundStyle(EPTheme.secondaryInk)
                    Text(action)
                        .font(.footnote)
                        .foregroundStyle(EPTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
            Text(response.userFacingAvailabilityMessage)
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
