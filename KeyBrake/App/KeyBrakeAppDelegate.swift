import AppKit
import SwiftUI

final class KeyBrakeAppDelegate: NSObject, NSApplicationDelegate {
    private var recoveryPanelController: RecoveryPanelController?
    private weak var model: KeyBrakeViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        recoveryPanelController = RecoveryPanelController()
    }

    @MainActor
    func attach(model: KeyBrakeViewModel) {
        self.model = model
        ensureRecoveryPanelController()
        if model.isShowingRecoveryPanel {
            recoveryPanelController?.show(model: model)
        }
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
}
