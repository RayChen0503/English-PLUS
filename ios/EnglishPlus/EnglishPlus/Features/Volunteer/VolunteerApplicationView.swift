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
                    Button("稍後完成") { appState.signOut() }
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
            Text("第 2 步，共 2 步")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EPTheme.primary)
            Label("上傳證明並送出審核", systemImage: "person.badge.shield.checkmark")
                .font(.largeTitle.bold())
                .foregroundStyle(EPTheme.ink)
            Text("帳號已建立。至少加入一份資格證明後即可送出；審核通過前，你不會看到任何學生或求助資料。")
                .font(.body)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
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
                    .foregroundStyle(canAddEvidence ? EPTheme.secondaryInk : EPTheme.warning)
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

    private var submitButton: some View {
        Button("送出審核") {
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
        evidence.count < 5 && totalEvidenceBytes < 25 * 1024 * 1024
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
