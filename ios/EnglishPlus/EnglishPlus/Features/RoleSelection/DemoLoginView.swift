import SwiftUI
import UIKit

struct DemoLoginView: View {
    @EnvironmentObject private var appState: AppState
    let role: UserRole

    @State private var email: String
    @State private var password: String
    @State private var displayName = ""
    @State private var showsPassword = false
    @State private var mode: LoginMode = .signIn

    init(role: UserRole) {
        self.role = role
        _email = State(initialValue: "")
        _password = State(initialValue: "")
    }

    var body: some View {
        ZStack {
            EPTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Button {
                        appState.signOut()
                    } label: {
                        Label("返回選擇身分", systemImage: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(EPTheme.primary)

                    header

                    if role == .student {
                        modePicker
                    }

                    accountCard

                    if let message = appState.signInErrorMessage {
                        Text(message)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(EPTheme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let message = appState.authNoticeMessage {
                        Label(message, systemImage: "checkmark.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(EPTheme.support)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(EPTheme.support.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                    }

                    primaryButton
                }
                .padding(EPTheme.pagePadding)
            }
        }
        .onChange(of: mode) { _, newMode in
            applyDefaults(for: newMode)
        }
        .onChange(of: appState.verificationEmailAddress) { _, address in
            guard let address, !address.isEmpty else { return }
            mode = .signIn
            email = address
            password = ""
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(role.title)登入")
                .font(.largeTitle.bold())
                .foregroundStyle(EPTheme.ink)
            Text(role.shortPurpose)
                .font(.body)
                .foregroundStyle(EPTheme.secondaryInk)
        }
    }

    private var modePicker: some View {
        HStack(spacing: 10) {
            modeButton(.signIn)
            modeButton(.createStudent)
        }
    }

    private func modeButton(_ targetMode: LoginMode) -> some View {
        Button {
            mode = targetMode
        } label: {
            Text(targetMode.title)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(mode == targetMode ? .white : EPTheme.primary)
                .background(mode == targetMode ? EPTheme.primary : EPTheme.primary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(mode.cardTitle)
                .font(.headline)
                .foregroundStyle(EPTheme.ink)
            Text(mode.cardDescription(for: role))
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            if mode == .createStudent {
                formField(
                    title: "姓名或暱稱",
                    placeholder: "例如：小安",
                    text: $displayName,
                    keyboardType: .default
                )
            }

            formField(
                title: "帳號",
                placeholder: "email",
                text: $email,
                keyboardType: .emailAddress
            )

            passwordField

            if mode == .signIn {
                accountRecoveryActions
            }

            if role != .student {
                Label("老師與志工帳號由管理者核發。若尚未收到帳號，請聯絡單位管理者。", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(EPTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EPTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private func formField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(EPTheme.secondaryInk)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("密碼")
                .font(.caption.bold())
                .foregroundStyle(EPTheme.secondaryInk)
            HStack {
                if showsPassword {
                    TextField("輸入密碼", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("輸入密碼", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Button {
                    showsPassword.toggle()
                } label: {
                    Image(systemName: showsPassword ? "eye.slash" : "eye")
                        .foregroundStyle(EPTheme.secondaryInk)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(EPTheme.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var accountRecoveryActions: some View {
        HStack(spacing: 16) {
            Button("忘記密碼？") {
                Task {
                    await appState.sendPasswordReset(email: email)
                }
            }
            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isManagingAccount)

            if appState.verificationEmailAddress != nil {
                Button("重新寄送驗證信") {
                    Task {
                        await appState.resendVerification(email: email, password: password)
                    }
                }
                .disabled(password.isEmpty || appState.isManagingAccount)
            }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(EPTheme.primary)
        .buttonStyle(.plain)
    }

    private var primaryButton: some View {
        Button(primaryButtonTitle) {
            Task {
                switch mode {
                case .signIn:
                    await appState.signIn(email: email, password: password, role: role)
                case .createStudent:
                    await appState.createAccount(
                        email: email,
                        password: password,
                        displayName: displayName,
                        role: .student
                    )
                }
            }
        }
        .disabled(isPrimaryButtonDisabled)
        .buttonStyle(PrimaryActionButtonStyle())
        .opacity(isPrimaryButtonDisabled ? 0.45 : 1)
    }

    private var primaryButtonTitle: String {
        if appState.signingInRole == role {
            return mode == .createStudent ? "建立中..." : "登入中..."
        }
        return mode == .createStudent ? "建立學生帳號" : "登入 \(role.title)端"
    }

    private var isPrimaryButtonDisabled: Bool {
        if appState.signingInRole != nil || appState.isManagingAccount { return true }
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if password.isEmpty { return true }
        if mode == .createStudent {
            return displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.count < 8
        }
        return false
    }

    private func applyDefaults(for mode: LoginMode) {
        switch mode {
        case .signIn:
            password = ""
        case .createStudent:
            email = ""
            password = ""
            displayName = ""
        }
    }
}

private enum LoginMode: Equatable {
    case signIn
    case createStudent

    var title: String {
        switch self {
        case .signIn:
            return "登入"
        case .createStudent:
            return "建立帳號"
        }
    }

    var cardTitle: String {
        switch self {
        case .signIn:
            return "使用帳號登入"
        case .createStudent:
            return "建立學生帳號"
        }
    }

    func cardDescription(for role: UserRole) -> String {
        switch self {
        case .signIn:
            return "使用已建立的帳號登入。系統會確認帳號身分與使用權限。"
        case .createStudent:
            return "學生可以先建立個人帳號，不需要加入班級。完成信箱驗證後即可開始使用。"
        }
    }
}
