import SwiftUI

struct TeacherHomeView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("今日需要先接住誰")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        TeacherStatusStrip()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("優先處理")
                                .font(.headline)
                            ForEach(learningRepository.teacherQueue.prefix(3)) { request in
                                TeacherRequestCard(request: request)
                            }
                        }

                        TeacherClassSummary()
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("教師工作台")
        }
    }
}

struct TeacherStudentsView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                List {
                    ForEach(learningRepository.staffStudentSummaries) { summary in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(summary.studentName)
                                    .font(.headline)
                                Spacer()
                                Text(summary.riskLevel.uiTitle)
                                    .font(.caption.bold())
                                    .foregroundStyle(summary.riskLevel == .high ? EPTheme.warning : EPTheme.support)
                            }
                            Text(summary.classCode)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(summary.nextAction)
                                .font(.subheadline)
                                .foregroundStyle(EPTheme.ink)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("學生紀錄")
        }
    }
}

struct TeacherHandoffView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("接力優先序")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        Text("排序規則：學生主動求助、高風險心情、閱讀卡點會先排在前面。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        TeacherHandoffSummaryCard()

                        ForEach(learningRepository.teacherQueue) { request in
                            TeacherRequestCard(request: request)
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("接力")
        }
    }
}

struct TeacherReportView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("班級週報")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        Text("用進步證據取代排名壓力，整理學生任務、求助與接力紀錄。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TeacherReportSignalCard(
                            title: "本週支持重點",
                            message: "先處理 \(learningRepository.staffDashboardMetrics.waitingHelpCount) 件待回應求助，再看高風險學生是否需要志工接力。",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            tint: EPTheme.warning
                        )

                        TeacherReportSignalCard(
                            title: "題庫與任務",
                            message: "目前可用 \(learningRepository.staffDashboardMetrics.questionCount) 題，題型已分成選擇、填空、克漏字、閱讀、翻譯與對話。",
                            systemImage: "books.vertical",
                            tint: EPTheme.primary
                        )

                        TeacherReportSignalCard(
                            title: "給學生看的回饋",
                            message: "你不是沒有進步，而是正在把問題縮小。今天能完成一個小關卡，就是英文斷點被修復的一步。",
                            systemImage: "sparkles",
                            tint: EPTheme.support
                        )

                        Button("分享摘要") {}
                            .buttonStyle(PrimaryActionButtonStyle())
                            .disabled(true)
                            .opacity(0.55)
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("報告")
        }
    }
}

struct TeacherQuestionBankView: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("題庫中心")
                            .font(.title.bold())
                            .foregroundStyle(EPTheme.ink)

                        Text("老師可以快速確認題型、難度與任務來源，之後接正式後台即可延伸成審題與派題。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(learningRepository.questionBankOverview) { overview in
                            TeacherQuestionBankRow(overview: overview)
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
            }
            .navigationTitle("題庫")
        }
    }
}

private struct TeacherStatusStrip: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        HStack(spacing: 10) {
            TeacherStatusTile(
                title: "高風險",
                value: "\(learningRepository.staffDashboardMetrics.highRiskCount)",
                color: EPTheme.warning
            )
            TeacherStatusTile(
                title: "待回應",
                value: "\(learningRepository.staffDashboardMetrics.waitingHelpCount)",
                color: EPTheme.primary
            )
            TeacherStatusTile(
                title: "已回覆",
                value: "\(learningRepository.staffDashboardMetrics.repliedCount)",
                color: EPTheme.support
            )
        }
    }
}

private struct TeacherStatusTile: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

struct TeacherRequestCard: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    let request: StudentSupportRequest

    @State private var replyDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.studentName)
                        .font(.headline)
                    Text(request.classCode)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(request.priority.uiTitle)
                    .font(.caption.bold())
                    .foregroundStyle(request.priority == .high ? EPTheme.warning : EPTheme.support)
            }

            Text(request.studentMessage)
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let moodScore = request.moodScore {
                Label("心情 \(moodScore)/5", systemImage: "heart.text.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(request.replies) { reply in
                Text("\(reply.authorName)：\(reply.body)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("輸入老師回饋", text: $replyDraft, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            Button("送出回饋") {
                learningRepository.addTeacherReply(to: request.id, body: replyDraft)
                replyDraft = ""
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct TeacherClassSummary: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("班級狀態")
                .font(.headline)
            ForEach(learningRepository.staffStudentSummaries) { summary in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.studentName)
                            .font(.subheadline.bold())
                        Text(summary.missionProgress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(summary.nextAction)
                        .font(.caption)
                        .foregroundStyle(EPTheme.ink)
                        .multilineTextAlignment(.trailing)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

private struct TeacherHandoffSummaryCard: View {
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("學生資料與真人接力分開處理", systemImage: "arrow.triangle.branch")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text("老師先看求助與風險，再決定要直接回覆、交給志工陪練，或放進本週追蹤。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                TeacherStatusTile(
                    title: "學生",
                    value: "\(learningRepository.staffDashboardMetrics.studentCount)",
                    color: EPTheme.primary
                )
                TeacherStatusTile(
                    title: "平均心情",
                    value: learningRepository.staffDashboardMetrics.averageMoodText,
                    color: EPTheme.support
                )
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

struct TeacherReportSignalCard: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}

struct TeacherQuestionBankRow: View {
    let overview: QuestionBankTypeOverview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(overview.type.title)
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Spacer()
                Text("\(overview.totalCount) 題")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(EPTheme.primary.opacity(0.08))
                    .clipShape(Capsule())
            }

            Text(overview.levelSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }
}
