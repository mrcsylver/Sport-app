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

    /// Shown at the foot of the leagues tab, so a bug report can say which
    /// build it came from.
    static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }
}
