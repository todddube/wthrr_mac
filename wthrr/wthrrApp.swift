// wthrrApp.swift
// wthrr — macOS decorative snowfall overlay
//
// Author: Todd Dube
// GitHub: https://github.com/todddube/wthrr_mac

import SwiftUI
import Darwin

/// App entry point. Registers the menu bar extra and wires up the AppDelegate.
/// The menu bar icon updates dynamically when the user switches weather type.
@main
struct wthrrApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    /// Mirrors the persisted weather type so SwiftUI can react to changes
    /// in the MenuBarExtra label — @AppStorage re-evaluates `body` when it changes.
    @AppStorage("weatherType") private var weatherTypeRaw: String = "snow"

    private var menuBarIcon: String {
        weatherTypeRaw == "rain" ? "cloud.rain.fill" : "cloud.snow.fill"
    }

    var body: some Scene {
        MenuBarExtra("wthrr", systemImage: menuBarIcon) {
            ContentView()
                .environment(SnowSettings.shared)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Handles app lifecycle: enforces single-instance, creates the snow overlay windows,
/// and installs a SIGTERM handler so the MenuBarExtra icon is cleanly removed on quit.
class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private(set) var snowflakeWindowController: SnowflakeWindowController?

    /// Called once the app has finished launching. Ensures only one instance runs,
    /// creates the overlay window controller, and sets up SIGTERM handling.
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

    /// Tears down overlay windows before the process exits, ensuring clean removal
    /// of the snow layer and MenuBarExtra icon.
    func applicationWillTerminate(_ notification: Notification) {
        snowflakeWindowController?.tearDown()
        snowflakeWindowController = nil
    }

    /// Keeps the app alive even when all regular windows are closed —
    /// the menu bar extra is the only UI surface.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private static var sigTermKey = 0
}
