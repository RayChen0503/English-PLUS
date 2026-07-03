import SwiftUI

struct StudentHomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    let onOpenSupport: () -> Void

    @State private var moodScore = 3
    @State private var timeLevel = 3
    @State private var wantsChallenge = false
    @State private var selectedTypes = Set<QuestionType>()
    @State private var selectedAnswer = ""
    @State private var isGeneratingMissionWithAI = false
    @State private var isExplainingWrongAnswer = false
    @State private var latestWrongAnswerAIResponse: AiProxyResponse?
    @State private var missionSupportConfirmation: String?
    @State private var missionSupportSentQuestionIds = Set<String>()

    init(onOpenSupport: @escaping () -> Void = {}) {
        self.onOpenSupport = onOpenSupport
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

                        if let assignment = learningRepository.pendingAssignments(forStudentUid: currentStudentUid).first {
                            assignedPracticeTaskCard(assignment)
                        }

                        studentFlowContent

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
        case .missionCompleted:
            missionCompletionActions
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
                .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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

            Text("今天的每日任務已完成。你可以保留成果去自由練習，也可以重新做一次心情檢測，讓 English+ 幫你安排下一輪任務。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    learningRepository.startNewLearningRound(
                        for: appState.currentUser,
                        profile: appState.currentProfile
                    )
                } label: {
                    Label("再跑一輪", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button {
                    learningRepository.enterFreePracticeMode()
                } label: {
                    Label("自由練習", systemImage: "pencil.and.list.clipboard")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
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
            Text("這裡不計入每日任務進度。想回到今天任務時，可以切回任務流程；想重新安排，也可以再做一次心情檢測。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    learningRepository.returnToMissionFlow()
                } label: {
                    Label("回到今日任務", systemImage: "target")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)

                Button {
                    learningRepository.startNewLearningRound(
                        for: appState.currentUser,
                        profile: appState.currentProfile
                    )
                } label: {
                    Label("重新檢測", systemImage: "checklist")
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
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private func assignedPracticeTaskCard(_ assignment: TeacherAssignedPracticeTask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("老師指派練習", systemImage: "person.crop.rectangle.badge.plus")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text(assignment.setTitle)
                .font(.title3.bold())
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(assignment.questionIds.count) 題・答對才會推進任務進度。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                learningRepository.startAssignedPracticeTask(assignment)
                selectedAnswer = ""
                latestWrongAnswerAIResponse = nil
            } label: {
                Label("開始老師指派題組", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(16)
        .background(EPTheme.support.opacity(0.12))
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

    private var currentStudentUid: String? {
        appState.currentUser?.id ?? appState.currentProfile?.id
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
        missionSupportConfirmation = nil

        guard !attempt.isCorrect else { return }
        Task {
            await askMissionAI(for: item, attempt: attempt)
        }
    }

    private func askMissionAI(for item: QuestionBankItem, attempt: MissionAttempt) async {
        isExplainingWrongAnswer = true
        let aiContext = WrongAnswerAIContext(
            classId: currentClassId,
            studentUid: appState.currentUser?.id,
            attempt: attempt,
            questionItem: item
        )
        latestWrongAnswerAIResponse = await appState.explainWrongAnswerWithAI(context: aiContext)
        isExplainingWrongAnswer = false
    }

    private func missionFeedbackCard(for attempt: MissionAttempt) -> some View {
        let item = learningRepository.currentMission?.questions.first { $0.id == attempt.questionId }
        return FeedbackCard(
            attempt: attempt,
            questionItem: item,
            aiResponse: latestWrongAnswerAIResponse,
            supportConfirmation: missionSupportConfirmation,
            teacherRequestSent: item.map { missionSupportSentQuestionIds.contains(missionSupportSentKey(for: $0, target: .teacher)) } ?? false,
            volunteerRequestSent: item.map { missionSupportSentQuestionIds.contains(missionSupportSentKey(for: $0, target: .volunteer)) } ?? false,
            isLoadingAI: isExplainingWrongAnswer,
            onOpenPractice: openPracticeFromAI,
            onOpenSupport: onOpenSupport,
            onAskAI: {
                guard let item else { return }
                Task {
                    await askMissionAI(for: item, attempt: attempt)
                }
            },
            onSendTeacher: {
                guard let item else { return }
                sendMissionSupportRequest(for: item, attempt: attempt, target: .teacher)
            },
            onSendVolunteer: {
                guard let item else { return }
                sendMissionSupportRequest(for: item, attempt: attempt, target: .volunteer)
            }
        )
    }

    private func sendMissionSupportRequest(
        for item: QuestionBankItem,
        attempt: MissionAttempt,
        target: MissionSupportTarget
    ) {
        learningRepository.sendQuestionSupportRequest(
            from: appState.currentUser,
            profile: appState.currentProfile,
            option: missionSupportOption(for: target),
            questionItem: item,
            selectedAnswer: attempt.selectedAnswer,
            message: missionSupportMessage(for: item, attempt: attempt, target: target)
        )
        missionSupportSentQuestionIds.insert(missionSupportSentKey(for: item, target: target))
        missionSupportConfirmation = target.confirmationText
    }

    private func missionSupportOption(for target: MissionSupportTarget) -> SupportOption {
        switch target {
        case .teacher:
            return SeedData.supportOptions.first { $0.id == "human-company" }
                ?? SupportOption(
                    id: "mission-teacher-help",
                    reason: "請老師協助今日任務",
                    studentText: "我想請老師看今天任務裡這一題。",
                    platformAction: "請老師查看學生今日任務題目、答案與 AI 提示。",
                    route: .humanHandoff
                )
        case .volunteer:
            return SeedData.supportOptions.first { $0.id == "reading-too-long" }
                ?? SupportOption(
                    id: "mission-volunteer-help",
                    reason: "請志工陪伴今日任務",
                    studentText: "我想請志工陪我看今天任務裡這一題。",
                    platformAction: "請志工陪學生拆解今日任務題目。",
                    route: .readingBreakdown
                )
        }
    }

    private func missionSupportMessage(
        for item: QuestionBankItem,
        attempt: MissionAttempt,
        target: MissionSupportTarget
    ) -> String {
        """
        我在今日任務這題卡住，想請\(target.displayName)看一下。
        題型：\(item.question.type.title)
        難度：\(item.level.uiTitle)
        題目：\(item.question.prompt)
        我的答案：\(attempt.selectedAnswer)
        正確答案：\(item.question.answer)
        解析：\(item.question.explanation)
        AI/系統提示：\(attempt.repairHint)
        """
    }

    private func missionSupportSentKey(for item: QuestionBankItem, target: MissionSupportTarget) -> String {
        "\(item.id)-\(target.rawValue)"
    }

    private func openPracticeFromAI() {
        learningRepository.enterFreePracticeMode()
        selectedAnswer = ""
        latestWrongAnswerAIResponse = nil
        missionSupportConfirmation = nil
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
                        .foregroundStyle(.secondary)
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
                return "可以重新檢測，也可以延續上一輪：\(continuation.progressText)。"
            }
            return "回答四題短檢測後，系統會安排今天的任務。"
        case .missionActive:
            return "答對題目才會推進每日任務進度。"
        case .missionCompleted:
            return "你已完成今天的任務，可以自由練習或再跑一輪。"
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

private enum MissionSupportTarget: String {
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

private struct FeedbackCard: View {
    let attempt: MissionAttempt
    let questionItem: QuestionBankItem?
    let aiResponse: AiProxyResponse?
    let supportConfirmation: String?
    let teacherRequestSent: Bool
    let volunteerRequestSent: Bool
    let isLoadingAI: Bool
    let onOpenPractice: () -> Void
    let onOpenSupport: () -> Void
    let onAskAI: () -> Void
    let onSendTeacher: () -> Void
    let onSendVolunteer: () -> Void

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
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !attempt.isCorrect, questionItem != nil {
                MissionQuestionSupportPanel(
                    aiResponse: aiResponse,
                    supportConfirmation: supportConfirmation,
                    teacherRequestSent: teacherRequestSent,
                    volunteerRequestSent: volunteerRequestSent,
                    isLoadingAI: isLoadingAI,
                    onOpenSupport: onOpenSupport,
                    onAskAI: onAskAI,
                    onSendTeacher: onSendTeacher,
                    onSendVolunteer: onSendVolunteer
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
    let teacherRequestSent: Bool
    let volunteerRequestSent: Bool
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

            Text("AI 可以立刻再講一次；老師或志工會收到這一題、你的答案與解析。送出後到「支持」查看回覆。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(action: onAskAI) {
                    Label(aiResponse == nil ? "問 AI 解題" : "再問 AI 一次", systemImage: "sparkles")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoadingAI)

                Button(action: onSendTeacher) {
                    Label(teacherRequestSent ? "已送老師" : "送給老師", systemImage: "person.text.rectangle")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(teacherRequestSent)

                Button(action: onSendVolunteer) {
                    Label(volunteerRequestSent ? "已送志工" : "送給志工", systemImage: "hands.sparkles")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(volunteerRequestSent)
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
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.74))
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
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(EPTheme.ink)
            .padding(12)
            .background(.white.opacity(0.72))
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
                ? "先用內建提示幫你整理下一步。"
                : "已整理成下一個可執行的小步驟。")
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
