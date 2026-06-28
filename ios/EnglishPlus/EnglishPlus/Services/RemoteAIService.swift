import Foundation

enum RemoteAIServiceError: Error {
    case missingAuthenticatedIdToken
    case workerEndpointNotConfigured
    case invalidFunctionResponse
    case functionReturnedStatus(Int)
    case taskTypeMismatch
    case timedOut

    var fallbackCode: String {
        switch self {
        case .missingAuthenticatedIdToken:
            return "AI_PROXY_MISSING_AUTH"
        case .workerEndpointNotConfigured:
            return "AI_PROXY_WORKER_NOT_CONFIGURED"
        case .invalidFunctionResponse:
            return "AI_PROXY_INVALID_RESPONSE"
        case .functionReturnedStatus(let status):
            return "AI_PROXY_HTTP_\(status)"
        case .taskTypeMismatch:
            return "AI_PROXY_TASK_MISMATCH"
        case .timedOut:
            return "AI_PROXY_TIMEOUT"
        }
    }
}

protocol AiProxyTransport {
    func call(_ request: AiProxyRequest, currentUser: DemoUser?) async throws -> AiProxyResponse
}

struct RemoteAIService: AIService {
    private let transport: AiProxyTransport
    private let fallbackService: AIService

    init(
        transport: AiProxyTransport = CloudflareWorkerAiProxyTransport(),
        fallbackService: AIService = MockAIService()
    ) {
        self.transport = transport
        self.fallbackService = fallbackService
    }

