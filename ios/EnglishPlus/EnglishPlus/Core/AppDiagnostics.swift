import Foundation
import OSLog

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

enum AppDiagnosticCategory: String {
    case authentication
    case consent
    case classroom
    case roster
    case volunteerService
    case volunteerReview
    case supportMutation
    case assignmentMutation
    case accountLifecycle
    case aiProxy

    fileprivate var code: Int {
        switch self {
        case .authentication: return 1001
        case .consent: return 1002
        case .classroom: return 2001
        case .roster: return 2002
        case .volunteerService: return 3001
        case .volunteerReview: return 3002
        case .supportMutation: return 4001
        case .assignmentMutation: return 4002
        case .accountLifecycle: return 5001
        case .aiProxy: return 6001
        }
    }

    fileprivate var summary: String {
        switch self {
        case .authentication: return "Authentication operation failed"
        case .consent: return "Consent operation failed"
        case .classroom: return "Classroom operation failed"
        case .roster: return "Classroom roster operation failed"
        case .volunteerService: return "Volunteer service operation failed"
        case .volunteerReview: return "Volunteer review operation failed"
        case .supportMutation: return "Support operation failed"
        case .assignmentMutation: return "Assignment operation failed"
        case .accountLifecycle: return "Account lifecycle operation failed"
        case .aiProxy: return "AI proxy operation failed"
        }
    }
}

@MainActor
final class AppDiagnostics {
    static let shared = AppDiagnostics()
    static let collectionPreferenceKey = "englishplus.stabilityDiagnosticsEnabled"

    private let defaults: UserDefaults
    private let logger: Logger
    private var isConfigured = false

    var isCollectionEnabled: Bool {
        defaults.bool(forKey: Self.collectionPreferenceKey)
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.englishplus",
            category: "stability"
        )
    }

    func configure() {
        guard !isConfigured else { return }
        isConfigured = true
        applyCollectionPreference()
        log(.applicationStarted)
    }

    func setCollectionEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: Self.collectionPreferenceKey)
        applyCollectionPreference()
    }

    func updateContext(route: AppRoute, role: UserRole?) {
        let routeName: String
        switch route {
        case .roleSelection: routeName = "role_selection"
        case .demoLogin: routeName = "authentication"
        case .volunteerApplication: routeName = "volunteer_application"
        case .privacyConsent: routeName = "privacy_consent"
        case .home: routeName = "home"
        }

        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(routeName, forKey: "app_route")
        crashlytics.setCustomValue(role?.rawValue ?? "none", forKey: "app_role")
        #endif
    }

    func record(_ category: AppDiagnosticCategory, underlying error: Error? = nil) {
        let errorType = underlying.map { String(reflecting: type(of: $0)) } ?? "unknown"
        logger.error("Non-fatal category=\(category.rawValue, privacy: .public) type=\(errorType, privacy: .public)")

        #if canImport(FirebaseCrashlytics)
        guard isCollectionEnabled else { return }
        let report = NSError(
            domain: "com.englishplus.\(category.rawValue)",
            code: category.code,
            userInfo: [
                NSLocalizedDescriptionKey: category.summary,
                "error_type": errorType,
            ]
        )
        Crashlytics.crashlytics().record(error: report)
        #endif
    }

    func log(_ event: AppDiagnosticEvent) {
        logger.info("Event \(event.rawValue, privacy: .public)")
        #if canImport(FirebaseCrashlytics)
        guard isCollectionEnabled else { return }
        Crashlytics.crashlytics().log(event.rawValue)
        #endif
    }

    private func applyCollectionPreference() {
        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCrashlyticsCollectionEnabled(isCollectionEnabled)
        if !isCollectionEnabled {
            crashlytics.deleteUnsentReports()
        }
        #endif
    }
}

enum AppDiagnosticEvent: String {
    case applicationStarted = "application_started"
    case realtimeSyncConnected = "realtime_sync_connected"
    case realtimeSyncOffline = "realtime_sync_offline"
    case manualSyncRetry = "manual_sync_retry"
}
