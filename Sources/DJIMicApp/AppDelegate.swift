import AppKit
import DJIMicUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MicNotificationCenter.shared.configure()
    }
}
