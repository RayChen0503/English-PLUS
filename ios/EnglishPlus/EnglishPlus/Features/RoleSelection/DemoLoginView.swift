import AuthenticationServices
import SwiftUI
import UIKit

#if canImport(GoogleSignInSwift)
import GoogleSignInSwift
#endif

struct DemoLoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    let role: UserRole

    @State private var mode: LoginMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showsPassword = false
    @State private var selectedInstitution: EducationInstitution?
    @State private var volunteerIsAdult = false
    @State private var volunteerAcceptedConduct = false
    @State private var volunteerMotivation = ""
    @State private var appleRawNonce: String?

    var body: some View {
        ZStack {
            EPTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    backButton
                    header
                    if let provider = federatedOnboardingProvider {
                        federatedSetupBanner(provider)
                    } else {
                        modePicker
                        if appState.canUseFederatedSignIn {
                            federatedButtons
                            divider
                        }
                    }

                    emailAccountForm
                    feedback
                    primaryButton
                }
                .padding(EPTheme.pagePadding)
                .padding(.bottom, 24)
            }
        }
        .onChange(of: mode) { _, _ in
            password = ""
            appState.clearAuthFeedback()
        }
        .onChange(of: appState.verificationEmailAddress) { _, address in
            guard let address, !address.isEmpty else { return }
            mode = .signIn
            email = address
            password = ""
        }
    }

    private var backButton: some View {
        Button {
            appState.signOut()
        } label: {
            Label("選擇其他身分", systemImage: "chevron.left")
        }
        .buttonStyle(.plain)
        .foregroundStyle(EPTheme.primary)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(role.title)
                .font(.largeTitle.bold())
                .foregroundStyle(EPTheme.ink)
            Text(headerDescription)
                .font(.body)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modePicker: some View {
        Picker("帳號模式", selection: $mode) {
            Text("登入").tag(LoginMode.signIn)
            Text("建立帳號").tag(LoginMode.register)
        }
        .pickerStyle(.segmented)
    }

    private func federatedSetupBanner(_ provider: AccountIdentityProvider) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("\(provider.displayName) 驗證完成", systemImage: "checkmark.shield.fill")
                .font(.headline)
                .foregroundStyle(EPTheme.support)
            Text("這是你第一次使用 English+。補完下方的\(role.title)資料後，系統會建立同一個帳號，不需要另外設定 Email 密碼。")
                .font(.subheadline)
                .foregroundStyle(EPTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Button("改用其他登入方式") {
                appState.cancelFederatedOnboarding()
                mode = .signIn
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(EPTheme.primary)
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(EPTheme.support.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: EPTheme.cardRadius)
                .stroke(EPTheme.support.opacity(0.28), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    private var federatedButtons: some View {
        VStack(spacing: 12) {
            #if canImport(GoogleSignInSwift)
            GoogleSignInButton(
                scheme: colorScheme == .dark ? .dark : .light,
                style: .wide,
                state: federatedActionDisabled ? .disabled : .normal
            ) {
                Task { await continueWithGoogle() }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            #else
            Button {
                Task { await continueWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                    Text("使用 Google 繼續")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(EPTheme.ink)
                .background(EPTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: EPTheme.cardRadius)
                        .stroke(EPTheme.hairline, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
            }
            .buttonStyle(.plain)
            .disabled(federatedActionDisabled)
            #endif

            SignInWithAppleButton(
                .continue,
                onRequest: prepareAppleRequest,
                onCompletion: completeAppleSignIn
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
            .disabled(federatedActionDisabled)
        }
        .opacity(federatedActionDisabled ? 0.48 : 1)
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(EPTheme.hairline).frame(height: 1)
            Text(mode == .signIn ? "或使用 Email 登入" : "或使用 Email 建立帳號")
                .font(.caption)
                .foregroundStyle(EPTheme.secondaryInk)
            Rectangle().fill(EPTheme.hairline).frame(height: 1)
        }
    }

    private var emailAccountForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            if federatedOnboardingProvider != nil {
                registrationFields
            } else {
                if mode == .register {
                    registrationFields
                }

                formField(
                    title: "Email",
                    placeholder: "name@example.com",
                    text: $email,
                    keyboardType: .emailAddress,
                    accessibilityIdentifier: "auth.email"
                )
                passwordField

                if mode == .signIn {
                    recoveryActions
                }
            }
        }
        .padding(16)
        .background(EPTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: EPTheme.cardRadius)
                .stroke(EPTheme.hairline.opacity(0.7), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
    }

    @ViewBuilder
    private var registrationFields: some View {
        formField(
            title: "顯示名稱",
            placeholder: role == .student ? "同學怎麼稱呼你" : "你的姓名",
            text: $displayName,
            keyboardType: .default
        )

        switch role {
        case .student:
            Label("不加入班級也能使用完整的個人學習功能。", systemImage: "person.crop.circle")
                .registrationHintStyle()
        case .teacher:
            InstitutionPickerView(selection: $selectedInstitution)
            Label("任職資訊用於班級顯示與管理，不是教師資格審核。教師帳號建立後可直接使用；學生主動加入班級後，你才能看到加入後的資料。", systemImage: "lock.shield")
                .registrationHintStyle()
        case .volunteer:
            Label("第 1 步，共 2 步：建立帳號與基本資料", systemImage: "1.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EPTheme.primary)
            Toggle("我已年滿 18 歲", isOn: $volunteerIsAdult)
            Toggle("我同意志工守則與資料保密規範", isOn: $volunteerAcceptedConduct)
            VStack(alignment: .leading, spacing: 8) {
                Text("申請動機")
                    .font(.caption.bold())
                    .foregroundStyle(EPTheme.secondaryInk)
                TextField("簡短說明你想協助學生的原因", text: $volunteerMotivation, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(EPTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
            }
            Label("第 2 步會自動進入證明上傳，可加入學籍、英語能力、教育或志工服務證明。審核通過前不會開放學生資料。", systemImage: "doc.badge.arrow.up")
                .registrationHintStyle()
        }
    }

    private func formField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        accessibilityIdentifier: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(EPTheme.secondaryInk)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .padding(12)
                .background(EPTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
                .accessibilityIdentifier(accessibilityIdentifier ?? "")
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("密碼")
                .font(.caption.bold())
                .foregroundStyle(EPTheme.secondaryInk)
            HStack(spacing: 8) {
                Group {
                    if showsPassword {
                        TextField("至少 8 個字元", text: $password)
                    } else {
                        SecureField("至少 8 個字元", text: $password)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("auth.password")

                Button {
                    showsPassword.toggle()
                } label: {
                    Image(systemName: showsPassword ? "eye.slash" : "eye")
                        .frame(width: 44, height: 44)
                        .foregroundStyle(EPTheme.secondaryInk)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 12)
            .background(EPTheme.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: EPTheme.cardRadius))
        }
    }

    private var recoveryActions: some View {
        HStack(spacing: 16) {
            Button("忘記密碼") {
                Task { await appState.sendPasswordReset(email: email) }
            }
            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if appState.verificationEmailAddress != nil {
                Button("重寄驗證信") {
                    Task { await appState.resendVerification(email: email, password: password) }
                }
                .disabled(password.isEmpty)
            }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(EPTheme.primary)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var feedback: some View {
        if let message = appState.signInErrorMessage {
            Label(message, systemImage: "exclamationmark.circle.fill")
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
    }

    private var primaryButton: some View {
        Button(primaryButtonTitle) {
            Task {
                if federatedOnboardingProvider != nil {
                    guard let profile = registrationProfile else { return }
                    await appState.completeFederatedOnboarding(profile: profile)
                } else {
                    await submitEmailForm()
                }
            }
        }
        .disabled(primaryActionDisabled)
        .buttonStyle(PrimaryActionButtonStyle())
        .accessibilityIdentifier("auth.submit")
    }

    private var headerDescription: String {
        switch role {
        case .student:
            return "登入後繼續你的每日任務、自由練習與班級作業。"
        case .teacher:
            return "登入後建立班級、指派任務並回覆學生的學習求助。"
        case .volunteer:
            return "登入後接續已核准的陪伴任務；新志工需先完成申請。"
        }
    }

    private var registrationProfile: RoleOnboardingProfile? {
        let cleanedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return nil }

        switch role {
        case .student:
            return RoleOnboardingProfile(
                displayName: cleanedName,
                role: .student,
                teacherAffiliation: nil,
                volunteerApplication: nil
            )
        case .teacher:
            guard let institution = selectedInstitution else { return nil }
            return RoleOnboardingProfile(
                displayName: cleanedName,
                role: .teacher,
                teacherAffiliation: TeacherAffiliation(
                    institutionId: institution.id,
                    institutionName: institution.name,
                    institutionKind: institution.kind,
                    institutionSource: institution.source,
                    claimStatus: .selfDeclared
                ),
                volunteerApplication: nil
            )
        case .volunteer:
            let motivation = volunteerMotivation.trimmingCharacters(in: .whitespacesAndNewlines)
            guard volunteerIsAdult, volunteerAcceptedConduct, !motivation.isEmpty else { return nil }
            return RoleOnboardingProfile(
                displayName: cleanedName,
                role: .volunteer,
                teacherAffiliation: nil,
                volunteerApplication: VolunteerApplicationInput(
                    confirmsAge18OrOlder: true,
                    acceptedConductVersion: "volunteer-conduct-v1",
                    motivation: motivation,
                    evidence: []
                )
            )
        }
    }

    private var federatedActionDisabled: Bool {
        appState.signingInRole != nil
    }

    private var federatedOnboardingProvider: AccountIdentityProvider? {
        appState.federatedOnboardingProvider(for: role)
    }

    private var primaryActionDisabled: Bool {
        if federatedOnboardingProvider != nil {
            return appState.signingInRole != nil || registrationProfile == nil
        }
        return emailActionDisabled
    }

    private var emailActionDisabled: Bool {
        if appState.signingInRole != nil || appState.isManagingAccount { return true }
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty {
            return true
        }
        return mode == .register && (password.count < 8 || registrationProfile == nil)
    }

    private var primaryButtonTitle: String {
        if federatedOnboardingProvider != nil {
            return appState.signingInRole == role
                ? "建立中..."
                : "完成\(role.title)帳號設定"
        }
        if appState.signingInRole == role {
            return mode == .register ? "建立中..." : "登入中..."
        }
        return mode == .register ? "建立\(role.title)帳號" : "登入"
    }

    private func submitEmailForm() async {
        switch mode {
        case .signIn:
            await appState.signIn(email: email, password: password, role: role)
        case .register:
            guard let profile = registrationProfile else { return }
            await appState.createAccount(
                AccountRegistration(
                    email: email,
                    password: password,
                    displayName: profile.displayName,
                    role: profile.role,
                    teacherAffiliation: profile.teacherAffiliation,
                    volunteerApplication: profile.volunteerApplication
                )
            )
        }
    }

    private func continueWithGoogle() async {
        do {
            let credential = try await FederatedSignInCoordinator.googleCredential()
            await handleFederatedCredential(credential)
        } catch FederatedSignInCoordinatorError.cancelled {
            return
        } catch {
            appState.presentAuthenticationError(error)
        }
    }

    private func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            appleRawNonce = try FederatedSignInCoordinator.prepareAppleRequest(request)
        } catch {
            appleRawNonce = nil
            appState.presentAuthenticationError(error)
        }
    }

    private func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        do {
            let credential = try FederatedSignInCoordinator.appleCredential(
                from: result,
                rawNonce: appleRawNonce
            )
            appleRawNonce = nil
            Task { await handleFederatedCredential(credential) }
        } catch FederatedSignInCoordinatorError.cancelled {
            appleRawNonce = nil
        } catch {
            appleRawNonce = nil
            appState.presentAuthenticationError(error)
        }
    }

    private func handleFederatedCredential(_ credential: FederatedIdentityCredential) async {
        await appState.signIn(with: credential, role: role)
    }
}

private enum LoginMode: Hashable {
    case signIn
    case register
}

private extension View {
    func registrationHintStyle() -> some View {
        font(.footnote)
            .foregroundStyle(EPTheme.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}
