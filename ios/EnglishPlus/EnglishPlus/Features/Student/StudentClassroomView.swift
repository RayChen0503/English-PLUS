import SwiftUI

struct StudentClassroomView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    @State private var joinCode = ""
    @State private var showsJoinAnotherClass = false
    @State private var classIdPendingLeave: String?
    @State private var openedAssignmentID: String?
    @State private var selectedAnswer = ""
    @State private var isSubmittingAnswer = false

    let onOpenHome: () -> Void

    init(onOpenHome: @escaping () -> Void = {}) {
        self.onOpenHome = onOpenHome
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()

                if let openedAssignment {
                    assignmentSession(openedAssignment)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            headerCard

                            if isPersonalMode {
                                personalModeCard
                                if !studentClassrooms.isEmpty || showsJoinAnotherClass {
                                    classAccessCard
                                }
                            } else if pendingAssignments.isEmpty {
                                emptyStateCard
                            } else {
                                pendingSection
                            }

                            if !isPersonalMode && !completedAssignments.isEmpty {
                                completedSection
                            }

                            if !isPersonalMode {
                                classAccessCard
                            }
                        }
                        .padding(EPTheme.pagePadding)
                    }
                }
            }
            .navigationTitle(openedAssignment == nil ? "班級" : "班級任務")
            .task {
                await appState.loadClassrooms()
            }
            .onChange(of: appState.currentProfile?.activeClassId) { _, _ in
                joinCode = ""
                showsJoinAnotherClass = false
                classIdPendingLeave = nil
                closeAssignmentSession()
            }
            .onChange(of: learningRepository.assignedPracticeTasks) { _, tasks in
                guard let openedAssignmentID else { return }
                if !tasks.contains(where: {
                    $0.id == openedAssignmentID && $0.status != .withdrawn
                }) {
                    closeAssignmentSession()
                }
            }
            .alert(
                "確定離開班級？",
                isPresented: Binding(
                    get: { classIdPendingLeave != nil },
                    set: { if !$0 { classIdPendingLeave = nil } }
                )
            ) {
                Button("取消", role: .cancel) {
                    classIdPendingLeave = nil
                }
                Button("離開班級", role: .destructive) {
                    guard let classId = classIdPendingLeave else { return }
                    classIdPendingLeave = nil
                    Task { await appState.leaveClassroom(classId: classId) }
                }
            } message: {
                Text("離開後將不再收到這個班級的新任務，老師也不能繼續查看你的即時資料；你的個人學習紀錄仍會保留。")
            }
        }
    }

    private var classAccessCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isPersonalMode ? "person.crop.circle" : "person.3.fill")
                    .font(.title3)
                    .foregroundStyle(EPTheme.primary)
                    .frame(width: 40, height: 40)
                    .background(EPTheme.primary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(isPersonalMode ? "目前：個人模式" : "目前：\(activeClassroom?.name ?? "班級模式")")
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text(isPersonalMode
                        ? "不加入班級也能正常學習；有老師提供的代碼時再加入即可。"
                        : "此頁只顯示目前班級的指派任務。切換班級後，內容會自動更新。")
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if appState.isLoadingClassrooms {
                Label("正在載入班級...", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote)
                    .foregroundStyle(EPTheme.secondaryInk)
            }

            if !studentClassrooms.isEmpty {
                Menu {
                    ForEach(studentClassrooms) { classroom in
                        Button {
                            Task { await appState.selectActiveClass(classroom.classId) }
                        } label: {
                            Label(
                                classroom.name,
                                systemImage: classroom.classId == appState.currentProfile?.activeClassId
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                        }
                    }
                } label: {
                    HStack {
                        Label("切換班級", systemImage: "arrow.left.arrow.right")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 12)
                    .foregroundStyle(EPTheme.ink)
                    .background(EPTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                }

                HStack(spacing: 8) {
                    if !isPersonalMode {
                        Button {
                            Task { await appState.selectActiveClass(nil) }
                        } label: {
                            Label("個人模式", systemImage: "person.crop.circle")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())

                        Button(role: .destructive) {
                            classIdPendingLeave = appState.currentProfile?.activeClassId
                        } label: {
                            Label("離開班級", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            }

            if showsJoinAnotherClass {
                joinClassForm
            } else {
                Button {
                    showsJoinAnotherClass = true
                } label: {
                    Label("加入另一個班級", systemImage: "person.badge.plus")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            if let notice = appState.classroomNoticeMessage {
                ClassroomInlineMessage(text: notice, isError: false)
            }
            if let error = appState.classroomErrorMessage {
                ClassroomInlineMessage(text: error, isError: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var joinClassForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("輸入老師提供的 8 碼代碼")
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.ink)

            TextField("例如 ABCD EFGH", text: $joinCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
                .font(.body.monospaced())
                .padding(12)
                .background(EPTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                .accessibilityIdentifier("student.classroom.joinCode")

            Button {
                Task {
                    let joined = await appState.joinClassroom(code: normalizedJoinCode)
                    if joined {
                        joinCode = ""
                        showsJoinAnotherClass = false
                    }
                }
            } label: {
                if appState.isManagingClassroom {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Label("加入班級", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(normalizedJoinCode.count != 8 || appState.isManagingClassroom)
            .opacity(normalizedJoinCode.count == 8 && !appState.isManagingClassroom ? 1 : 0.45)
            .accessibilityIdentifier("student.classroom.join")

            Button("取消") {
                joinCode = ""
                showsJoinAnotherClass = false
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }

    private var studentClassrooms: [ClassroomSummary] {
        appState.classrooms.filter { $0.role == .student && $0.status == .active }
    }

    private var activeClassroom: ClassroomSummary? {
        studentClassrooms.first { $0.classId == appState.currentProfile?.activeClassId }
    }

    private var normalizedJoinCode: String {
        String(joinCode.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(EPTheme.primary)
                    .frame(width: 38, height: 38)
                    .background(EPTheme.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text("班級任務")
                        .font(.title3.bold())
                        .foregroundStyle(EPTheme.ink)
                    Text(isPersonalMode
                        ? "目前沒有啟用班級。你的每日任務、AI 解題與自由練習都能照常使用。"
                        : "先完成老師派給你的題組；完成後會自動移到下方紀錄。")
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !isPersonalMode {
                HStack(spacing: 8) {
                    ClassroomStatPill(title: "待完成", value: "\(pendingAssignments.count)")
                    ClassroomStatPill(title: "已完成", value: "\(completedAssignments.count)")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        .accessibilityIdentifier("student.classroom.header")
    }

    private var personalModeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("目前沒有班級任務", systemImage: "person.crop.circle.badge.checkmark")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text("你可以照常完成每日任務與自由練習。加入班級後，老師指派的題組會自動出現在這裡。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showsJoinAnotherClass = true
            } label: {
                Label("使用班級代碼加入", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .accessibilityIdentifier("student.classroom.showJoin")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        .accessibilityIdentifier("student.classroom.personalMode")
    }

    private var isPersonalMode: Bool {
        appState.currentProfile?.activeClassId == nil
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("目前沒有老師指派任務", systemImage: "checkmark.seal")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text("你可以先完成今日任務或自由練習。老師派發新題組時，這一頁會出現提醒。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("待完成")
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Spacer()
                Text("\(pendingAssignments.count) 組")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.warning)
            }

            ForEach(pendingAssignments) { assignment in
                ClassroomAssignmentCard(
                    assignment: assignment,
                    primaryActionTitle: assignment.status == .active ? "繼續練習" : "開始題組",
                    primaryActionIcon: assignment.status == .active ? "arrow.right.circle.fill" : "play.circle.fill"
                ) {
                    Task {
                        if assignment.status == .pending {
                            guard await learningRepository.startAssignedPracticeTask(assignment) else {
                                return
                            }
                        }
                        openedAssignmentID = assignment.id
                        selectedAnswer = ""
                    }
                }
            }

            if let error = learningRepository.assignmentActionErrorMessage {
                ClassroomInlineMessage(text: error, isError: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("student.classroom.pending")
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近完成")
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Spacer()
                Text("保留最近 5 組")
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
            }

            ForEach(completedAssignments.prefix(5)) { assignment in
                ClassroomAssignmentCard(
                    assignment: assignment,
                    primaryActionTitle: nil,
                    primaryActionIcon: nil,
                    onPrimaryAction: nil
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("student.classroom.completed")
    }

    private var pendingAssignments: [TeacherAssignedPracticeTask] {
        assignments.filter { $0.status == .pending || $0.status == .active }
    }

    private var completedAssignments: [TeacherAssignedPracticeTask] {
        assignments.filter { $0.status == .completed }
    }

    private var assignments: [TeacherAssignedPracticeTask] {
        learningRepository.assignments(forStudentUid: currentStudentUid)
            .filter { $0.status != .withdrawn }
    }

    private var currentStudentUid: String? {
        appState.currentUser?.id ?? appState.currentProfile?.id
    }

    private var openedAssignment: TeacherAssignedPracticeTask? {
        guard let openedAssignmentID else { return nil }
        return assignments.first { $0.id == openedAssignmentID }
    }

    private func assignmentSession(_ assignment: TeacherAssignedPracticeTask) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    closeAssignmentSession()
                } label: {
                    Label("離開題組", systemImage: "chevron.left")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(EPTheme.primary)

                VStack(alignment: .leading, spacing: 10) {
                    Text(assignment.setTitle)
                        .font(.title2.bold())
                        .foregroundStyle(EPTheme.ink)
                    Text("由 \(assignment.assignedByName) 指派 · 共 \(assignment.questionIds.count) 題")
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.secondaryInk)
                    ProgressView(
                        value: Double(correctAssignmentCount(assignment)),
                        total: Double(max(assignment.questionIds.count, 1))
                    )
                    .tint(assignment.status == .completed ? EPTheme.support : EPTheme.primary)
                    Text(assignment.status == .completed
                        ? "全部完成，老師已收到作答結果。"
                        : "已答對 \(correctAssignmentCount(assignment))/\(assignment.questionIds.count) 題；答錯可留在原題重試。")
                        .font(.caption)
                        .foregroundStyle(EPTheme.secondaryInk)
                }
                .padding(16)
                .background(EPTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

                if assignment.status == .completed {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("這組班級任務完成了", systemImage: "checkmark.seal.fill")
                            .font(.title3.bold())
                            .foregroundStyle(EPTheme.support)
                        Text("班級紅點會消失，老師端也能查看每題作答結果。")
                            .font(.subheadline)
                            .foregroundStyle(EPTheme.secondaryInk)
                        Button("回到班級任務") { closeAssignmentSession() }
                            .buttonStyle(PrimaryActionButtonStyle())
                    }
                    .padding(16)
                    .background(EPTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                } else if let item = nextAssignmentQuestion(for: assignment) {
                    assignmentQuestionCard(item, assignment: assignment)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ProgressView()
                        Text("正在同步老師指派的題目... 這裡只會載入「\(assignment.setTitle)」的題目。")
                            .font(.subheadline)
                            .foregroundStyle(EPTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(EPTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                }

                if let error = learningRepository.assignmentActionErrorMessage {
                    ClassroomInlineMessage(text: error, isError: true)
                }
            }
            .padding(EPTheme.pagePadding)
        }
    }

    private func assignmentQuestionCard(
        _ item: QuestionBankItem,
        assignment: TeacherAssignedPracticeTask
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(item.question.type.title)
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.primary)
                Text(item.level.uiTitle)
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
                Spacer()
                Text("第 \(currentAssignmentQuestionNumber(assignment)) 題")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.secondaryInk)
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
                    ForEach(Array(assignmentOptionOrder(for: item, in: assignment).enumerated()), id: \.offset) { _, option in
                        ClassroomAnswerOptionButton(
                            option: option,
                            isSelected: option == selectedAnswer
                        ) {
                            selectedAnswer = option
                        }
                    }
                }
            }

            Button {
                Task { await submitAssignmentAnswer() }
            } label: {
                if isSubmittingAnswer {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text("送出答案").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(selectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingAnswer)
            .opacity(selectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingAnswer ? 0.45 : 1)

            if let attempt = latestAttempt(for: item) {
                Label(
                    attempt.isCorrect ? "答對了，進度已同步給老師。" : "還差一點，看看提示後再試一次。",
                    systemImage: attempt.isCorrect ? "checkmark.circle.fill" : "lightbulb.fill"
                )
                .font(.subheadline.bold())
                .foregroundStyle(attempt.isCorrect ? EPTheme.support : EPTheme.warning)

                if !attempt.isCorrect {
                    Text(attempt.repairHint)
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    @MainActor
    private func submitAssignmentAnswer() async {
        guard !isSubmittingAnswer else { return }
        guard let assignment = openedAssignment else { return }
        isSubmittingAnswer = true
        defer { isSubmittingAnswer = false }
        guard await learningRepository.submitAssignedPracticeAnswer(
            selectedAnswer,
            assignmentId: assignment.id
        ) != nil else { return }
        selectedAnswer = ""
    }

    private func latestAttempt(for item: QuestionBankItem) -> PracticeAssignmentQuestionResult? {
        openedAssignment?.questionResults?.first { $0.questionId == item.id }
    }

    private func correctAssignmentCount(_ assignment: TeacherAssignedPracticeTask) -> Int {
        assignment.questionResults?.filter(\.isCorrect).count ?? 0
    }

    private func currentAssignmentQuestionNumber(_ assignment: TeacherAssignedPracticeTask) -> Int {
        guard let questionId = nextAssignmentQuestion(for: assignment)?.id,
              let index = assignment.questionIds.firstIndex(of: questionId) else {
            return max(1, correctAssignmentCount(assignment) + 1)
        }
        return index + 1
    }

    private func nextAssignmentQuestion(
        for assignment: TeacherAssignedPracticeTask
    ) -> QuestionBankItem? {
        let completedQuestionIds = Set(
            (assignment.questionResults ?? [])
                .filter(\.isCorrect)
                .map(\.questionId)
        )
        guard let questionId = assignment.questionIds.first(where: {
            !completedQuestionIds.contains($0)
        }) else { return nil }
        return learningRepository.questionBankItems.first { $0.id == questionId }
    }

    private func assignmentOptionOrder(
        for item: QuestionBankItem,
        in assignment: TeacherAssignedPracticeTask
    ) -> [String] {
        let index = assignment.questionIds.firstIndex(of: item.id) ?? 0
        return QuestionGroupingEngine.balancedOptions(for: item, sessionIndex: index)
    }

    private func closeAssignmentSession() {
        openedAssignmentID = nil
        selectedAnswer = ""
        isSubmittingAnswer = false
        learningRepository.clearAssignmentActionError()
    }
}

private struct ClassroomAnswerOptionButton: View {
    let option: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? EPTheme.primary : EPTheme.secondaryInk)
                Text(option)
                    .foregroundStyle(EPTheme.ink)
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(isSelected ? EPTheme.primary.opacity(0.12) : EPTheme.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        }
        .buttonStyle(.plain)
    }
}

private struct ClassroomInlineMessage: View {
    let text: String
    let isError: Bool

    var body: some View {
        Label(text, systemImage: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
            .font(.footnote)
            .foregroundStyle(isError ? EPTheme.warning : EPTheme.support)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((isError ? EPTheme.warning : EPTheme.support).opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ClassroomAssignmentCard: View {
    let assignment: TeacherAssignedPracticeTask
    let primaryActionTitle: String?
    let primaryActionIcon: String?
    let onPrimaryAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.setTitle)
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("由 \(assignment.assignedByName) 指派")
                        .font(.caption)
                        .foregroundStyle(EPTheme.secondaryInk)
                }

                Spacer()

                Text(assignment.status.classroomTitle)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(assignment.status.classroomColor)
                    .background(assignment.status.classroomColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                ClassroomStatPill(title: "題數", value: "\(assignment.questionIds.count)")
                ClassroomStatPill(title: "進度", value: "\(answeredQuestionCount)/\(assignment.questionIds.count)")
            }

            Text(assignment.status == .completed
                 ? "這組題目已完成，老師可以在班級端查看作答結果。"
                 : "完成後老師會看到你的作答情況。老師收回任務後，任務會從這裡消失。")
                .font(.footnote)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            if let primaryActionTitle,
               let primaryActionIcon,
               let onPrimaryAction {
                Button {
                    onPrimaryAction()
                } label: {
                    Label(primaryActionTitle, systemImage: primaryActionIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
        .padding(14)
        .background(EPTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: EPTheme.cardRadius)
                .stroke(EPTheme.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var answeredQuestionCount: Int {
        Set(assignment.questionResults?.map(\.questionId) ?? []).count
    }
}

private struct ClassroomStatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(EPTheme.secondaryInk)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private extension PracticeAssignmentStatus {
    var classroomTitle: String {
        switch self {
        case .pending:
            return "待開始"
        case .active:
            return "練習中"
        case .completed:
            return "已完成"
        case .withdrawn:
            return "已收回"
        }
    }

    var classroomColor: Color {
        switch self {
        case .pending:
            return EPTheme.warning
        case .active:
            return EPTheme.primary
        case .completed:
            return EPTheme.support
        case .withdrawn:
            return EPTheme.secondaryInk
        }
    }
}
