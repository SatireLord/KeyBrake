import AppKit
import SwiftUI

// Greppable:
// canonical: recovery-panel-lifecycle
// aliases: recovery panel; AppKit recovery panel; title-bar close
// forms: recovery-panel-lifecycle; isShowingRecoveryPanel
// descriptors: canonical recovery surface; panel dismissal; panel re-presentation
// states: shown; hidden; closing; reopened
// consumers: KeyBrakeAppDelegate; RecoveryView; KeyBrakeMenuView
// owner: RecoveryPanelController
@MainActor
final class RecoveryPanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private weak var model: KeyBrakeViewModel?

    func show(model: KeyBrakeViewModel) {
        if panel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 470), styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
            panel.title = "KeyBrake Recovery"
            panel.level = .floating
            panel.isReleasedWhenClosed = false
            panel.isMovableByWindowBackground = true
            panel.delegate = self
            panel.contentView = NSHostingView(rootView: RecoveryView(model: model))
            self.panel = panel
        }
        self.model = model
        panel?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        model?.keepIsolation()
    }
}
