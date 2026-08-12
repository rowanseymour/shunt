import AppKit

private let keySenderPID = AEKeyword(0x7370_6964) // 'spid'

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
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
