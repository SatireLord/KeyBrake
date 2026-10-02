import AppKit
import KeyBrakeCore
import SwiftUI
import UserNotifications

final class KeyBrakeAppDelegate: NSObject, NSApplicationDelegate {
    private var recoveryPanelController: RecoveryPanelController?
    private weak var model: KeyBrakeViewModel?
    private var pendingKeyboardSettingsRoute = false
    private var openSettingsWindow: (() -> Void)?
    private let recoveryNotificationBridge = KeyBrakeRecoveryNotificationBridge()

    func applicationDidFinishLaunching(_ notification: Notification) {
        recoveryPanelController = RecoveryPanelController()
        recoveryNotificationBridge.owner = self
        UNUserNotificationCenter.current().delegate = recoveryNotificationBridge
    }

    @MainActor
    func attach(model: KeyBrakeViewModel, openSettingsWindow: (() -> Void)? = nil) {
        self.model = model
        if let openSettingsWindow {
            self.openSettingsWindow = openSettingsWindow
        }
        ensureRecoveryPanelController()
        if model.isShowingRecoveryPanel {
            recoveryPanelController?.show(model: model)
        }
        deliverKeyboardSettingsRouteIfReady()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { KeyBrakeSystemSettingsRoute.parse($0) == .keyboard }) else { return }
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.receiveKeyboardSettingsRoute()
            }
        }
    }

    @MainActor
    func presentRecoveryFromNotification() {
        guard let model else { return }
        model.isShowingRecoveryPanel = true
        presentRecoveryPanel(model: model)
    }

    @MainActor
    func presentRecoveryPanel(model: KeyBrakeViewModel) {
        attach(model: model)
        recoveryPanelController?.show(model: model)
    }

    @MainActor
    func hideRecoveryPanel() {
        recoveryPanelController?.hide()
    }

    @MainActor
    private func ensureRecoveryPanelController() {
        if recoveryPanelController == nil {
            recoveryPanelController = RecoveryPanelController()
        }
    }

    @MainActor
    private func receiveKeyboardSettingsRoute() {
        pendingKeyboardSettingsRoute = true
        deliverKeyboardSettingsRouteIfReady()
    }

    @MainActor
    private func deliverKeyboardSettingsRouteIfReady() {
        guard pendingKeyboardSettingsRoute,
              let model,
              let openSettingsWindow else { return }
        pendingKeyboardSettingsRoute = false
        model.openKeyboardSettingsFromSystemSettings()
        openSettingsWindow()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            guard let model else {
                return .terminateCancel
            }
            guard model.shouldInterceptTermination else {
                return .terminateNow
            }
            model.requestQuit()
            return .terminateCancel
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            model?.cleanupDemoStore()
        }
    }
}

/// Forwards the recovery notification onto the main actor without capturing
/// KeyBrakeAppDelegate inside the UserNotifications callback.
private final class KeyBrakeRecoveryNotificationBridge: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    weak var owner: KeyBrakeAppDelegate?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let opensRecovery = response.notification.request.identifier == "keybrake.recovery-pending"
        let owner = owner
        completionHandler()
        guard opensRecovery else { return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                owner?.presentRecoveryFromNotification()
            }
        }
    }
}
