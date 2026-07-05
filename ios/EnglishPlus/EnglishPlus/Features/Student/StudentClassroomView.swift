import SwiftUI

struct StudentClassroomView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    let onOpenHome: () -> Void

    init(onOpenHome: @escaping () -> Void = {}) {
        self.onOpenHome = onOpenHome
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard

                        if pendingAssignments.isEmpty {
                            emptyStateCard
                        } else {
                            pendingSection
                        }

                        if !completedAssignments.isEmpty {
                            completedSection
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("班級")
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(EPTheme.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("老師指派任務")
                        .font(.title3.bold())
                        .foregroundStyle(EPTheme.ink)
                    Text("這裡只放老師指定給你的練習。收到新任務時，班級欄位會出現提醒；完成後提醒會自動消失。")
                        .font(.subheadline)
                        .foregroundStyle(EPTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                ClassroomStatPill(title: "待完成", value: "\(pendingAssignments.count)")
                ClassroomStatPill(title: "已完成", value: "\(completedAssignments.count)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("目前沒有老師指派任務", systemImage: "checkmark.seal")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text("你可以先去練習中心自由練習。之後老師派新的任務時，這裡會直接出現，不會混在首頁或學習地圖裡。")
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
            Text("待完成")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            ForEach(pendingAssignments) { assignment in
                ClassroomAssignmentCard(
                    assignment: assignment,
                    primaryActionTitle: assignment.status == .active ? "繼續任務" : "開始任務",
                    primaryActionIcon: assignment.status == .active ? "arrow.right.circle.fill" : "play.circle.fill"
                ) {
                    if assignment.status == .pending {
                        learningRepository.startAssignedPracticeTask(assignment)
                    }
                    onOpenHome()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("完成紀錄")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            ForEach(completedAssignments.prefix(5)) { assignment in
                ClassroomAssignmentCard(
                    assignment: assignment,
                    primaryActionTitle: nil,
                    primaryActionIcon: nil,
                    onPrimaryAction: nil
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var pendingAssignments: [TeacherAssignedPracticeTask] {
        assignments.filter { $0.status != .completed }
    }

    private var completedAssignments: [TeacherAssignedPracticeTask] {
        assignments.filter { $0.status == .completed }
    }

    private var assignments: [TeacherAssignedPracticeTask] {
        learningRepository.assignments(forStudentUid: currentStudentUid)
    }

    private var currentStudentUid: String? {
        appState.currentUser?.id ?? appState.currentProfile?.id
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
                ClassroomStatPill(title: "班級", value: assignment.classId)
            }

            Text("完成這組任務後，老師就能更清楚看到你的練習進度。卡住時也可以在題目下方送出求助。")
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
        .background(EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
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
            return "進行中"
        case .completed:
            return "完成"
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
        }
    }
}
