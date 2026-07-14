import SwiftUI
import UniformTypeIdentifiers

struct VolunteerApplicationView: View {
    @EnvironmentObject private var appState: AppState

    @State private var confirmsAge = true
    @State private var acceptedConduct = true
    @State private var motivation = ""
    @State private var evidence: [VolunteerEvidenceReference] = []
    @State private var selectedKind: VolunteerQualificationKind = .universityEnrollment
    @State private var showsFileImporter = false
    @State private var isUploading = false
    @State private var deletingEvidenceID: String?
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        applicationStatusCard
                        identitySection
                        evidenceSection
                        feedback
                        submitButton
                    }
                    .padding(EPTheme.pagePadding)
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(canEditApplication ? "稍後完成" : "登出") { appState.signOut() }
                }
            }
        }
        .task {
            await appState.loadVolunteerApplicationDraft()
            hydrate(from: appState.volunteerApplicationDraft)
        }
        .onChange(of: appState.volunteerApplicationDraft) { _, draft in
            hydrate(from: draft)
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.pdf, .jpeg, .png],
            allowsMultipleSelection: false,
            onCompletion: handleFileSelection
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(canEditApplication ? "第 2 步，共 2 步" : "申請進度")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EPTheme.primary)
            Label(headerTitle, systemImage: "person.badge.shield.checkmark")
                .font(.largeTitle.bold())
                .foregroundStyle(EPTheme.ink)
            Text(headerDetail)
                .font(.body)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var applicationStatusCard: some View {
        if let reviewState = appState.volunteerApplicationReviewState {
            VStack(alignment: .leading, spacing: 10) {
                Label(reviewState.status.applicantTitle, systemImage: reviewState.status.applicantIcon)
                    .font(.headline)
                    .foregroundStyle(reviewState.status.applicantColor)
                Text(reviewState.status.applicantDetail)
                    .font(.subheadline)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                if let note = reviewState.normalizedReviewNote {
                    Divider()
                    Text("管理員說明")
                        .font(.caption.bold())
                        .foregroundStyle(EPTheme.secondaryInk)
                    Text(note)
                        .font(.body)
                        .foregroundStyle(EPTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let reviewedAt = reviewState.reviewedAt {
                        Text(reviewedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(EPTheme.secondaryInk)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(reviewState.status.applicantColor.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: EPTheme.cardRadius)
                    .stroke(reviewState.status.applicantColor.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
            .accessibilityIdentifier("volunteer.application.status")
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("確認申請資料")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            Toggle("我已年滿 18 歲", isOn: $confirmsAge)
            Toggle("我同意志工守則與資料保密規範", isOn: $acceptedConduct)
            VStack(alignment: .leading, spacing: 8) {
                Text("申請動機")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.secondaryInk)
                TextField("簡短說明你想協助學生的原因", text: $motivation, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(EPTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        .disabled(!canEditApplication)
        .opacity(canEditApplication ? 1 : 0.72)
    }

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("資格證明（至少 1 份）")
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
                Text("至少一份，最多 5 份；可使用 PDF、JPG 或 PNG，單檔 10 MB、合計 25 MB。")
                    .font(.footnote)
                    .foregroundStyle(EPTheme.secondaryInk)
                Text("已加入 \(evidence.count)/5 份 · \(formattedSize(totalEvidenceBytes))/25 MB")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(evidenceCapacityExceeded ? EPTheme.warning : EPTheme.secondaryInk)
                Label(
                    "證明只供授權管理員審核；核准、拒絕或停權後 30 天會自動刪除。",
                    systemImage: "lock.shield"
                )
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            }

            Picker("證明類型", selection: $selectedKind) {
                ForEach(VolunteerQualificationKind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.menu)

            Button {
                showsFileImporter = true
            } label: {
                Label(isUploading ? "上傳中..." : "選擇證明文件", systemImage: "doc.badge.plus")
            }
            .disabled(isUploading || !canAddEvidence)
            .buttonStyle(SecondaryActionButtonStyle())

            if evidence.isEmpty {
                Label("尚未加入證明文件", systemImage: "tray")
                    .font(.footnote)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(evidence) { item in
                    evidenceRow(item)
                }
            }
        }
        .disabled(!canEditApplication)
        .opacity(canEditApplication ? 1 : 0.72)
    }

    private func evidenceRow(_ item: VolunteerEvidenceReference) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.mimeType == "application/pdf" ? "doc.richtext" : "photo")
                .foregroundStyle(EPTheme.support)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.originalFilename)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EPTheme.ink)
                    .lineLimit(1)
                Text("\(item.kind.title) · \(formattedSize(item.sizeBytes))")
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
            }
            Spacer()
            Button {
                Task { await removeEvidence(item) }
            } label: {
                Image(systemName: "trash")
                    .frame(width: 44, height: 44)
                    .foregroundStyle(EPTheme.danger)
            }
            .buttonStyle(.plain)
            .disabled(isUploading || deletingEvidenceID != nil)
        }
        .padding(12)
        .background(EPTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: EPTheme.cardRadius)
                .stroke(EPTheme.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    @ViewBuilder
    private var feedback: some View {
        if let localError {
            Label(localError, systemImage: "exclamationmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(EPTheme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let error = appState.signInErrorMessage {
            Label(error, systemImage: "exclamationmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(EPTheme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var submitButton: some View {
        if canEditApplication {
            Button(submitButtonTitle) {
                Task { await appState.submitVolunteerApplication(application) }
            }
            .disabled(
                !application.isReadyToSubmit
                    || isUploading
                    || deletingEvidenceID != nil
                    || appState.signingInRole != nil
            )
            .buttonStyle(PrimaryActionButtonStyle())
        }
    }

    private var application: VolunteerApplicationInput {
        VolunteerApplicationInput(
            confirmsAge18OrOlder: confirmsAge,
            acceptedConductVersion: acceptedConduct ? "volunteer-conduct-v1" : "",
            motivation: motivation.trimmingCharacters(in: .whitespacesAndNewlines),
            evidence: evidence
        )
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result {
                localError = error.localizedDescription
            }
            return
        }
        guard canAddEvidence else {
            localError = "最多可上傳 5 份證明，合計不得超過 25 MB。"
            return
        }
        Task {
            isUploading = true
            localError = nil
            do {
                let uploaded = try await appState.uploadVolunteerEvidence(
                    from: url,
                    kind: selectedKind
                )
                evidence.append(uploaded)
            } catch {
                localError = (error as? LocalizedError)?.errorDescription
                    ?? "文件沒有上傳完成，請再試一次。"
            }
            isUploading = false
        }
    }

    private func removeEvidence(_ item: VolunteerEvidenceReference) async {
        guard deletingEvidenceID == nil else { return }
        localError = nil
        deletingEvidenceID = item.id
        defer { deletingEvidenceID = nil }
        do {
            try await appState.deleteVolunteerEvidence(item)
            evidence.removeAll { $0.id == item.id }
        } catch {
            localError = "無法移除文件，請稍後再試。"
        }
    }

    private func hydrate(from draft: VolunteerApplicationInput?) {
        guard let draft else { return }
        confirmsAge = draft.confirmsAge18OrOlder
        acceptedConduct = !draft.acceptedConductVersion.isEmpty
        motivation = draft.motivation
        evidence = draft.evidence
    }

    private func formattedSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private var totalEvidenceBytes: Int {
        evidence.reduce(0) { $0 + max(0, $1.sizeBytes) }
    }

    private var canAddEvidence: Bool {
        canEditApplication && evidence.count < 5 && totalEvidenceBytes < 25 * 1024 * 1024
    }

    private var evidenceCapacityExceeded: Bool {
        evidence.count >= 5 || totalEvidenceBytes >= 25 * 1024 * 1024
    }

    private var canEditApplication: Bool {
        appState.volunteerApplicationReviewState?.isEditable ?? true
    }

    private var headerTitle: String {
        switch appState.volunteerApplicationReviewState?.status {
        case .pendingReview:
            return "申請正在審核"
        case .needsMoreInformation:
            return "補齊資料後重新送審"
        case .rejected:
            return "查看結果並修改申請"
        case .approved:
            return "志工資格已通過"
        default:
            return "上傳證明並送出審核"
        }
    }

    private var headerDetail: String {
        canEditApplication
            ? "至少加入一份資格證明後即可送出；審核通過前，你不會看到任何學生或求助資料。"
            : "你可以在這裡查看申請狀態與管理員說明。審核期間資料會保持唯讀。"
    }

    private var submitButtonTitle: String {
        switch appState.volunteerApplicationReviewState?.status {
        case .needsMoreInformation:
            return "完成補件並重新送審"
        case .rejected:
            return "修改後重新送審"
        default:
            return "送出審核"
        }
    }
}

private extension VolunteerQualificationKind {
    var title: String {
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

private extension VolunteerApplicationStatus {
    var applicantTitle: String {
        switch self {
        case .draft, .submitted:
            return "尚未送出"
        case .pendingReview:
            return "等待管理員審核"
        case .needsMoreInformation:
            return "需要補件"
        case .approved:
            return "申請已通過"
        case .rejected:
            return "申請未通過"
        case .withdrawn:
            return "申請已撤回"
        case .suspended:
            return "志工資格已停用"
        }
    }

    var applicantDetail: String {
        switch self {
        case .draft, .submitted:
            return "完成申請資料並加入證明文件後即可送審。"
        case .pendingReview:
            return "資料已安全送出。審核完成前不需要重複上傳；之後登入即可查看結果。"
        case .needsMoreInformation:
            return "請依下方管理員說明補上或更換文件，再重新送出。"
        case .approved:
            return "帳號已開通。加入服務班級並經老師核准後，才會看到該班學生主動送出的求助。"
        case .rejected:
            return "請先閱讀管理員說明。若資料可以修正，可修改後重新送審。"
        case .withdrawn:
            return "這份申請目前沒有進行審核。"
        case .suspended:
            return "志工功能已暫停；如需了解原因，請依管理員說明聯絡平台。"
        }
    }

    var applicantIcon: String {
        switch self {
        case .pendingReview:
            return "clock.badge.checkmark"
        case .needsMoreInformation:
            return "doc.badge.plus"
        case .approved:
            return "checkmark.seal.fill"
        case .rejected, .suspended:
            return "exclamationmark.triangle.fill"
        default:
            return "doc.text"
        }
    }

    var applicantColor: Color {
        switch self {
        case .approved:
            return EPTheme.support
        case .needsMoreInformation, .pendingReview:
            return EPTheme.warning
        case .rejected, .suspended:
            return EPTheme.danger
        default:
            return EPTheme.primary
        }
    }
}
