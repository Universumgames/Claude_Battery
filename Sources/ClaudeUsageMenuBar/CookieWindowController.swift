import AppKit
import SwiftUI

@MainActor
final class CookieWindowController: NSWindowController {
    convenience init(onSave: @escaping (String) -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Claude Session Cookie"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()

        self.init(window: window)

        let view = CookieEntryView(
            onSave: { [weak self] value in
                onSave(value)
                self?.close()
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )
        window.contentView = NSHostingView(rootView: view)
    }
}
