import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var hostingView: NSHostingView<PopoverView>!
    private var cookieWindowController: CookieWindowController?
    private var signInWindowController: SignInWindowController?
    private let store = UsageStore()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = Self.batteryImage(for: nil)
        }

        menu = NSMenu()
        menu.delegate = self
        let item = NSMenuItem()
        hostingView = NSHostingView(rootView: PopoverView(
            store: store,
            onRequestSignIn: { [weak self] in self?.presentSignIn() },
            onRequestCookieEntry: { [weak self] in self?.presentCookieEntry() }
        ))
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 260)
        item.view = hostingView
        menu.addItem(item)
        statusItem.menu = menu

        store.$snapshot
            .combineLatest(store.$lastError)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in self?.updateStatusIcon() }
            .store(in: &cancellables)

        store.start()
    }

    func menuWillOpen(_ menu: NSMenu) {
        Task { await store.refresh() }
        resizeHostingView()
    }

    /// Accessory (menu-bar-only) apps have no main menu by default, but Cmd+key
    /// equivalents like paste/copy are matched against NSApp.mainMenu before
    /// reaching the responder chain — without this, Cmd+V silently does nothing
    /// in any text field even though right-click paste still works.
    private func setUpMainMenu() {
        let mainMenu = NSMenu()

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    private func presentSignIn() {
        menu.cancelTracking()
        let controller = SignInWindowController(onSignedIn: { [weak self] cookie in
            self?.store.setCookie(cookie)
        })
        signInWindowController = controller
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    private func presentCookieEntry() {
        menu.cancelTracking()
        let controller = CookieWindowController(onSave: { [weak self] cookie in
            self?.store.setCookie(cookie)
        })
        cookieWindowController = controller
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    private func resizeHostingView() {
        let fitting = hostingView.fittingSize
        let width: CGFloat = 300
        let height = max(fitting.height, 100)
        if hostingView.frame.size != NSSize(width: width, height: height) {
            hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        }
    }

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        let fraction = store.menuBarRemainingFraction
        button.image = Self.batteryImage(for: fraction)
        if let fraction {
            button.toolTip = "Claude usage: \(Int(fraction * 100))% left"
        } else if store.lastError != nil {
            button.toolTip = "Claude usage: unavailable"
        } else {
            button.toolTip = "Claude usage"
        }
        resizeHostingView()
    }

    private static func batteryImage(for fraction: Double?) -> NSImage? {
        let symbolName: String
        var tint: NSColor?

        guard let fraction else {
            let image = NSImage(systemSymbolName: "battery.0percent", accessibilityDescription: "Claude usage unknown")
            let config = NSImage.SymbolConfiguration(paletteColors: [.secondaryLabelColor])
            let configured = image?.withSymbolConfiguration(config)
            configured?.isTemplate = false
            return configured
        }

        switch fraction {
        case ..<0.001: symbolName = "battery.0percent"
        case ..<0.30: symbolName = "battery.25percent"
        case ..<0.55: symbolName = "battery.50percent"
        case ..<0.80: symbolName = "battery.75percent"
        default: symbolName = "battery.100percent"
        }

        if fraction <= 0.10 {
            tint = .systemRed
        } else if fraction <= 0.30 {
            tint = .systemOrange
        }

        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Claude usage \(Int(fraction * 100))% left")
        guard let tint else {
            image?.isTemplate = true
            return image
        }
        let config = NSImage.SymbolConfiguration(paletteColors: [tint])
        let configured = image?.withSymbolConfiguration(config)
        configured?.isTemplate = false
        return configured
    }
}
