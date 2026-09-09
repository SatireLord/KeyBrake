import Foundation

public enum TCCService: String, Codable, CaseIterable, Sendable {
    case all = "All"
    case accessibility = "Accessibility"
    case inputMonitoring = "ListenEvent"
    case postEvent = "PostEvent"
    case appleEvents = "AppleEvents"
    case developerTool = "DeveloperTool"
    case screenCapture = "ScreenCapture"
    case audioCapture = "AudioCapture"
    case remoteDesktop = "RemoteDesktop"
    case fullDiskAccess = "SystemPolicyAllFiles"
    case desktopFolder = "SystemPolicyDesktopFolder"
    case documentsFolder = "SystemPolicyDocumentsFolder"
    case downloadsFolder = "SystemPolicyDownloadsFolder"
    case networkVolumes = "SystemPolicyNetworkVolumes"
    case removableVolumes = "SystemPolicyRemovableVolumes"
    case appData = "SystemPolicyAppData"
    case appBundles = "SystemPolicyAppBundles"
    case systemAdministrationFiles = "SystemPolicySysAdminFiles"
    case fileProviderDomain = "FileProviderDomain"
    case fileProviderPresence = "FileProviderPresence"
    case camera = "Camera"
    case externalCameraMedia = "ExternalCameraMedia"
    case microphone = "Microphone"
    case bluetooth = "BluetoothAlways"
    case contacts = "AddressBook"
    case calendar = "Calendar"
    case reminders = "Reminders"
    case photos = "Photos"
    case photosAdd = "PhotosAdd"
    case mediaLibrary = "MediaLibrary"
    case speechRecognition = "SpeechRecognition"
    case homeKit = "HomeKit"
    case siri = "Siri"
    case motion = "Motion"
    case focusStatus = "FocusStatus"
    case energyKitGuidance = "EnergyKitGuidance"
    case gameCenterFriends = "GameCenterFriends"
    case userTracking = "UserTracking"
    case virtualMachineNetworking = "VirtualMachineNetworking"
    case voiceBanking = "VoiceBanking"
    case webBrowserPublicKeyCredential = "WebBrowserPublicKeyCredential"
}

public struct PrivacyServiceDescriptor: Sendable, Equatable, Identifiable {
    public let id: TCCService
    public let displayName: String
    public let category: String
    public let minimumMajorVersion: Int

    public init(id: TCCService, displayName: String, category: String, minimumMajorVersion: Int = 14) {
        self.id = id
        self.displayName = displayName
        self.category = category
        self.minimumMajorVersion = minimumMajorVersion
    }
}

public enum PrivacyServiceCatalog {
    public static let descriptors: [PrivacyServiceDescriptor] = [
        .init(id: .accessibility, displayName: "Accessibility", category: "Control and Input"),
        .init(id: .inputMonitoring, displayName: "Input Monitoring", category: "Control and Input"),
        .init(id: .postEvent, displayName: "Send Keystrokes / Input", category: "Control and Input"),
        .init(id: .appleEvents, displayName: "Automation / Apple Events", category: "Control and Input"),
        .init(id: .developerTool, displayName: "Developer Tools", category: "Control and Input"),
        .init(id: .screenCapture, displayName: "Screen Recording", category: "Control and Input"),
        .init(id: .audioCapture, displayName: "System Audio Recording", category: "Control and Input"),
        .init(id: .remoteDesktop, displayName: "Remote Desktop", category: "Control and Input"),
        .init(id: .fullDiskAccess, displayName: "Full Disk Access", category: "Files and Application Data"),
        .init(id: .desktopFolder, displayName: "Desktop Folder", category: "Files and Application Data"),
        .init(id: .documentsFolder, displayName: "Documents Folder", category: "Files and Application Data"),
        .init(id: .downloadsFolder, displayName: "Downloads Folder", category: "Files and Application Data"),
        .init(id: .networkVolumes, displayName: "Network Volumes", category: "Files and Application Data"),
        .init(id: .removableVolumes, displayName: "Removable Volumes", category: "Files and Application Data"),
        .init(id: .appData, displayName: "Other Apps’ Data", category: "Files and Application Data"),
        .init(id: .appBundles, displayName: "Application Bundles", category: "Files and Application Data"),
        .init(id: .systemAdministrationFiles, displayName: "System Administration Files", category: "Files and Application Data"),
        .init(id: .fileProviderDomain, displayName: "File Provider Domains", category: "Files and Application Data"),
        .init(id: .fileProviderPresence, displayName: "File Provider Presence", category: "Files and Application Data"),
        .init(id: .camera, displayName: "Camera", category: "Devices and Personal Data"),
        .init(id: .microphone, displayName: "Microphone", category: "Devices and Personal Data"),
        .init(id: .bluetooth, displayName: "Bluetooth", category: "Devices and Personal Data"),
        .init(id: .contacts, displayName: "Contacts", category: "Devices and Personal Data"),
        .init(id: .calendar, displayName: "Calendars", category: "Devices and Personal Data"),
        .init(id: .reminders, displayName: "Reminders", category: "Devices and Personal Data"),
        .init(id: .photos, displayName: "Photos", category: "Devices and Personal Data"),
        .init(id: .speechRecognition, displayName: "Speech Recognition", category: "Devices and Personal Data"),
        .init(id: .homeKit, displayName: "Home", category: "Devices and Personal Data"),
        .init(id: .siri, displayName: "Siri", category: "Devices and Personal Data"),
        .init(id: .motion, displayName: "Motion", category: "Devices and Personal Data"),
        .init(id: .focusStatus, displayName: "Focus Status", category: "Devices and Personal Data"),
        .init(id: .userTracking, displayName: "Tracking", category: "Devices and Personal Data"),
        .init(id: .all, displayName: "All supported decisions", category: "All")
    ]
}
