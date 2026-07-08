import AppKit
import WebKit

/// Shows claude.ai's real login page in an embedded browser and grabs the
/// `sessionKey` cookie the moment it appears, instead of asking the user to
/// dig it out of DevTools. Also handles popup-based sign-in (e.g. "Continue
/// with Google") by opening a child window that shares the same cookie store.
@MainActor
final class SignInWindowController: NSWindowController, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver, NSWindowDelegate {
    private let webView: WKWebView
    private let onSignedIn: (String) -> Void
    private var didSignIn = false
    private var popupControllers: [SignInWindowController] = []

    convenience init(onSignedIn: @escaping (String) -> Void) {
        self.init(configuration: WKWebViewConfiguration(), onSignedIn: onSignedIn, isPopup: false)
        webView.load(URLRequest(url: URL(string: "https://claude.ai/login")!))
    }

    private init(configuration: WKWebViewConfiguration, onSignedIn: @escaping (String) -> Void, isPopup: Bool) {
        self.onSignedIn = onSignedIn
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 480, height: 680), configuration: configuration)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 680),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = isPopup ? "Sign in" : "Sign in to Claude"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        window.delegate = self
        webView.navigationDelegate = self
        webView.uiDelegate = self
        window.contentView = webView

        if !isPopup {
            configuration.websiteDataStore.httpCookieStore.add(self)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Popup support (e.g. "Continue with Google")

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        let popup = SignInWindowController(configuration: configuration, onSignedIn: onSignedIn, isPopup: true)
        popupControllers.append(popup)
        popup.showWindow(nil)
        popup.window?.makeKeyAndOrderFront(nil)
        return popup.webView
    }

    func webViewDidClose(_ webView: WKWebView) {
        popupControllers.removeAll { $0.webView === webView }
        webView.window?.close()
    }

    // MARK: - Cookie watching

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        guard !didSignIn else { return }
        cookieStore.getAllCookies { [weak self] cookies in
            guard let self, !self.didSignIn else { return }
            guard let sessionCookie = cookies.first(where: {
                $0.name == "sessionKey" && $0.domain.hasSuffix("claude.ai")
            }), !sessionCookie.value.isEmpty else { return }
            self.didSignIn = true
            self.onSignedIn(sessionCookie.value)
            self.close()
        }
    }

    func windowWillClose(_ notification: Notification) {
        webView.configuration.websiteDataStore.httpCookieStore.remove(self)
        popupControllers.forEach { $0.window?.close() }
    }
}
