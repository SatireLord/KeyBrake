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
            Self.preferredInstallationURLs(
                workspace.urlsForApplications(withBundleIdentifier: identifier),
                homeDirectory: FileManager.default.homeDirectoryForCurrentUser
            )
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

    private static func preferredInstallationURLs(_ applications: [URL], homeDirectory: URL) -> [URL] {
        let applicationDirectories = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            homeDirectory.appendingPathComponent("Applications", isDirectory: true)
        ]
        let preferredDirectoryPaths = Set(applicationDirectories.map {
            $0.standardizedFileURL.resolvingSymlinksInPath().standardizedFileURL.path
        })
        let installedApplications = applications.filter { application in
            let containingDirectory = application.deletingLastPathComponent()
                .standardizedFileURL.resolvingSymlinksInPath().standardizedFileURL.path
            return preferredDirectoryPaths.contains(containingDirectory)
        }
        return installedApplications.isEmpty ? applications : installedApplications
    }

    func openKeyboardSettings(completion: @escaping @MainActor (KeyBrakeSystemSettingsHandoff.Outcome) -> Void) {
        handoff.openKeyboardSettings(completion: completion)
    }
}
