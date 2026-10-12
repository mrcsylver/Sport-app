import Foundation
import UIKit
import WebKit

/// The robot check, for the native app.
///
/// WHY IT EXISTS AT ALL. The front door of this app is Supabase's anonymous
/// sign-in, which writes a row in `auth.users`. The key that calls it is
/// public by design, so without a gate a script can mint accounts until a
/// free database is full — and every fresh identity also comes with its own
/// ten guesses at somebody else's restore code, which is what makes the
/// throttle inside `restore_profile()` a fence rather than a gate.
///
/// WHY IT IS A WEB VIEW. Turnstile is a browser widget, and Cloudflare only
/// accepts a challenge served from a hostname on the widget's allow-list.
/// `about:blank`, which is where a local HTML string lives, can never be on
/// that list. So the app opens the web app's own `captcha.html` over https
/// and takes the token back through a message handler.
///
/// WHY IT MAKES ITS OWN WINDOW. `ensureSignedIn()` runs before there is any
/// view to present from — it is what gets the app to its first screen. A
/// `UIWindow` of its own needs nothing from the view hierarchy and tears
/// itself down afterwards.
///
/// OFF BY DEFAULT: `Config.turnstileSiteKey` empty means `token()` returns
/// nil without creating anything, and the sign-in goes out as it always has.
@MainActor
enum Captcha {
    static var isOn: Bool { !Config.turnstileSiteKey.isEmpty }

    /// A token, or nil when this is switched off. Throws when the challenge
    /// cannot be completed, because a sign-in with no token against a project
    /// that demands one fails with a message about CAPTCHAs that means
    /// nothing to anybody.
    static func token() async throws -> String? {
        guard isOn else { return nil }
        guard var parts = URLComponents(string: Config.captchaPage) else {
            throw CaptchaError.unreachable
        }
        parts.queryItems = [URLQueryItem(name: "k", value: Config.turnstileSiteKey)]
        guard let url = parts.url else { throw CaptchaError.unreachable }

        let host = CaptchaHost(url: url)
        defer { host.dismiss() }
        return try await host.run()
    }
}

enum CaptchaError: LocalizedError {
    case failed
    case unreachable

    var errorDescription: String? {
        switch self {
        case .failed:      return "The robot check did not go through. Try again."
        case .unreachable: return "The robot check could not load. Check your connection."
        }
    }
}

/// The window, the web view and the one message handler between them.
@MainActor
final class CaptchaHost: NSObject, WKScriptMessageHandler {
    private let url: URL
    private var window: UIWindow?
    private var waiter: CheckedContinuation<String, Error>?

    init(url: URL) {
        self.url = url
        super.init()
    }

    func run() async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            waiter = cont
            present()
            /// A challenge somebody walks away from must not wedge the app on
            /// its launch screen for ever.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 90 * 1_000_000_000)
                self?.finish(.failure(CaptchaError.failed))
            }
        }
    }

    private func present() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else {
            finish(.failure(CaptchaError.unreachable))
            return
        }
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "captcha")
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = UIColor(red: 0.043, green: 0.051, blue: 0.063, alpha: 1)
        web.load(URLRequest(url: url))

        let holder = UIViewController()
        holder.view.backgroundColor = web.backgroundColor
        holder.view.addSubview(web)
        web.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            web.topAnchor.constraint(equalTo: holder.view.topAnchor),
            web.bottomAnchor.constraint(equalTo: holder.view.bottomAnchor),
            web.leadingAnchor.constraint(equalTo: holder.view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: holder.view.trailingAnchor)
        ])

        let w = UIWindow(windowScene: scene)
        w.rootViewController = holder
        /// Spelled out rather than `.alert + 1`: UIWindow.Level is a struct
        /// around a CGFloat and arithmetic on it is not free.
        w.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        w.makeKeyAndVisible()
        window = w
    }

    func dismiss() {
        window?.isHidden = true
        window = nil
    }

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        /// Whatever the page posts is data, not instruction: the only thing
        /// read out of it is a string under `token`, and anything else is a
        /// failure.
        guard let body = message.body as? [String: Any] else {
            finish(.failure(CaptchaError.failed)); return
        }
        if let token = body["token"] as? String, !token.isEmpty {
            finish(.success(token)); return
        }
        let why = body["error"] as? String ?? ""
        finish(.failure(why == "CAPTCHA_UNREACHABLE" || why == "NO_SITE_KEY"
                        ? CaptchaError.unreachable : CaptchaError.failed))
    }

    private func finish(_ result: Result<String, Error>) {
        guard let cont = waiter else { return }
        waiter = nil
        dismiss()
        cont.resume(with: result)
    }
}
