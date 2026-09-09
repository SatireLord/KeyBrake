import AppKit
import SwiftUI

final class KeyBrakeAppDelegate: NSObject, NSApplicationDelegate {
    private var recoveryPanelController: RecoveryPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        recoveryPanelController = RecoveryPanelController()
    }
}
