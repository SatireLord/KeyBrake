import Foundation

public struct FeatureContract: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let productDescription: String
    public let requiredMenuActions: [String]
    public let requiredOperationalStates: [String]
    public let protectedTargets: [String]
    public let recoveryRules: [String]
    public let forbiddenClaims: [String]
    public let approvedThreatTerms: [String]

    public static let fallback = FeatureContract(
        schemaVersion: 1,
        productDescription: "KeyBrake is a macOS menu-bar input and remote-access failsafe. It gives users a keyboard-independent recovery path for runaway keystroke automation, pauses approved local injectors, and performs reversible network isolation during suspicious or fraudulent remote-support sessions.",
        requiredMenuActions: ["Stop Skynet Locally", "Stop Remote Access", "Revoke App Access…", "Restore Human Control", "Restart Espanso", "Open Incident Log", "Open Command Center", "Settings…", "Quit KeyBrake"],
        requiredOperationalStates: KeyBrakeOperationalState.allCases.map(\.rawValue),
        protectedTargets: [
            "org.realitygood.KeyBrake",
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.SystemUIServer",
            "com.apple.WindowServer",
            "com.apple.loginwindow",
            "com.apple.launchd",
            "kernel_task"
        ],
        recoveryRules: [
            "restoreOnlyChangesMadeByKeyBrake",
            "neverAutomaticallyRestoreTCCGrants",
            "neverAutomaticallyRestartRemoteControlApps",
            "preserveMouseDrivenRecovery",
            "retainUnresolvedRecoverySnapshot",
            "neverReconnectVPNAutomatically"
        ],
        forbiddenClaims: ["Computer Secured", "Hacker Removed", "Threat Neutralized", "System Safe", "All Remote Access Eliminated"],
        approvedThreatTerms: ["runaway user-space input automation", "unauthorized input automation", "fraudulent remote-support sessions", "untrusted remote-control software", "unexpected remote access"]
    )

    public init(schemaVersion: Int, productDescription: String, requiredMenuActions: [String], requiredOperationalStates: [String], protectedTargets: [String], recoveryRules: [String], forbiddenClaims: [String], approvedThreatTerms: [String]) {
        self.schemaVersion = schemaVersion
        self.productDescription = productDescription
        self.requiredMenuActions = requiredMenuActions
        self.requiredOperationalStates = requiredOperationalStates
        self.protectedTargets = protectedTargets
        self.recoveryRules = recoveryRules
        self.forbiddenClaims = forbiddenClaims
        self.approvedThreatTerms = approvedThreatTerms
    }

    public static func load(from url: URL) throws -> FeatureContract {
        try JSONDecoder().decode(FeatureContract.self, from: Data(contentsOf: url))
    }

    public static func current(resourceURL: URL?) -> FeatureContract {
        guard let resourceURL, let loaded = try? load(from: resourceURL) else {
            return fallback
        }
        return loaded
    }

    public static func current(in bundle: Bundle = .main) -> FeatureContract {
        current(resourceURL: bundle.url(forResource: "KeyBrakeFeatureContract", withExtension: "json"))
    }
}
