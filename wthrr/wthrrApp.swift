import SwiftUI
import Darwin

@main
struct wthrrApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("wthrr", systemImage: "cloud.snow.fill") {
            ContentView()
                .environment(SnowSettings.shared)
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private(set) var snowflakeWindowController: SnowflakeWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Enforce single instance: if another copy is already running, quit this one.
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != NSRunningApplication.current }
        if !others.isEmpty {
            NSApplication.shared.terminate(nil)
            return
        }

        snowflakeWindowController = SnowflakeWindowController()
        snowflakeWindowController?.showWindows()

        // Catch SIGTERM (sent by Xcode stop button and launchd) and turn it into
        // a clean NSApp termination so applicationWillTerminate fires and the
        // MenuBarExtra icon is properly removed before the process exits.
        signal(SIGTERM, SIG_IGN)
        let sigTermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        sigTermSource.setEventHandler {
            NSApplication.shared.terminate(nil)
        }
        sigTermSource.resume()
        // Keep the source alive for the lifetime of the app
        objc_setAssociatedObject(self, &AppDelegate.sigTermKey, sigTermSource, .OBJC_ASSOCIATION_RETAIN)
    }

    func applicationWillTerminate(_ notification: Notification) {
        snowflakeWindowController?.tearDown()
        snowflakeWindowController = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private static var sigTermKey = 0
}
