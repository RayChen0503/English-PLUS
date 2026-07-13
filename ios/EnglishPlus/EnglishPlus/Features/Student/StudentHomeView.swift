import SwiftUI

struct StudentHomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    let onOpenSupport: () -> Void
    let onOpenPractice: () -> Void

    @State private var moodScore = 3
    @State private var timeLevel = 3
    @State private var wantsChallenge = false
    @State private var selectedTypes = Set<QuestionType>()
    @State private var selectedAnswer = ""
    @State private var isGeneratingMissionWithAI = false
    @State private var isExplainingWrongAnswer = false
    @State private var latestWrongAnswerAIResponse: AiProxyResponse?
    @State private var missionAIRequestId: UUID?
    @State private var missionSupportConfirmation: String?
    @State private var missionSupportSentQuestionIds = Set<String>()
    @State private var showsHumanSupportConfirmation = false
    @State private var showsAccountData = false

    init(
        onOpenSupport: @escaping () -> Void = {},
        onOpenPractice: @escaping () -> Void = {}
    ) {
        self.onOpenSupport = onOpenSupport
        self.onOpenPractice = onOpenPractice
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        LearningFlowStatusCard(
                            flow: learningRepository.learningFlow,
                            progress: learningRepository.progressSnapshot
                        )

                        studentFlowContent

                        freePracticeCard
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("首頁")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showsAccountData = true
                        } label: {
                            Label("帳號與資料", systemImage: "person.text.rectangle")
                        }

                        Button(role: .destructive) {
                            appState.signOut()
                        } label: {
                            Label("登出", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Label("帳號", systemImage: "person.crop.circle")
                    }
                }
            }
            .sheet(isPresented: $showsAccountData) {
                AccountDataView()
            }
            .onAppear(perform: initializePreferredTypes)
            .alert("送出真人求助？", isPresented: $showsHumanSupportConfirmation) {
                Button("取消", role: .cancel) {}
                Button("送給老師與志工") {
                    Task {
                        await sendHumanSupportRequest()
                    }
                }
            } message: {
                Text("只有按下送出後，班級中的老師與志工才會看到這則訊息。心情分數本身不會自動通知任何人。")
            }
        }
    }

    @ViewBuilder
    private var studentFlowContent: some View {
        switch learningRepository.learningFlow.stage {
        case .needsCheckIn:
            if learningRepository.canContinuePreviousProgress {
                continuationCard
            }
            checkInCard
        case .missionActive:
            missionCard
            if shouldOfferHumanSupport {
                humanSupportCard
            }
        case .missionCompleted:
            missionCompletionActions
            if shouldOfferHumanSupport {
                humanSupportCard
            }
        case .freePractice:
            freePracticeModeCard
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
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var continuationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("可以延續上次進度")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            if let continuation = learningRepository.learningFlow.continuation {
                Text("上一輪：\(continuation.progressText)")
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.secondaryInk)
            }

            Button {
                learningRepository.continueLearningFlow()
            } label: {
                Label("延續上次任務", systemImage: "arrow.clockwise.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(16)
        .background(EPTheme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var checkInCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("開始心情檢測")
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Text("這裡只問四題。系統會依照你的狀態、時間與想練的題型，產生今日任務。")
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.secondaryInk)
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
        .background(EPTheme.card)
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
                                .foregroundStyle(EPTheme.secondaryInk)
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
                        .foregroundStyle(EPTheme.secondaryInk)
                }

                if let response = appState.latestAIResponse, response.taskType == .dailyMission {
                    AIStatusCard(response: response, title: "AI 任務安排")
                }

                Text("答對才會增加進度。答錯時會保留這題，先看提示再重試。")
                    .font(.footnote)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                if progress.status == .completed {
                    CompletionCard()
                } else {
                    let activeMissionQuestion = learningRepository.nextMissionQuestion
                    if let item = activeMissionQuestion {
                        missionQuestionView(item)
                    }
                }

                if let attempt = learningRepository.latestMissionAttempt {
                    missionFeedbackCard(for: attempt)
                }
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var missionCompletionActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            CompletionCard()

            Text("今天的每日任務已完成。下一步可以到練習中心自由挑戰；如果想重新安排任務，請到學習地圖按重新檢測。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                openFreePractice()
            } label: {
                Label("前往自由練習", systemImage: "pencil.and.list.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var freePracticeModeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("自由練習模式")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            Text("這裡不計入每日任務進度。想回到今天任務時，可以切回任務流程；想重新安排，請到學習地圖按重新檢測。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    learningRepository.returnToMissionFlow()
                } label: {
                    Label("回到今日任務", systemImage: "target")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button {
                    openFreePractice()
                } label: {
                    Label("自由練習", systemImage: "pencil.and.list.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var freePracticeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("自由練習")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            Text("完成今日任務後，可以到練習中心自由挑題。自由練習不會影響今日任務進度。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
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
                    .foregroundStyle(EPTheme.secondaryInk)
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
                    ForEach(Array(missionOptionOrder(for: item).enumerated()), id: \.offset) { _, option in
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
                submitMissionAnswer(for: item)
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

    private func missionQuestionIndex(for item: QuestionBankItem) -> Int {
        learningRepository.currentMission?.questions.firstIndex { $0.id == item.id } ?? 0
    }

    private func missionOptionOrder(for item: QuestionBankItem) -> [String] {
        QuestionGroupingEngine.balancedOptions(
            for: item,
            sessionIndex: missionQuestionIndex(for: item)
        )
    }

    private func initializePreferredTypes() {
        guard selectedTypes.isEmpty else { return }
        selectedTypes = Set(learningRepository.defaultPreferredQuestionTypes)
    }

    @MainActor
    private func generateMissionAfterAI() async {
        guard !preferredTypesInDisplayOrder.isEmpty else { return }
        isGeneratingMissionWithAI = true
        defer { isGeneratingMissionWithAI = false }

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
        missionAIRequestId = nil
        isExplainingWrongAnswer = false
    }

    private func submitMissionAnswer(for item: QuestionBankItem) {
        guard learningRepository.nextMissionQuestion?.id == item.id else {
            selectedAnswer = ""
            latestWrongAnswerAIResponse = nil
            missionAIRequestId = nil
            isExplainingWrongAnswer = false
            missionSupportConfirmation = nil
            return
        }
        guard let attempt = learningRepository.submitMissionAnswer(selectedAnswer) else { return }
        selectedAnswer = ""
        latestWrongAnswerAIResponse = nil
        missionAIRequestId = nil
        isExplainingWrongAnswer = false
        missionSupportConfirmation = nil

        guard !attempt.isCorrect else { return }
    }

    @MainActor
    private func askMissionAI(for item: QuestionBankItem, attempt: MissionAttempt) async {
        guard learningRepository.latestMissionAttempt?.id == attempt.id else { return }
        let requestId = UUID()
        missionAIRequestId = requestId
        isExplainingWrongAnswer = true
        defer {
            if missionAIRequestId == requestId {
                isExplainingWrongAnswer = false
            }
        }

        let aiContext = WrongAnswerAIContext(
            classId: currentClassId,
            studentUid: appState.currentUser?.id,
            attempt: attempt,
            questionItem: item
        )
        guard let response = await appState.explainWrongAnswerWithAI(context: aiContext) else { return }
        guard missionAIRequestId == requestId,
              learningRepository.latestMissionAttempt?.id == attempt.id
        else { return }
        latestWrongAnswerAIResponse = response
    }

    private func missionFeedbackCard(for attempt: MissionAttempt) -> some View {
        let item = learningRepository.currentMission?.questions.first { $0.id == attempt.questionId }
        return FeedbackCard(
            attempt: attempt,
            questionItem: item,
            aiResponse: latestWrongAnswerAIResponse,
            supportConfirmation: missionSupportConfirmation,
            supportRequestSent: item.map { missionSupportSentQuestionIds.contains(missionSupportSentKey(for: $0)) } ?? false,
            canRequestHumanSupport: appState.currentProfile?.activeClassId != nil,
            isLoadingAI: isExplainingWrongAnswer,
            onOpenPractice: {
                guard let item else { return }
                openPracticeFromAI(for: item)
            },
            onOpenSupport: onOpenSupport,
            onAskAI: {
                guard let item else { return }
                Task {
                    await askMissionAI(for: item, attempt: attempt)
                }
            },
            onSendSupport: {
                guard let item else { return }
                Task {
                    await sendMissionSupportRequest(for: item, attempt: attempt)
                }
            }
        )
    }

    @MainActor
    private func sendMissionSupportRequest(
        for item: QuestionBankItem,
        attempt: MissionAttempt
    ) async {
        guard appState.currentProfile?.activeClassId != nil else { return }
        let didSend = await learningRepository.sendQuestionSupportRequest(
            from: appState.currentUser,
            profile: appState.currentProfile,
            option: missionSupportOption(),
            questionItem: item,
            selectedAnswer: attempt.selectedAnswer,
            message: missionSupportMessage(for: item, attempt: attempt)
        )
        guard didSend else { return }
        missionSupportSentQuestionIds.insert(missionSupportSentKey(for: item))
        missionSupportConfirmation = "已送給老師與志工，兩邊都會看到這一題與你的答案。"
    }

    private func missionSupportOption() -> SupportOption {
        SeedData.supportOptions.first { $0.id == "human-company" }
            ?? SupportOption(
                id: "mission-shared-help",
                reason: "請老師與志工協助今日任務",
                studentText: "我想請老師或志工看今天任務裡這一題。",
                platformAction: "請老師與志工查看學生今日任務題目、答案與 AI 提示。",
                route: .humanHandoff
            )
    }

    private func missionSupportMessage(
        for item: QuestionBankItem,
        attempt: MissionAttempt
    ) -> String {
        """
        我在今日任務這題卡住，想請老師或志工看一下。
        題型：\(item.question.type.title)
        難度：\(item.level.uiTitle)
        題目：\(item.question.prompt)
        我的答案：\(attempt.selectedAnswer)
        正確答案：\(item.question.answer)
        解析：\(item.question.explanation)
        AI/系統提示：\(attempt.repairHint)
        """
    }

    private func missionSupportSentKey(for item: QuestionBankItem) -> String {
        "\(item.id)-shared"
    }

    private func openPracticeFromAI(for item: QuestionBankItem) {
        let repairSelection = QuestionGroupingEngine.repairSelection(
            after: item,
            from: learningRepository.questionBankItems,
            limit: 3
        )
        learningRepository.scheduleFocusedPractice(
            title: "錯題回練：\(item.skill.isEmpty ? item.question.concept : item.skill)",
            questionIds: repairSelection.items.map(\.id)
        )
        openFreePractice()
    }

    private var humanSupportCard: some View {
        StudentHumanHelpCard(
            canSendToClass: appState.currentProfile?.activeClassId != nil,
            hasSentRequest: hasActiveHumanSupportRequest,
            onSend: {
                showsHumanSupportConfirmation = true
            },
            onOpenSupport: onOpenSupport
        )
    }

    private var shouldOfferHumanSupport: Bool {
        guard let moodScore = learningRepository.currentCheckIn?.moodScore else { return false }
        return moodScore <= 2
    }

    private var hasActiveHumanSupportRequest: Bool {
        learningRepository.supportRequests(forStudentUid: appState.currentUser?.id).contains { request in
            request.reason == .emotionalSupport
                && request.withdrawnAt == nil
                && request.studentArchivedAt == nil
                && request.status != .closed
        }
    }

    @MainActor
    private func sendHumanSupportRequest() async {
        guard appState.currentProfile?.activeClassId != nil,
              !hasActiveHumanSupportRequest else { return }
        _ = await learningRepository.sendSupportRequest(
            from: appState.currentUser,
            profile: appState.currentProfile,
            option: humanSupportOption(),
            message: "我今天狀態比較低，想主動請老師或志工陪我一下。"
        )
    }

    private func humanSupportOption() -> SupportOption {
        SeedData.supportOptions.first { $0.route == .recovery }
            ?? SupportOption(
                id: "student-human-support",
                reason: "我想找真人陪我",
                studentText: "我今天狀態比較低，想找人陪我一下。",
                platformAction: "等待班級中的老師或志工回覆。",
                route: .recovery
            )
    }

    private func openFreePractice() {
        learningRepository.enterFreePracticeMode()
        selectedAnswer = ""
        latestWrongAnswerAIResponse = nil
        missionAIRequestId = nil
        isExplainingWrongAnswer = false
        missionSupportConfirmation = nil
        onOpenPractice()
    }
}

private struct LearningFlowStatusCard: View {
    let flow: LearningFlowState
    let progress: StudentProgressSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stageTitle)
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text(stageDetail)
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text("第 \(flow.roundNumber) 輪")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(stageColor)
                    .background(stageColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            if let progress, (flow.stage == .missionActive || flow.stage == .missionCompleted) {
                ProgressView(value: progress.progressFraction)
                    .tint(stageColor)
                Text(progress.progressText)
                    .font(.caption.bold())
                    .foregroundStyle(stageColor)
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var stageTitle: String {
        switch flow.stage {
        case .needsCheckIn:
            return "先完成心情檢測"
        case .missionActive:
            return "今日任務進行中"
        case .missionCompleted:
            return "今日任務完成"
        case .freePractice:
            return "自由練習中"
        }
    }

    private var stageDetail: String {
        switch flow.stage {
        case .needsCheckIn:
            if let continuation = flow.continuation {
                return "可以延續上一輪：\(continuation.progressText)。若想重新安排，請到學習地圖按重新檢測。"
            }
            return "回答四題短檢測後，系統會安排今天的任務。"
        case .missionActive:
            return "答對題目才會推進每日任務進度。"
        case .missionCompleted:
            return "你已完成今天的任務，下一步可以自由練習。"
        case .freePractice:
            return "自由練習不影響每日任務完成度。"
        }
    }

    private var stageColor: Color {
        switch flow.stage {
        case .needsCheckIn:
            return EPTheme.primary
        case .missionActive:
            return EPTheme.warning
        case .missionCompleted:
            return EPTheme.support
        case .freePractice:
            return EPTheme.primary
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
            .foregroundStyle(EPTheme.secondaryInk)
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
    let questionItem: QuestionBankItem?
    let aiResponse: AiProxyResponse?
    let supportConfirmation: String?
    let supportRequestSent: Bool
    let canRequestHumanSupport: Bool
    let isLoadingAI: Bool
    let onOpenPractice: () -> Void
    let onOpenSupport: () -> Void
    let onAskAI: () -> Void
    let onSendSupport: () -> Void

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
                .foregroundStyle(EPTheme.secondaryInk)
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
                if !attempt.isCorrect {
                    AIActionButtonRow(
                        title: "去練同類題",
                        detail: "把 AI 的提示接到自由練習，先補這一類再回每日任務。",
                        systemImage: "target"
                    ) {
                        onOpenPractice()
                    }
                }
            } else if !attempt.isCorrect {
                Text("提示：\(attempt.repairHint)")
                    .font(.footnote)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !attempt.isCorrect, questionItem != nil {
                MissionQuestionSupportPanel(
                    aiResponse: aiResponse,
                    supportConfirmation: supportConfirmation,
                    supportRequestSent: supportRequestSent,
                    canRequestHumanSupport: canRequestHumanSupport,
                    isLoadingAI: isLoadingAI,
                    onOpenSupport: onOpenSupport,
                    onAskAI: onAskAI,
                    onSendSupport: onSendSupport
                )
            }
        }
        .padding(14)
        .background((attempt.isCorrect ? EPTheme.support : EPTheme.warning).opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct MissionQuestionSupportPanel: View {
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
            Label("看完結果，需要再拆一步嗎？", systemImage: "lifepreserver")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text(canRequestHumanSupport
                ? "答案已送出。你可以請 AI 換個方式說明，或把這次作答送給班級老師與志工。"
                : "答案已送出。你可以請 AI 換個方式說明；加入班級後，也能把這次作答送給真人協助。")
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                Button(action: onAskAI) {
                    Label(aiResponse == nil ? "請 AI 換個方式解釋" : "請 AI 再解釋一次", systemImage: "sparkles")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryActionButtonStyle())
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

            if let supportConfirmation {
                VStack(alignment: .leading, spacing: 8) {
                    Label(supportConfirmation, systemImage: "paperplane.fill")
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
        .background(EPTheme.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct AIActionButtonRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(EPTheme.primary)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.bold())
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.secondaryInk)
            }
            .foregroundStyle(EPTheme.ink)
            .padding(12)
            .background(EPTheme.elevatedCard)
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        }
        .buttonStyle(.plain)
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
                    .foregroundStyle(EPTheme.secondaryInk)
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

            Text(response.userFacingAvailabilityMessage)
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)

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
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(EPTheme.support.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct StudentHumanHelpCard: View {
    let canSendToClass: Bool
    let hasSentRequest: Bool
    let onSend: () -> Void
    let onOpenSupport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("今天先不用硬撐", systemImage: "heart.circle.fill")
                .font(.headline)
                .foregroundStyle(EPTheme.support)

            Text("心情檢測只用來調整學習任務，不會自動通知老師、志工或其他人。需要陪伴時，由你決定要不要主動送出。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if hasSentRequest {
                Label("已送給老師與志工，可到支持頁查看回覆或收回。", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(EPTheme.support)

                Button("查看支持回覆", action: onOpenSupport)
                    .buttonStyle(SecondaryActionButtonStyle())
            } else if canSendToClass {
                Button(action: onSend) {
                    Label("主動請老師或志工陪我", systemImage: "person.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
            } else {
                Text("目前是個人學習模式，因此不會把訊息傳給老師或志工；你仍可直接使用下方的官方求助資源。")
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Text("需要立即協助")
                .font(.caption.bold())
                .foregroundStyle(EPTheme.secondaryInk)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    HumanHelpPhoneLink(title: "安心專線 1925", number: "1925")
                    HumanHelpPhoneLink(title: "保護專線 113", number: "113")
                }
                VStack(spacing: 8) {
                    HumanHelpPhoneLink(title: "安心專線 1925", number: "1925")
                    HumanHelpPhoneLink(title: "保護專線 113", number: "113")
                }
            }

            HumanHelpPhoneLink(title: "有立即危險請撥 119", number: "119", isEmergency: true)

            Text("English+ 不是 24 小時緊急服務，也無法保證老師或志工立即看到訊息。遇到立即危險，請直接找身邊可信任的大人或撥 119。")
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.support.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct HumanHelpPhoneLink: View {
    let title: String
    let number: String
    var isEmergency = false

    var body: some View {
        Link(destination: URL(string: "tel:\(number)")!) {
            Label(title, systemImage: "phone.fill")
                .font(.caption.bold())
                .foregroundStyle(isEmergency ? EPTheme.warning : EPTheme.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background((isEmergency ? EPTheme.warning : EPTheme.primary).opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityHint("撥打 \(number)")
    }
}
