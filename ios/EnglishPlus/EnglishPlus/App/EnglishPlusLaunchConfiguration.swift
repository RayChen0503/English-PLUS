import Foundation

enum EnglishPlusLaunchConfiguration {
    private enum Argument {
        static let uiTesting = "-EnglishPlusUITesting"
        static let resetState = "-EnglishPlusResetState"
        static let startOffline = "-EnglishPlusStartOffline"
    }

    #if DEBUG
    private static var arguments: [String] {
        ProcessInfo.processInfo.arguments
    }

    static var isUITesting: Bool {
        arguments.contains(Argument.uiTesting)
    }

    static var shouldStartOffline: Bool {
        isUITesting && arguments.contains(Argument.startOffline)
    }

    static func prepareProcessIfNeeded() {
        guard isUITesting, arguments.contains(Argument.resetState) else { return }
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
    }
    #else
    static let isUITesting = false
    static let shouldStartOffline = false

    static func prepareProcessIfNeeded() {}
    #endif
}
