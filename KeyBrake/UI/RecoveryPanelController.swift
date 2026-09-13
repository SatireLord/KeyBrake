import AppKit
import SwiftUI

@MainActor
final class RecoveryPanelController {
    private var panel: NSPanel?

    func show(model: KeyBrakeViewModel) {
        if panel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 470), styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
            panel.title = "KeyBrake Recovery"
            panel.level = .floating
            panel.isMovableByWindowBackground = true
            panel.contentView = NSHostingView(rootView: RecoveryView(model: model))
            self.panel = panel
        }
        panel?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel?.orderOut(nil)
    }
}
