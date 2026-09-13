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

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            guard let model, model.hasRecovery, !model.shouldAllowImmediateQuit else {
                return .terminateNow
            }
            model.requestQuit()
            return .terminateCancel
        }
    }
}
