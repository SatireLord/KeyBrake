import AppKit
import Foundation

@MainActor
final class KeyBrakeAppLauncher {
    private static let hostBundleIdentifierInfoKey = "KeyBrakeHostBundleIdentifier"

    private let handoff: KeyBrakeSystemSettingsHandoff

    init(
        bundle: Bundle = Bundle(for: KeyBrakeSettingsPane.self),
        workspace: NSWorkspace = .shared,
        registeredApplicationResolver: KeyBrakeSystemSettingsHandoff.RegisteredApplicationResolver? = nil,
        runningApplicationResolver: KeyBrakeSystemSettingsHandoff.RunningApplicationResolver? = nil,
        routeOpener: KeyBrakeSystemSettingsHandoff.RouteOpener? = nil
    ) {
        let hostBundleIdentifier = bundle.object(forInfoDictionaryKey: Self.hostBundleIdentifierInfoKey) as? String
        let resolveRegisteredApplications = registeredApplicationResolver ?? { identifier in
            workspace.urlsForApplications(withBundleIdentifier: identifier)
        }
        let resolveRunningApplications = runningApplicationResolver ?? { identifier in
            workspace.runningApplications.compactMap { application in
                guard application.bundleIdentifier == identifier else { return nil }
                return KeyBrakeSystemSettingsHandoff.RunningApplication(bundleURL: application.bundleURL)
            }
        }
        let supportsKeyboardRoute: KeyBrakeSystemSettingsHandoff.KeyboardRouteSupportChecker = { applicationURL in
            guard let appBundle = Bundle(url: applicationURL),
                  let urlTypes = appBundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else { return false }
            return urlTypes.contains { urlType in
                (urlType["CFBundleURLSchemes"] as? [String])?.contains {
                    $0.caseInsensitiveCompare("keybrake") == .orderedSame
                } == true
            }
        }
        let openRoute = routeOpener ?? { routeURL, applicationURL, completion in
            workspace.open(
                [routeURL],
                withApplicationAt: applicationURL,
                configuration: NSWorkspace.OpenConfiguration()
            ) { application, error in
                let result: KeyBrakeSystemSettingsHandoff.RouteOpenResult
                if let error {
                    result = .failed(error.localizedDescription)
                } else if application != nil {
                    result = .opened
                } else {
                    result = .failed("Launch Services did not return a running KeyBrake application.")
                }
                Task { @MainActor in completion(result) }
            }
        }

        handoff = KeyBrakeSystemSettingsHandoff(
            hostBundleIdentifier: hostBundleIdentifier,
            registeredApplicationResolver: resolveRegisteredApplications,
            runningApplicationResolver: resolveRunningApplications,
            keyboardRouteSupportChecker: supportsKeyboardRoute,
            routeOpener: openRoute
        )
    }

    func openKeyboardSettings(completion: @escaping @MainActor (KeyBrakeSystemSettingsHandoff.Outcome) -> Void) {
        handoff.openKeyboardSettings(completion: completion)
    }
}
