import SwiftUI

struct DemoLoginView: View {
    @EnvironmentObject private var appState: AppState
    let role: UserRole

    @State private var email: String
    @State private var password: String
    @State private var showsPassword = false

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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(role.title)登入")
                            .font(.largeTitle.bold())
                            .foregroundStyle(EPTheme.ink)
                        Text(role.shortPurpose)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("使用帳號登入")
                            .font(.headline)
                            .foregroundStyle(EPTheme.ink)
                        Text("請使用測試帳號登入。系統會檢查帳號、密碼、角色與班級資料；未通過就不會進入 App。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("帳號")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            TextField("email", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("密碼")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
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
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))

                    if let message = appState.signInErrorMessage {
                        Text(message)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(appState.signingInRole == role ? "登入中..." : "登入 \(role.title)端") {
                        Task {
                            await appState.signIn(email: email, password: password, role: role)
                        }
                    }
                    .disabled(appState.signingInRole != nil || email.isEmpty || password.isEmpty)
                    .buttonStyle(PrimaryActionButtonStyle())
                    .opacity(appState.signingInRole != nil || email.isEmpty || password.isEmpty ? 0.45 : 1)
                }
                .padding(EPTheme.pagePadding)
            }
        }
    }
}
