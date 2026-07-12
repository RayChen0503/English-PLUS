import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

enum FederatedSignInCoordinatorError: LocalizedError {
    case configurationMissing
    case presentationUnavailable
    case cancelled
    case invalidCredential
    case nonceGenerationFailed

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "這個登入方式尚未完成設定，請先改用其他方式。"
        case .presentationUnavailable:
            return "目前無法開啟登入頁面，請稍後再試。"
        case .cancelled:
            return "已取消登入。"
        case .invalidCredential:
            return "登入資料不完整，請重新嘗試。"
        case .nonceGenerationFailed:
            return "無法建立安全登入請求，請稍後再試。"
        }
    }
}

@MainActor
enum FederatedSignInCoordinator {
    static func googleCredential() async throws -> FederatedIdentityCredential {
        #if canImport(GoogleSignIn) && canImport(FirebaseCore)
        guard let clientID = FirebaseApp.app()?.options.clientID, !clientID.isEmpty else {
            throw FederatedSignInCoordinatorError.configurationMissing
        }
        guard let presenter = presentingViewController() else {
            throw FederatedSignInCoordinatorError.presentationUnavailable
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                throw FederatedSignInCoordinatorError.invalidCredential
            }
            return .google(
                idToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn", nsError.code == -5 {
                throw FederatedSignInCoordinatorError.cancelled
            }
            throw error
        }
        #else
        throw FederatedSignInCoordinatorError.configurationMissing
        #endif
    }

    static func prepareAppleRequest(
        _ request: ASAuthorizationAppleIDRequest
    ) throws -> String {
        let nonce = try randomNonceString()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        return nonce
    }

    static func appleCredential(
        from result: Result<ASAuthorization, Error>,
        rawNonce: String?
    ) throws -> FederatedIdentityCredential {
        switch result {
        case .failure(let error as ASAuthorizationError) where error.code == .canceled:
            throw FederatedSignInCoordinatorError.cancelled
        case .failure(let error):
            throw error
        case .success(let authorization):
            guard
                let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = appleCredential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let rawNonce,
                !rawNonce.isEmpty
            else {
                throw FederatedSignInCoordinatorError.invalidCredential
            }
            return .apple(idToken: idToken, rawNonce: rawNonce)
        }
    }

    static func handleOpenURL(_ url: URL) {
        #if canImport(GoogleSignIn)
        _ = GIDSignIn.sharedInstance.handle(url)
        #endif
    }

    private static func presentingViewController() -> UIViewController? {
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var controller = activeScene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonceString(length: Int = 32) throws -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            guard status == errSecSuccess else {
                throw FederatedSignInCoordinatorError.nonceGenerationFailed
            }
            for random in randomBytes where remainingLength > 0 {
                if Int(random) < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
}
