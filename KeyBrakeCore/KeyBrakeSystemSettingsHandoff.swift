import Foundation

@MainActor
public final class KeyBrakeSystemSettingsHandoff {
    public struct RunningApplication: Equatable, Sendable {
        public let bundleURL: URL?

        public init(bundleURL: URL?) {
            self.bundleURL = bundleURL
        }
    }

    public enum RouteOpenResult: Equatable, Sendable {
        case opened
        case failed(String)
    }

    public enum Failure: Equatable, Sendable {
        case missingHostBundleIdentifier
        case applicationNotRegistered
        case multipleRegisteredApplications(Int)
        case keyboardRouteNotRegistered
        case multipleRunningApplications(Int)
        case runningApplicationLocationUnavailable
        case differentApplicationIsRunning
        case duplicateInvocation
        case launchFailed(String)
    }

    public enum Outcome: Equatable, Sendable {
        case opened
        case failed(Failure)
    }

    public typealias RegisteredApplicationResolver = (String) -> [URL]
    public typealias RunningApplicationResolver = (String) -> [RunningApplication]
    public typealias KeyboardRouteSupportChecker = (URL) -> Bool
    public typealias RouteOpener = (
        _ routeURL: URL,
        _ applicationURL: URL,
        _ completion: @escaping @MainActor (RouteOpenResult) -> Void
    ) -> Void

    private let hostBundleIdentifier: String?
    private let registeredApplicationResolver: RegisteredApplicationResolver
    private let runningApplicationResolver: RunningApplicationResolver
    private let keyboardRouteSupportChecker: KeyboardRouteSupportChecker
    private let routeOpener: RouteOpener
    private var requestInFlight = false

    public init(
        hostBundleIdentifier: String?,
        registeredApplicationResolver: @escaping RegisteredApplicationResolver,
        runningApplicationResolver: @escaping RunningApplicationResolver,
        keyboardRouteSupportChecker: @escaping KeyboardRouteSupportChecker = { _ in true },
        routeOpener: @escaping RouteOpener
    ) {
        self.hostBundleIdentifier = hostBundleIdentifier
        self.registeredApplicationResolver = registeredApplicationResolver
        self.runningApplicationResolver = runningApplicationResolver
        self.keyboardRouteSupportChecker = keyboardRouteSupportChecker
        self.routeOpener = routeOpener
    }

    public func openKeyboardSettings(completion: @escaping @MainActor (Outcome) -> Void) {
        guard !requestInFlight else {
            completion(.failed(.duplicateInvocation))
            return
        }
        requestInFlight = true

        guard let bundleIdentifier = hostBundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bundleIdentifier.isEmpty else {
            finish(.failed(.missingHostBundleIdentifier), completion: completion)
            return
        }

        let registeredApplications = uniqueFileURLs(registeredApplicationResolver(bundleIdentifier))
        let runningApplications = runningApplicationResolver(bundleIdentifier)
        guard runningApplications.count <= 1 else {
            finish(.failed(.multipleRunningApplications(runningApplications.count)), completion: completion)
            return
        }

        let applicationURL: URL
        if let runningApplication = runningApplications.first {
            guard let runningURL = runningApplication.bundleURL, runningURL.isFileURL else {
                finish(.failed(.runningApplicationLocationUnavailable), completion: completion)
                return
            }
            guard registeredApplications.isEmpty || registeredApplications.contains(where: {
                Self.identityPath(for: $0) == Self.identityPath(for: runningURL)
            }) else {
                finish(.failed(.differentApplicationIsRunning), completion: completion)
                return
            }
            applicationURL = runningURL
        } else {
            guard !registeredApplications.isEmpty else {
                finish(.failed(.applicationNotRegistered), completion: completion)
                return
            }
            guard registeredApplications.count == 1 else {
                finish(.failed(.multipleRegisteredApplications(registeredApplications.count)), completion: completion)
                return
            }
            applicationURL = registeredApplications[0]
        }

        guard keyboardRouteSupportChecker(applicationURL) else {
            finish(.failed(.keyboardRouteNotRegistered), completion: completion)
            return
        }

        routeOpener(KeyBrakeSystemSettingsRoute.canonicalKeyboardURL, applicationURL) { [weak self] result in
            guard let self else { return }
            switch result {
            case .opened:
                self.finish(.opened, completion: completion)
            case let .failed(reason):
                self.finish(.failed(.launchFailed(reason)), completion: completion)
            }
        }
    }

    private func finish(_ outcome: Outcome, completion: @MainActor (Outcome) -> Void) {
        requestInFlight = false
        completion(outcome)
    }

    private func uniqueFileURLs(_ urls: [URL]) -> [URL] {
        var seenPaths = Set<String>()
        return urls.filter(\.isFileURL).filter { url in
            seenPaths.insert(Self.identityPath(for: url)).inserted
        }
    }

    private static func identityPath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
