import SwiftUI

struct AccountDataView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    @State private var preview: AccountDeletionPreview?
    @State private var confirmationText = ""
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var showsFinalConfirmation = false
    @FocusState private var isConfirmationFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                EPTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        accountSummary
                        deletionExplanation

                        if isLoading {
                            ProgressView("正在確認帳號資料...")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 24)
                        } else if let preview {
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
            .navigationTitle("帳號與資料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .disabled(appState.isManagingAccount)
                }
            }
            .task {
                await loadPreview()
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
            .disabled(confirmationText != "刪除" || appState.isManagingAccount)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
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
            preview = try await appState.loadAccountDeletionPreview()
        } catch {
            preview = nil
            errorMessage = userMessage(for: error)
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
            let receipt = try await appState.deleteCurrentAccount()
            guard receipt.completed else {
                throw AccountLifecycleError.cleanupFailed
            }
            learningRepository.eraseLocalData(for: uid)
            appState.completeAccountDeletion()
            dismiss()
        } catch {
            errorMessage = userMessage(for: error)
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
