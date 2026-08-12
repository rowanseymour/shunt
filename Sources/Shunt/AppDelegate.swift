import AppKit
import SwiftUI

private let keySenderPID = AEKeyword(0x7370_6964) // 'spid'

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var devSettingsWindow: NSWindow?
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Must be registered before didFinishLaunching to catch the URL that launched us.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        // Matches LSUIElement in Info.plist; also hides the dock icon when run unbundled during development.
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dev affordance, e.g. for capturing screenshots without clicking through the menu.
        if ProcessInfo.processInfo.environment["SHUNT_OPEN_SETTINGS"] != nil {
            let window = NSWindow(contentViewController: NSHostingController(
                rootView: SettingsView().environment(AppModel.shared)
            ))
            window.title = "Shunt Settings"
            window.styleMask = [.titled, .closable]
            window.makeKeyAndOrderFront(nil)
            devSettingsWindow = window
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // One-time onboarding: after acceptance this never fires again.
        if !AppModel.shared.isDefaultBrowser {
            AppModel.shared.setAsDefaultBrowser()
        }
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else { return }
        let senderPID = event.attributeDescriptor(forKeyword: keySenderPID)?.int32Value
        let sourceApp = senderPID.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier }
        AppModel.shared.route(url, from: sourceApp)
    }
}
