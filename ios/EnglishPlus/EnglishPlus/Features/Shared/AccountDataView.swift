import AuthenticationServices
import SwiftUI

struct AccountDataView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    @State private var preview: AccountDeletionPreview?
    @State private var selectedClassSuccessors: [String: String] = [:]
    @State private var confirmationText = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showsDeletionDetails = false
    @State private var showsFinalConfirmation = false
    @State private var appleDeletionNonce: String?
    @State private var hasRevokedAppleAuthorization = false
    @State private var hasRevokedGoogleAuthorization = false
    @FocusState private var isConfirmationFieldFocused: Bool

    private var hasCompleteClassTransferSelections: Bool {
        guard let preview else { return false }
        return preview.ownedClasses.allSatisfy { classroom in
            !classroom.requiresTransferSelection
                || selectedClassSuccessors[classroom.classId] != nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        accountSummary
                        privacyAndSupportSection
                        aiTransparencySection
                        stabilityDiagnosticsSection
                        deletionEntry

                        if showsDeletionDetails && isLoading {
                            ProgressView("正在確認帳號資料...")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 24)
                        } else if showsDeletionDetails, let preview {
                            deletionImpact(preview)
                            confirmationSection
                        }

                        if let errorMessage {
                            accountErrorCard(errorMessage)
                        }
                    }
                    .padding(EPTheme.pagePadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("帳號、隱私與支援")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .disabled(appState.isManagingAccount)
                }
            }
            .alert("永久刪除這個帳號？", isPresented: $showsFinalConfirmation) {
                Button("取消", role: .cancel) {}
                Button("永久刪除", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("刪除後無法復原。系統會先清除可識別你的資料，完成後才會刪除登入帳號。")
            }
            .interactiveDismissDisabled(appState.isManagingAccount)
        }
    }

    private var privacyAndSupportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("隱私與支援", systemImage: "lock.shield")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text("你可以隨時重新查看資料用途、聯絡方式，以及如何查詢、更正或刪除資料。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            PrivacySupportLinks(role: appState.currentUser?.role)

            Text("政策生效日：\(LegalSupportConfiguration.policyEffectiveDate)")
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var aiTransparencySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("AI 如何協助", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text("English+ 只把完成當次功能所需的最少學習內容，經 Cloudflare 後端交給 Groq AI，產生任務、錯題說明或可編輯草稿。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Label("不傳送姓名、Email 或志工資格證明", systemImage: "person.crop.circle.badge.checkmark")
            Label("AI 可能出錯，採用前仍要自行確認", systemImage: "checkmark.bubble")
            Label("心情分數不會自動通知老師或志工", systemImage: "bell.slash")
        }
        .font(.caption)
        .foregroundStyle(EPTheme.secondaryInk)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var stabilityDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(
                isOn: Binding(
                    get: { AppDiagnostics.shared.isCollectionEnabled },
                    set: { AppDiagnostics.shared.setCollectionEnabled($0) }
                )
            ) {
                Label("分享當機與穩定性診斷", systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .foregroundStyle(EPTheme.ink)
            }
            .tint(EPTheme.support)

            Text("開啟後會傳送 App 版本、角色類型、所在流程與錯誤類別，協助修復閃退與同步失敗。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Label("不傳送姓名、Email、題目內容、心情分數或班級名稱", systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        .accessibilityIdentifier("account.stability-diagnostics")
    }

    private var deletionEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            deletionExplanation

            if !showsDeletionDetails {
                Button {
                    showsDeletionDetails = true
                    Task { await loadPreview() }
                } label: {
                    Label("查看刪除內容", systemImage: "chevron.down")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            } else {
                Button {
                    showsDeletionDetails = false
                    confirmationText = ""
                    errorMessage = nil
                    appleDeletionNonce = nil
                    hasRevokedAppleAuthorization = false
                    hasRevokedGoogleAuthorization = false
                } label: {
                    Label("收起刪除內容", systemImage: "chevron.up")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(appState.isManagingAccount)
            }
        }
    }

    private var accountSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("目前帳號", systemImage: "person.crop.circle")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text(appState.currentUser?.displayName ?? "English+ 使用者")
                .font(.title3.bold())
                .foregroundStyle(EPTheme.ink)

            Text(appState.currentUser?.role.title ?? "使用者")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var deletionExplanation: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("刪除帳號", systemImage: "trash")
                .font(.headline)
                .foregroundStyle(EPTheme.warning)

            Text("這會刪除個人檔案、學習紀錄、心情檢測、求助內容、回覆身分與上傳證明。系統只會保留無法回推到個人的整體統計數字。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("為避免他人誤刪，正式刪除前可能會要求你先登出再重新登入。")
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.warning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private func deletionImpact(_ preview: AccountDeletionPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(preview.ownedClasses) { classroom in
                ownedClassDisposition(classroom)
            }

            Text("這次會影響")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            AccountDeletionImpactRow(
                title: "個人與學習資料",
                detail: "清除所有可識別你的紀錄",
                systemImage: "person.text.rectangle"
            )

            if preview.classMembershipCount > 0 {
                AccountDeletionImpactRow(
                    title: "班級關係",
                    detail: "離開 \(preview.classMembershipCount) 個班級並停止後續存取",
                    systemImage: "person.3"
                )
            }

            if preview.ownedClassCount > 0 {
                AccountDeletionImpactRow(
                    title: "你建立的班級",
                    detail: "封存 \(preview.ownedClassCount) 個班級，未完成任務停止派送",
                    systemImage: "archivebox"
                )
            }

            AccountDeletionImpactRow(
                title: "匿名統計",
                detail: "只保留總刪除次數等無法辨識個人的數字",
                systemImage: "chart.bar"
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    @ViewBuilder
    private func ownedClassDisposition(
        _ classroom: AccountDeletionOwnedClass
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(classroom.className, systemImage: "building.2")
                .font(.subheadline.bold())
                .foregroundStyle(EPTheme.ink)

            if classroom.eligibleCoTeachers.isEmpty {
                Label(
                    "沒有其他可接手的老師；刪除帳號後，這個班級會封存並保留歷史紀錄。",
                    systemImage: "archivebox"
                )
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
            } else {
                Picker(
                    "接手老師",
                    selection: Binding(
                        get: {
                            selectedClassSuccessors[classroom.classId]
                                ?? classroom.eligibleCoTeachers[0].uid
                        },
                        set: { selectedClassSuccessors[classroom.classId] = $0 }
                    )
                ) {
                    ForEach(classroom.eligibleCoTeachers) { teacher in
                        Text(teacher.displayName).tag(teacher.uid)
                    }
                }
                .pickerStyle(.menu)

                Label(
                    "刪除帳號前會把班級管理權移交；學生、任務與歷史紀錄會保留。",
                    systemImage: "arrow.trianglehead.branch"
                )
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
            }
        }
        .padding(12)
        .background(EPTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var confirmationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("確認永久刪除")
                .font(.headline)
                .foregroundStyle(EPTheme.ink)

            Text("請輸入「刪除」後再繼續。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)

            TextField("刪除", text: $confirmationText)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isConfirmationFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    isConfirmationFieldFocused = false
                }

            if appState.currentAccountUsesAppleSignIn {
                appleDeletionConfirmation
            }

            if appState.currentAccountUsesGoogleSignIn {
                googleDeletionConfirmation
            }

            Button(role: .destructive) {
                showsFinalConfirmation = true
            } label: {
                if appState.isManagingAccount {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("正在安全刪除...")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Label("永久刪除帳號", systemImage: "trash.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(EPTheme.warning)
            .disabled(
                confirmationText != "刪除"
                    || !hasCompleteClassTransferSelections
                    || (appState.currentAccountUsesAppleSignIn && !hasRevokedAppleAuthorization)
                    || (appState.currentAccountUsesGoogleSignIn && !hasRevokedGoogleAuthorization)
                    || appState.isManagingAccount
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    @ViewBuilder
    private var googleDeletionConfirmation: some View {
        if hasRevokedGoogleAuthorization {
            Label("Google 帳號已重新確認", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EPTheme.support)
                .accessibilityIdentifier("account.google-revocation-complete")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("這個帳號已連結 Google。刪除前需再確認一次，並撤銷 English+ 已取得的 Google 登入授權。")
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task { await completeGoogleDeletionAuthorization() }
                } label: {
                    if appState.isManagingAccount {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("正在確認 Google 帳號...")
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        Label("使用 Google 重新確認", systemImage: "person.badge.key.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(confirmationText != "刪除" || appState.isManagingAccount)
                .accessibilityIdentifier("account.google-revoke")
            }
        }
    }

    @ViewBuilder
    private var appleDeletionConfirmation: some View {
        if hasRevokedAppleAuthorization {
            Label("Apple 帳號已重新確認", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EPTheme.support)
                .accessibilityIdentifier("account.apple-revocation-complete")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("這個帳號已連結 Apple。依 Apple 規定，刪除前需再確認一次並撤銷 English+ 的登入授權。")
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                SignInWithAppleButton(
                    .continue,
                    onRequest: { request in
                        do {
                            appleDeletionNonce = try FederatedSignInCoordinator.prepareAppleRequest(request)
                            errorMessage = nil
                        } catch {
                            errorMessage = userMessage(for: error)
                        }
                    },
                    onCompletion: { result in
                        Task { await completeAppleDeletionAuthorization(result) }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(confirmationText != "刪除" || appState.isManagingAccount)
                .accessibilityIdentifier("account.apple-revoke")
            }
        }
    }

    private func accountErrorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("尚未完成", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(EPTheme.warning)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(EPTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    errorActions(message)
                }

                VStack(spacing: 10) {
                    errorActions(message)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.warning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    @ViewBuilder
    private func errorActions(_ message: String) -> some View {
        Button("重試") {
            Task {
                await loadPreview()
            }
        }
        .buttonStyle(SecondaryActionButtonStyle())
        .disabled(isLoading || appState.isManagingAccount)

        if message.contains("重新登入") || message.contains("登入已逾時") {
            Button("登出並重新登入") {
                appState.signOut()
                dismiss()
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(appState.isManagingAccount)
        }
    }

    @MainActor
    private func loadPreview() async {
        isLoading = true
        errorMessage = nil
        do {
            let loadedPreview = try await appState.loadAccountDeletionPreview()
            preview = loadedPreview
            selectedClassSuccessors = Dictionary(
                uniqueKeysWithValues: loadedPreview.ownedClasses.compactMap { classroom in
                    guard let first = classroom.eligibleCoTeachers.first else { return nil }
                    return (classroom.classId, first.uid)
                }
            )
        } catch {
            preview = nil
            errorMessage = userMessage(for: error)
            AppDiagnostics.shared.record(.accountLifecycle, underlying: error)
        }
        isLoading = false
    }

    @MainActor
    private func deleteAccount() async {
        guard confirmationText == "刪除",
              let uid = appState.currentUser?.id else { return }
        isConfirmationFieldFocused = false
        errorMessage = nil
        do {
            let receipt = try await appState.deleteCurrentAccount(
                classTransfers: selectedClassSuccessors
            )
            guard receipt.completed else {
                throw AccountLifecycleError.cleanupFailed
            }
            learningRepository.eraseLocalData(for: uid)
            appState.completeAccountDeletion()
            dismiss()
        } catch {
            errorMessage = userMessage(for: error)
            AppDiagnostics.shared.record(.accountLifecycle, underlying: error)
        }
    }

    @MainActor
    private func completeAppleDeletionAuthorization(
        _ result: Result<ASAuthorization, Error>
    ) async {
        errorMessage = nil
        do {
            let credential = try FederatedSignInCoordinator.appleAccountDeletionCredential(
                from: result,
                rawNonce: appleDeletionNonce
            )
            try await appState.reauthenticateAndRevokeAppleForAccountDeletion(
                using: credential
            )
            hasRevokedAppleAuthorization = true
            appleDeletionNonce = nil
        } catch FederatedSignInCoordinatorError.cancelled {
            appleDeletionNonce = nil
        } catch {
            appleDeletionNonce = nil
            errorMessage = userMessage(for: error)
            AppDiagnostics.shared.record(.accountLifecycle, underlying: error)
        }
    }

    @MainActor
    private func completeGoogleDeletionAuthorization() async {
        errorMessage = nil
        do {
            let credential = try await FederatedSignInCoordinator.googleAccountDeletionCredential()
            try await appState.reauthenticateAndRevokeGoogleForAccountDeletion(
                using: credential
            )
            hasRevokedGoogleAuthorization = true
        } catch FederatedSignInCoordinatorError.cancelled {
            return
        } catch {
            errorMessage = userMessage(for: error)
            AppDiagnostics.shared.record(.accountLifecycle, underlying: error)
        }
    }

    private func userMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription
            ?? "帳號刪除沒有完成，資料不會被誤標為已刪除。請稍後重試。"
    }
}

private struct AccountDeletionImpactRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(EPTheme.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(EPTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
