import QuickLook
import SwiftUI

struct VolunteerReviewView: View {
    @EnvironmentObject private var appState: AppState

    @State private var previewURL: URL?
    @State private var isDownloadingEvidence = false
    @State private var evidenceErrorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if let evidenceErrorMessage {
                            Label(evidenceErrorMessage, systemImage: "exclamationmark.circle.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(EPTheme.danger)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if appState.isLoadingVolunteerReviews {
                            ProgressView("正在載入申請...")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else if let error = appState.volunteerReviewErrorMessage {
                            errorState(error)
                        } else if appState.volunteerReviewApplications.isEmpty {
                            emptyState
                        } else {
                            ForEach(appState.volunteerReviewApplications) { application in
                                VolunteerReviewCard(
                                    application: application,
                                    isDownloadingEvidence: isDownloadingEvidence,
                                    openEvidence: openEvidence
                                )
                            }
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
                .refreshable {
                    await appState.loadVolunteerReviewApplications()
                }
            }
            .navigationTitle("志工審核")
        }
        .task {
            await appState.loadVolunteerReviewApplications()
        }
        .onChange(of: previewURL) { oldValue, newValue in
            if newValue == nil, let oldValue {
                try? FileManager.default.removeItem(at: oldValue)
            }
        }
        .onDisappear {
            if let previewURL {
                try? FileManager.default.removeItem(at: previewURL)
                self.previewURL = nil
            }
        }
        .quickLookPreview($previewURL)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("待審志工")
                .font(.title.bold())
                .foregroundStyle(EPTheme.ink)
            Text("確認申請動機與證明後再核准。核准會立即開通志工帳號；要求補件不會開放學生資料。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.largeTitle)
                .foregroundStyle(EPTheme.support)
            Text("目前沒有待審申請")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            Text("新的志工申請送出後會出現在這裡。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(EPTheme.danger)
            Button("重新載入") {
                Task { await appState.loadVolunteerReviewApplications() }
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private func openEvidence(_ evidence: VolunteerReviewEvidence) {
        Task {
            isDownloadingEvidence = true
            defer { isDownloadingEvidence = false }
            evidenceErrorMessage = nil
            do {
                previewURL = try await appState.downloadVolunteerEvidence(evidence)
            } catch {
                evidenceErrorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "無法開啟這份證明，請檢查網路後再試。"
            }
        }
    }
}

private struct VolunteerReviewCard: View {
    @EnvironmentObject private var appState: AppState

    let application: VolunteerReviewApplication
    let isDownloadingEvidence: Bool
    let openEvidence: (VolunteerReviewEvidence) -> Void

    @State private var note = ""
    @State private var isSubmitting = false
    @State private var confirmationAction: VolunteerReviewAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(application.displayName)
                        .font(.headline)
                        .foregroundStyle(EPTheme.ink)
                    Text(application.status == .needsMoreInformation ? "等待補件" : "等待審核")
                        .font(.caption.bold())
                        .foregroundStyle(application.status == .needsMoreInformation ? EPTheme.warning : EPTheme.primary)
                }
                Spacer()
                Text("\(application.evidence.count) 份證明")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.secondaryInk)
            }

            Text(application.motivation)
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(application.evidence) { evidence in
                    Button {
                        openEvidence(evidence)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: evidence.mimeType == "application/pdf" ? "doc.richtext" : "photo")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(evidence.filename)
                                    .lineLimit(1)
                                Text(evidence.kind.reviewTitle)
                                    .font(.caption)
                                    .foregroundStyle(EPTheme.secondaryInk)
                            }
                            Spacer()
                            Image(systemName: "eye")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EPTheme.primary)
                        .padding(12)
                        .background(EPTheme.secondarySurface)
                        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDownloadingEvidence)
                }
            }

            if application.status == .needsMoreInformation {
                Label("等待申請者補件並重新送出後，才會重新開放審核。", systemImage: "clock.badge")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(EPTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                TextField("審核備註或補件說明", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(EPTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

                HStack(spacing: 10) {
                    Button("要求補件") {
                        confirmationAction = .needsMoreInformation
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("核准") {
                        confirmationAction = .approved
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }

                Button("拒絕申請", role: .destructive) {
                    confirmationAction = .rejected
                }
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        .disabled(isSubmitting)
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { confirmationAction != nil },
                set: { if !$0 { confirmationAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let action = confirmationAction {
                Button(action.confirmationButtonTitle, role: action == .rejected ? .destructive : nil) {
                    Task { await submit(action) }
                }
            }
            Button("取消", role: .cancel) { confirmationAction = nil }
        }
    }

    private var confirmationTitle: String {
        switch confirmationAction {
        case .approved:
            return "核准後會立即開通志工帳號。"
        case .rejected:
            return "拒絕後帳號不會取得志工權限。"
        case .needsMoreInformation:
            return "申請者下次登入時可以補件。"
        default:
            return "確認審核結果"
        }
    }

    private func submit(_ action: VolunteerReviewAction) async {
        isSubmitting = true
        confirmationAction = nil
        _ = await appState.reviewVolunteer(
            uid: application.uid,
            action: action,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        isSubmitting = false
    }
}

private extension VolunteerReviewAction {
    var confirmationButtonTitle: String {
        switch self {
        case .approved:
            return "確認核准"
        case .rejected:
            return "確認拒絕"
        case .needsMoreInformation:
            return "送出補件要求"
        case .suspended:
            return "確認停權"
        }
    }
}

private extension VolunteerQualificationKind {
    var reviewTitle: String {
        switch self {
        case .universityEnrollment:
            return "大專院校在學身分"
        case .englishProficiency:
            return "英語能力證明"
        case .educatorCredential:
            return "教育工作相關證明"
        case .nonprofitOrVolunteerService:
            return "非營利或志工服務證明"
        case .other:
            return "其他證明"
        }
    }
}
