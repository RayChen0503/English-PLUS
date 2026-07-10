import Foundation

struct RuntimeAIStatus: Equatable {
    let ok: Bool
    let fallbackUsed: Bool
    let taskType: String
    let provider: String
    let modelUsed: String
    let errorCode: String?
    let checkedAt: Date

    init(response: AiProxyResponse, checkedAt: Date = Date()) {
        ok = response.ok
        fallbackUsed = response.fallbackUsed
        taskType = response.taskType.rawValue
        provider = "groq"
        modelUsed = response.modelUsed ?? "unknown"
        errorCode = response.errorCode
        self.checkedAt = checkedAt
    }
}

struct RuntimeDiagnosticsSnapshot: Equatable {
    let backendMode: EnglishPlusBackendMode
    let hasFirebaseConfig: Bool
    let authProvider: String
    let firestoreProvider: String
    let learningProvider: String
    let aiProvider: String
    let aiProxyEndpoint: String?
    var signedInUserId: String?
    var signedInRole: UserRole?
    var signedInClassId: String?
    var lastAIStatus: RuntimeAIStatus?

    var isFirebaseRuntime: Bool {
        backendMode == .firebase && hasFirebaseConfig
    }

    var isRemoteAIRuntime: Bool {
        aiProvider == "RemoteAIService" && aiProxyEndpoint != nil
    }

    func withSession(user: DemoUser, profile: AppUserProfile) -> RuntimeDiagnosticsSnapshot {
        var copy = self
        copy.signedInUserId = user.id
        copy.signedInRole = user.role
        copy.signedInClassId = profile.activeClassId
        return copy
    }

    func clearingSession() -> RuntimeDiagnosticsSnapshot {
        var copy = self
        copy.signedInUserId = nil
        copy.signedInRole = nil
        copy.signedInClassId = nil
        copy.lastAIStatus = nil
        return copy
    }

    func recordingAIResponse(_ response: AiProxyResponse) -> RuntimeDiagnosticsSnapshot {
        var copy = self
        copy.lastAIStatus = RuntimeAIStatus(response: response)
        return copy
    }
}
