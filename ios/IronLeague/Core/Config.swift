import Foundation

/// The same Supabase project the web app uses. The anon key is designed to be
/// public: the database is protected by row-level security and the SECURITY
/// DEFINER functions in supabase/schema.sql, not by hiding this string.
enum Config {
    static let supabaseURL = URL(string: "https://ivjufpcmrhvjrysvomji.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2anVmcGNtcmh2anJ5c3ZvbWppIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MTAzMzMsImV4cCI6MjEwNDI4NjMzM30.a4J2lNrwBvZNqjHS0JxjoMQkRwan4A_jhuKSkJ8Xarc"

    /// Every week boundary, rest day and bounty date is computed in this zone
    /// on the server. The app must agree or the countdown lies.
    static let timeZone = TimeZone(identifier: "Europe/Paris") ?? .current

    /// The symbol the shop prints prices in. Mirrors CURRENCY in config.js.
    static let currency = "\u{20ac}"

    /// Where somebody turned away at the door is sent to ask for a seat —
    /// an Instagram profile, a mailto:, a form, whatever. Leave it empty and
    /// the button is hidden rather than dead. Mirrors CONTACT_URL in config.js.
    static let contactURL = "mailto:mrcsylver@gmail.com"

    /// Cloudflare Turnstile. Empty means off, exactly as in config.js, and
    /// off is the shipped state: no web view is ever created and no challenge
    /// is ever asked for. Fill it in only at the same time as Supabase's own
    /// Attack Protection — a key here with nothing checking it is theatre,
    /// and Supabase checking with no key here means nobody can sign in.
    ///
    /// The SITE key, which is public like the anon key above. The secret one
    /// belongs in the Supabase dashboard and nowhere in this repository.
    static let turnstileSiteKey = ""

    /// Where the challenge page lives. It has to be a hostname on the
    /// Cloudflare widget's allow-list, which a local HTML string can never
    /// be, so the native app borrows the web app's own page.
    static let captchaPage = "https://mrcsylver.github.io/Sport-app/captcha.html"

    /// Shown at the foot of the leagues tab, so a bug report can say which
    /// build it came from.
    static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }
}
