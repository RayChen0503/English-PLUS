import Foundation
import Network

enum NetworkConnectivityStatus: Equatable, Sendable {
    case unknown
    case connected
    case disconnected
}

struct LearningRepositorySyncContext {
    let classId: String
    let user: DemoUser?
    let profile: AppUserProfile?

    var scopeKey: String {
        [classId, profile?.id ?? user?.id ?? "anonymous", profile?.role.rawValue ?? user?.role.rawValue ?? "unknown"]
            .joined(separator: "|")
    }
}

struct LearningRepositorySyncFailureDisposition: Equatable {
    let message: String
    let shouldRetry: Bool
}

struct LearningRepositoryComponentIssueRegistry {
    enum Transition {
        case unchanged
        case issue(LearningRepositorySyncFailureDisposition)
        case healthy
    }

    private(set) var issues: [String: LearningRepositorySyncFailureDisposition] = [:]

    var isEmpty: Bool { issues.isEmpty }

    var presentation: LearningRepositorySyncFailureDisposition? {
        issues
            .sorted { lhs, rhs in
                if lhs.value.shouldRetry != rhs.value.shouldRetry {
                    return !lhs.value.shouldRetry
                }
                return lhs.key < rhs.key
            }
            .first?
            .value
    }

    mutating func recordFailure(source: String, error: Error) {
        issues[source] = LearningRepositorySyncFailureClassifier.classify(error)
    }

    @discardableResult
    mutating func recordRecovery(source: String) -> Bool {
        issues.removeValue(forKey: source) != nil
    }

    mutating func reset() {
        issues.removeAll(keepingCapacity: true)
    }

    mutating func apply(_ event: LearningRepositoryListenerHealthEvent) -> Transition {
        switch event {
        case .failed(let source, let error):
            recordFailure(source: source, error: error)
            return presentation.map(Transition.issue) ?? .healthy
        case .recovered(let source):
            guard recordRecovery(source: source) else { return .unchanged }
            return presentation.map(Transition.issue) ?? .healthy
        }
    }
}

enum LearningRepositorySyncFailureClassifier {
    private static let transientURLCodes: Set<Int> = [
        NSURLErrorTimedOut,
        NSURLErrorCannotFindHost,
        NSURLErrorCannotConnectToHost,
        NSURLErrorNetworkConnectionLost,
        NSURLErrorDNSLookupFailed,
        NSURLErrorNotConnectedToInternet
    ]

    static func classify(_ error: Error) -> LearningRepositorySyncFailureDisposition {
        let errors = errorChain(startingAt: error as NSError)

        if errors.contains(where: { nsError in
            nsError.domain == NSURLErrorDomain && transientURLCodes.contains(nsError.code)
        }) {
            return LearningRepositorySyncFailureDisposition(
                message: "同步連線暫時不穩定，已保留目前資料並會自動重試。",
                shouldRetry: true
            )
        }

        if let firestoreError = errors.first(where: isFirestoreError) {
            switch firestoreError.code {
            case 4, 10, 13, 14:
                return LearningRepositorySyncFailureDisposition(
                    message: "同步服務暫時忙碌，已保留目前資料並會自動重試。",
                    shouldRetry: true
                )
            case 16:
                return LearningRepositorySyncFailureDisposition(
                    message: "登入狀態已失效，請重新登入後同步資料。",
                    shouldRetry: false
                )
            case 7:
                return LearningRepositorySyncFailureDisposition(
                    message: "目前帳號沒有讀取這部分資料的權限，請確認班級或帳號身分。",
                    shouldRetry: false
                )
            case 8:
                return LearningRepositorySyncFailureDisposition(
                    message: "同步服務目前繁忙，請稍後再試。",
                    shouldRetry: false
                )
            case 3, 9, 12:
                return LearningRepositorySyncFailureDisposition(
                    message: "這部分資料暫時無法載入，其他已同步內容仍可使用。",
                    shouldRetry: false
                )
            default:
                break
            }
        }

        return LearningRepositorySyncFailureDisposition(
            message: "部分資料暫時無法同步，其他已載入內容仍可使用。",
            shouldRetry: false
        )
    }

    private static func isFirestoreError(_ error: NSError) -> Bool {
        let domain = error.domain.lowercased()
        return domain.contains("firestore") || domain.contains("grpc")
    }

    private static func errorChain(startingAt firstError: NSError) -> [NSError] {
        var result: [NSError] = []
        var current: NSError? = firstError
        var visited = Set<ObjectIdentifier>()

        while let error = current {
            let identifier = ObjectIdentifier(error)
            guard visited.insert(identifier).inserted else { break }
            result.append(error)
            current = error.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return result
    }
}

protocol NetworkConnectivityMonitoring: AnyObject {
    var currentStatus: NetworkConnectivityStatus { get }

    func start(
        onChange: @escaping @Sendable (NetworkConnectivityStatus) -> Void
    )
    func stop()
}

final class NetworkConnectivityMonitor: NetworkConnectivityMonitoring, @unchecked Sendable {
    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var status: NetworkConnectivityStatus = .unknown

    init(
        monitor: NWPathMonitor = NWPathMonitor(),
        queue: DispatchQueue = DispatchQueue(label: "com.englishplus.network-monitor")
    ) {
        self.monitor = monitor
        self.queue = queue
    }

    var currentStatus: NetworkConnectivityStatus {
        lock.englishPlusWithLock { status }
    }

    func start(
        onChange: @escaping @Sendable (NetworkConnectivityStatus) -> Void
    ) {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let nextStatus: NetworkConnectivityStatus = path.status == .satisfied
                ? .connected
                : .disconnected
            let didChange = lock.englishPlusWithLock {
                guard self.status != nextStatus else { return false }
                self.status = nextStatus
                return true
            }
            if didChange {
                onChange(nextStatus)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}

final class LaunchArgumentNetworkConnectivityMonitor: NetworkConnectivityMonitoring {
    let currentStatus: NetworkConnectivityStatus

    init(status: NetworkConnectivityStatus) {
        currentStatus = status
    }

    func start(
        onChange: @escaping @Sendable (NetworkConnectivityStatus) -> Void
    ) {
        onChange(currentStatus)
    }

    func stop() {}
}

private extension NSLock {
    func englishPlusWithLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
