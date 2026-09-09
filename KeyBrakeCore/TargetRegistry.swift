import Foundation

public enum TargetRegistry {
    public static let protectedIdentifiers: Set<String> = [
        "org.realitygood.KeyBrake",
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.SystemUIServer",
        "com.apple.WindowServer",
        "com.apple.loginwindow",
        "com.apple.launchd",
        "kernel_task"
    ]

    public static let builtInLocalAutomation: [TargetDefinition] = [
        TargetDefinition(id: "espanso", displayName: "Espanso", category: .localAutomation, bundleIdentifier: "org.espanso.Espanso", enabledForEmergencyStop: true, allowForcedTermination: true)
    ]

    public static let builtInRemoteAccess: [TargetDefinition] = [
        TargetDefinition(id: "anydesk", displayName: "AnyDesk", category: .remoteAccess, bundleIdentifier: "com.anydesk.AnyDesk", approvedByUser: false, allowForcedTermination: true),
        TargetDefinition(id: "teamviewer", displayName: "TeamViewer", category: .remoteAccess, bundleIdentifier: "com.teamviewer.TeamViewer", approvedByUser: false, allowForcedTermination: true),
        TargetDefinition(id: "chrome-remote-desktop", displayName: "Chrome Remote Desktop", category: .remoteAccess, bundleIdentifier: "com.google.Chrome.remote_desktop", approvedByUser: false, allowForcedTermination: true),
        TargetDefinition(id: "rustdesk", displayName: "RustDesk", category: .remoteAccess, bundleIdentifier: "com.carriez.RustDesk", approvedByUser: false, allowForcedTermination: true),
        TargetDefinition(id: "splashtop", displayName: "Splashtop", category: .remoteAccess, bundleIdentifier: "com.splashtop.SplashtopSOS", approvedByUser: false, allowForcedTermination: true),
        TargetDefinition(id: "parsec", displayName: "Parsec", category: .remoteAccess, bundleIdentifier: "tv.parsec.Parsec", approvedByUser: false, allowForcedTermination: true),
        TargetDefinition(id: "screenconnect", displayName: "ScreenConnect / ConnectWise Control", category: .remoteAccess, bundleIdentifier: "com.screenconnect.client", approvedByUser: false, allowForcedTermination: true)
    ]

    public static func canEnroll(_ definition: TargetDefinition, applicationBundleIdentifier: String?, executableURL: URL?) -> Bool {
        if protectedIdentifiers.contains(definition.id) { return false }
        if let applicationBundleIdentifier, protectedIdentifiers.contains(applicationBundleIdentifier) { return false }
        if let executableURL, executableURL.path.contains("/System/Library/") || executableURL.path == "/sbin/launchd" { return false }
        return definition.category == .localAutomation || definition.category == .remoteAccess
    }
}
