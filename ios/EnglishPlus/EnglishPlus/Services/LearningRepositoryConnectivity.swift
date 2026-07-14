import Foundation
import Network

enum NetworkConnectivityStatus: Equatable, Sendable {
    case unknown
    case connected
    case disconnected
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

private extension NSLock {
    func englishPlusWithLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