    func generateDailyMission(
        context: DailyMissionAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse {
        await callOrFallback(.dailyMission(context: context), currentUser: currentUser) {
            await fallbackService.generateDailyMission(context: context, currentUser: currentUser)
        }
    }

    func explainWrongAnswer(
        context: WrongAnswerAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse {
        await callOrFallback(.wrongAnswerExplanation(context: context), currentUser: currentUser) {
            await fallbackService.explainWrongAnswer(context: context, currentUser: currentUser)
        }
    }

    func provideEmotionalSupport(
        context: SupportAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse {
        await callOrFallback(.emotionalSupport(context: context), currentUser: currentUser) {
            await fallbackService.provideEmotionalSupport(context: context, currentUser: currentUser)
        }
    }

    func draftTeacherFeedback(
        context: SupportAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse {
        await callOrFallback(.teacherFeedbackDraft(context: context), currentUser: currentUser) {
            await fallbackService.draftTeacherFeedback(context: context, currentUser: currentUser)
        }
    }

    func coachVolunteerReply(
        context: SupportAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse {
        await callOrFallback(.volunteerReplyCoach(context: context), currentUser: currentUser) {
            await fallbackService.coachVolunteerReply(context: context, currentUser: currentUser)
        }
    }

    func recommendPractice(
        context: PracticeRecommendationAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse {
        await callOrFallback(.progressSummary(context: context), currentUser: currentUser) {
            await fallbackService.recommendPractice(context: context, currentUser: currentUser)
        }
    }

    private func callOrFallback(
        _ request: AiProxyRequest,
        currentUser: DemoUser?,
        fallback: () async -> AiProxyResponse
    ) async -> AiProxyResponse {
        do {
            return try await transport.call(request, currentUser: currentUser)
        } catch {
            var fallbackResponse = await fallback()
            fallbackResponse.ok = false
            fallbackResponse.fallbackUsed = true
            fallbackResponse.errorCode = fallbackCode(for: error)
            return fallbackResponse
        }
    }

    private func fallbackCode(for error: Error) -> String {
        if let remoteError = error as? RemoteAIServiceError {
            return remoteError.fallbackCode
        }
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return RemoteAIServiceError.timedOut.fallbackCode
        }
        return "AI_PROXY_UNAVAILABLE"
    }
}

enum EnglishPlusAIProxyConfig {
    static let infoPlistKey = "ENGLISHPLUS_AI_PROXY_URL"

    static var workerEndpoint: URL? {
        guard
            let rawValue = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String
        else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            trimmed.hasPrefix("https://"),
            !trimmed.contains("YOUR_WORKERS_SUBDOMAIN"),
            let url = URL(string: trimmed)
        else {
            return nil
        }
        return url
    }
}

struct CloudflareWorkerAiProxyTransport: AiProxyTransport {
    typealias IdTokenProvider = () async throws -> String?

    private let endpoint: URL?
    private let idTokenProvider: IdTokenProvider
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let timeoutInterval: TimeInterval

    init(
        endpoint: URL? = EnglishPlusAIProxyConfig.workerEndpoint,
        idTokenProvider: @escaping IdTokenProvider = { nil },
        session: URLSession = .shared,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        timeoutInterval: TimeInterval = 15
    ) {
        self.endpoint = endpoint
        self.idTokenProvider = idTokenProvider
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
        self.timeoutInterval = timeoutInterval
    }

    func call(_ request: AiProxyRequest, currentUser: DemoUser?) async throws -> AiProxyResponse {
        guard let endpoint else {
            throw RemoteAIServiceError.workerEndpointNotConfigured
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeoutInterval
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idToken = try await idTokenProvider(), !idToken.isEmpty {
            urlRequest.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try encoder.encode(CallableRequestEnvelope(data: request))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            if let urlError = error as? URLError, urlError.code == .timedOut {
                throw RemoteAIServiceError.timedOut
            }
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteAIServiceError.invalidFunctionResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw RemoteAIServiceError.functionReturnedStatus(httpResponse.statusCode)
        }

        let result: AiProxyResponse
        if
            let envelope = try? decoder.decode(CallableResponseEnvelope.self, from: data),
            let envelopeResult = envelope.result ?? envelope.data
        {
            result = envelopeResult
        } else if let directResult = try? decoder.decode(AiProxyResponse.self, from: data) {
            result = directResult
        } else {
            throw RemoteAIServiceError.invalidFunctionResponse
        }

        guard result.taskType == request.taskType else {
            throw RemoteAIServiceError.taskTypeMismatch
        }
        return result
    }
}

struct FirebaseCallableAiProxyTransport: AiProxyTransport {
    typealias IdTokenProvider = () async throws -> String?

    private let endpoint: URL
    private let idTokenProvider: IdTokenProvider
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let timeoutInterval: TimeInterval

    init(
        projectId: String = FirebaseBackendConfig.projectId,
        region: String = "asia-east1",
        callableName: String = "englishPlusAiProxy",
        idTokenProvider: @escaping IdTokenProvider = { nil },
        session: URLSession = .shared,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        timeoutInterval: TimeInterval = 15
    ) {
        endpoint = URL(string: "https://\(region)-\(projectId).cloudfunctions.net/\(callableName)")!
        self.idTokenProvider = idTokenProvider
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
        self.timeoutInterval = timeoutInterval
    }

    func call(_ request: AiProxyRequest, currentUser: DemoUser?) async throws -> AiProxyResponse {
        guard let idToken = try await idTokenProvider(), !idToken.isEmpty else {
            throw RemoteAIServiceError.missingAuthenticatedIdToken
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeoutInterval
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try encoder.encode(CallableRequestEnvelope(data: request))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            if let urlError = error as? URLError, urlError.code == .timedOut {
                throw RemoteAIServiceError.timedOut
            }
            throw error
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteAIServiceError.invalidFunctionResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw RemoteAIServiceError.functionReturnedStatus(httpResponse.statusCode)
        }

        let envelope: CallableResponseEnvelope
        do {
            envelope = try decoder.decode(CallableResponseEnvelope.self, from: data)
        } catch {
            throw RemoteAIServiceError.invalidFunctionResponse
        }
        guard let result = envelope.result ?? envelope.data else {
            throw RemoteAIServiceError.invalidFunctionResponse
        }
        guard result.taskType == request.taskType else {
            throw RemoteAIServiceError.taskTypeMismatch
        }
        return result
    }
}

private struct CallableRequestEnvelope: Encodable {
    let data: AiProxyRequest
}

private struct CallableResponseEnvelope: Decodable {
    let result: AiProxyResponse?
    let data: AiProxyResponse?
}
