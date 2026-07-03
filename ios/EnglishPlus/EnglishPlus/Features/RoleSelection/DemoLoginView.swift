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
        let credential = DemoAccountCredential.credential(for: role)
        _email = State(initialValue: credential.email)
        _password = State(initialValue: credential.password)
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

                    primaryButton
                }
                .padding(EPTheme.pagePadding)
            }
        }
        .onChange(of: mode) { _, newMode in
            applyDefaults(for: newMode)
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

            if role != .student {
                Label("老師與志工帳號目前由管理者或 Firebase 後台建立，避免學生誤建成工作端帳號。", systemImage: "lock.shield")
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
                    TextField("password", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("password", text: $password)
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
        if appState.signingInRole != nil { return true }
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if password.isEmpty { return true }
        if mode == .createStudent {
            return displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.count < 6
        }
        return false
    }

    private func applyDefaults(for mode: LoginMode) {
        switch mode {
        case .signIn:
            let credential = DemoAccountCredential.credential(for: role)
            email = credential.email
            password = credential.password
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
            return "請使用測試帳號或已建立的正式帳號登入。系統會檢查帳號、密碼、角色與班級資料；未通過就不會進入 App。"
        case .createStudent:
            return "測試階段可先建立學生帳號。建立後會進入資料使用確認；同一帳號確認過後，下次登入就不會重複跳出。"
        }
    }
}
