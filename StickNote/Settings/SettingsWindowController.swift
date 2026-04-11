import AppKit
import SwiftData
import SwiftUI

/// Presents ``SettingsView`` in an `NSWindow` so Settings is available when the menu bar extra is hidden
/// and when opening from `applicationShouldHandleReopen`.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = SettingsView()
            .modelContext(AppState.shared.context)
            .environment(AppState.shared.model)

        let hostingView = NSHostingView(rootView: root)
        let size = NSSize(
            width: SettingsWindowMetrics.width,
            height: SettingsWindowMetrics.height
        )

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Settings"
        w.contentView = hostingView
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.setContentSize(size)
        w.contentMinSize = size
        w.contentMaxSize = size
        w.center()

        self.window = w
        w.makeKeyAndOrderFront(nil)
    }
}
