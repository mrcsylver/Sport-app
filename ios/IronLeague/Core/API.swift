import Foundation
import Supabase

/// One typed call per Postgres function. Nothing in the app talks to Supabase
/// except through here, so a change in the schema has exactly one place to
/// land — the same discipline the web client uses.
///
/// Every one of these is a SECURITY DEFINER function that checks membership
/// server-side. The app cannot read a league it does not belong to, however
/// it asks.
actor API {
    static let shared = API()

    nonisolated let client = SupabaseClient(
        supabaseURL: Config.supabaseURL,
        supabaseKey: Config.supabaseAnonKey)

    // MARK: - Session

    /// Anonymous sign-in, exactly like the web app: no email, no password, a
    /// device-bound identity that a restore code can move to another phone.
    func ensureSignedIn() async throws {
        if client.auth.currentSession == nil {
            _ = try await client.auth.signInAnonymously()
        }
    }

    private func rpc<T: Decodable>(_ fn: String,
                                   _ params: [String: AnyJSON] = [:],
                                   as: T.Type = T.self) async throws -> T {
        let query = params.isEmpty
            ? client.rpc(fn)
            : client.rpc(fn, params: params)
        return try await query.execute().value
    }

    private func rpcVoid(_ fn: String, _ params: [String: AnyJSON] = [:]) async throws {
        let query = params.isEmpty
            ? client.rpc(fn)
            : client.rpc(fn, params: params)
        _ = try await query.execute()
    }

    // MARK: - Profile

    /// The one read that is not an RPC: row-level security already limits
    /// `profiles` to your own row plus people you share a league with, so
    /// filtering on the signed-in user is enough.
    func myProfile() async throws -> Profile? {
        guard let uid = client.auth.currentSession?.user.id else { return nil }
        let rows: [Profile] = try await client
            .from("profiles").select()
            .eq("user_id", value: uid.uuidString)
            .limit(1)
            .execute().value
        return rows.first
    }

    func createProfile(name: String) async throws -> Profile {
        try await rpc("create_profile", ["p_name": .string(name)])
    }
    func restoreProfile(code: String) async throws -> Profile? {
        try await rpc("restore_profile", ["p_code": .string(code.uppercased())])
    }
    func renameProfile(_ name: String) async throws -> Profile {
        try await rpc("rename_profile", ["p_name": .string(name)])
    }
    func setAvatar(_ spec: String) async throws -> Profile {
        try await rpc("set_avatar", ["p_avatar": .string(spec)])
    }
    func setBodyweight(_ kg: Double?) async throws -> Profile {
        try await rpc("set_bodyweight", ["p_kg": kg.map { .double($0) } ?? .null])
    }
    func setUnits(_ units: String) async throws -> Profile {
        try await rpc("set_units", ["p_units": .string(units)])
    }
    func setNameColor(_ key: String) async throws -> Profile {
        try await rpc("set_name_color", ["p_color": .string(key)])
    }
    func setBanner(_ key: String) async throws -> Profile {
        try await rpc("set_banner", ["p_banner": .string(key)])
    }
    func setPinnedBadges(_ keys: [String]) async throws -> Profile {
        try await rpc("set_pinned_badges", ["p_keys": .array(keys.map { .string($0) })])
    }

    // MARK: - Leagues

    func myLeagues() async throws -> [League] {
        try await rpc("my_leagues")
    }
    func leaguePreview(code: String) async throws -> LeaguePreviewRow? {
        let rows: [LeaguePreviewRow] = try await rpc("league_preview",
                                                     ["p_code": .string(code.uppercased())])
        return rows.first
    }
    func createLeague(name: String) async throws -> League {
        try await rpc("create_league", ["p_name": .string(name)])
    }
    func joinLeague(code: String) async throws -> League {
        try await rpc("join_league_by_code", ["p_code": .string(code.uppercased())])
    }
    func leaveLeague(_ id: UUID) async throws {
        try await rpcVoid("leave_league", ["p_league": .string(id.uuidString)])
    }
    func deleteLeague(_ id: UUID) async throws {
        try await rpcVoid("delete_league", ["p_league": .string(id.uuidString)])
    }

    // MARK: - The board

    func leaderboard(_ league: UUID, week: String? = nil) async throws -> [Standing] {
        var p: [String: AnyJSON] = ["p_league": .string(league.uuidString)]
        if let week { p["p_week"] = .string(week) }
        return try await rpc("league_leaderboard", p)
    }
    func feed(_ league: UUID, profile: UUID) async throws -> [WorkoutRow] {
        try await client
            .from("workouts")
            .select("id,exercise_key,mode,amount,points,created_at,profile_id")
            .eq("league_id", value: league.uuidString)
            .eq("profile_id", value: profile.uuidString)
            .order("created_at", ascending: false)
            .execute().value
    }

    // MARK: - Logging

    /// Fans out to every league the person is in, exactly like the web app —
    /// one workout, one row per league, sharing a group_id.
    @discardableResult
    func logWorkout(league: UUID, key: String, mode: String, amount: Double,
                    bodyweightKg: Double? = nil, loadKg: Double? = nil) async throws -> [WorkoutRow] {
        try await rpc("log_workout", [
            "p_league": .string(league.uuidString),
            "p_key": .string(key),
            "p_mode": .string(mode),
            "p_amount": .double(amount),
            "p_bw": bodyweightKg.map { .double($0) } ?? .null,
            "p_load": loadKg.map { .double($0) } ?? .null
        ])
    }

    func deleteWorkout(_ id: UUID) async throws {
        _ = try await client.from("workouts").delete().eq("id", value: id.uuidString).execute()
    }

    // MARK: - Everything derived

    func exercises() async throws -> [Exercise] {
        try await client.from("exercises").select().order("sort").execute().value
    }
    func currentRaid(_ league: UUID) async throws -> Raid? {
        let rows: [Raid] = try await rpc("current_raid", ["p_league": .string(league.uuidString)])
        return rows.first
    }
    func currentBounty(_ league: UUID) async throws -> Bounty? {
        let rows: [Bounty] = try await rpc("current_bounty", ["p_league": .string(league.uuidString)])
        return rows.first
    }
    func combo(_ league: UUID) async throws -> [ComboSlice] {
        try await rpc("my_combo_today", ["p_league": .string(league.uuidString)])
    }
    func streaks(_ league: UUID) async throws -> [Streak] {
        try await rpc("league_streaks", ["p_league": .string(league.uuidString)])
    }
    func rivalries(_ league: UUID) async throws -> [Rivalry] {
        try await rpc("league_rivalries", ["p_league": .string(league.uuidString)])
    }
    func badges(_ league: UUID) async throws -> [BadgeRow] {
        try await rpc("my_badges", ["p_league": .string(league.uuidString)])
    }
    func weeklyHistory(_ league: UUID) async throws -> [HistoryRow] {
        try await rpc("weekly_history", ["p_league": .string(league.uuidString)])
    }
    func myStats(_ league: UUID, allTime: Bool) async throws -> [StatRow] {
        try await rpc("my_stats", ["p_league": .string(league.uuidString),
                                   "p_all": .bool(allTime)])
    }

    // MARK: - Duels

    func duelRecord(_ league: UUID) async throws -> DuelRecord? {
        let rows: [DuelRecord] = try await rpc("my_duel_record",
                                               ["p_league": .string(league.uuidString)])
        return rows.first
    }
    func myChallenges() async throws -> [Challenge] {
        try await rpc("my_challenges")
    }
    func createChallenge(_ league: UUID) async throws -> ChallengeRow {
        try await rpc("create_challenge", ["p_league": .string(league.uuidString)])
    }
    func challengePreview(code: String) async throws -> ChallengePreview? {
        let rows: [ChallengePreview] = try await rpc("challenge_preview",
                                                     ["p_code": .string(code.uppercased())])
        return rows.first
    }
    @discardableResult
    func acceptChallenge(code: String) async throws -> ChallengeRow {
        try await rpc("accept_challenge", ["p_code": .string(code.uppercased())])
    }
    func cancelChallenge(_ id: UUID) async throws {
        try await rpcVoid("cancel_challenge", ["p_id": .string(id.uuidString)])
    }

    // MARK: - Owning a league

    /// `seasonWeeks` is nil for a league that just keeps going — the column
    /// only accepts null or 1…26, so a zero would be rejected by the check.
    func setLeagueSettings(_ id: UUID, restDow: [Int],
                           seasonWeeks: Int?) async throws -> League {
        try await rpc("set_league_settings", [
            "p_league": .string(id.uuidString),
            "p_rest_dow": .array(restDow.map { .integer($0) }),
            "p_season_weeks": seasonWeeks.map { .integer($0) } ?? .null
        ])
    }
    func setLeagueBadge(_ id: UUID, badge: League.Badge) async throws -> League {
        var fields: [String: AnyJSON] = [:]
        if let v = badge.shape  { fields["shape"]  = .string(v) }
        if let v = badge.color  { fields["color"]  = .string(v) }
        if let v = badge.emblem { fields["emblem"] = .string(v) }
        if let v = badge.skin   { fields["skin"]   = .string(v) }
        if let v = badge.text   { fields["text"]   = .string(v) }
        return try await rpc("set_league_badge", [
            "p_league": .string(id.uuidString),
            "p_badge": .object(fields)
        ])
    }
}

/// `create_challenge` and `accept_challenge` return the raw row rather than
/// the joined view `my_challenges` gives, so it gets its own small shape.
struct ChallengeRow: Codable, Hashable {
    let id: UUID
    var code: String
    var leagueId: UUID

    enum CodingKeys: String, CodingKey {
        case id, code
        case leagueId = "league_id"
    }
}

/// Turns a Postgres error into something worth showing a person.
enum Friendly {
    static func message(_ error: Error) -> String {
        // A PostgrestError keeps the server's text in its own fields, and
        // localizedDescription on a Swift error struct throws that away, so
        // both are searched.
        let raw = "\(error) \(error.localizedDescription)"
        let map: [String: String] = [
            "REST_DAY_DONE": "You already logged your rest-day stretch.",
            "REST_DAY": "It is a rest day — only a stretch counts.",
            "WEEK_CLOSED": "That week is finished and cannot be edited.",
            "LEAGUE_FULL": "That league is full.",
            "NOT_A_MEMBER": "You are not in that league.",
            "NO_PROFILE": "Something went wrong with your profile — reopen the app."
        ]
        for (needle, nice) in map where raw.contains(needle) { return nice }
        if raw.contains("duplicate key") { return "That already exists." }
        if let pretty = quoted(raw) { return pretty }
        return error.localizedDescription
    }

    /// Postgres raises its own exceptions with a readable sentence — "Only the
    /// person who created a league can change its settings" — so pull that
    /// out rather than showing a person a struct dump.
    private static func quoted(_ raw: String) -> String? {
        guard let r = raw.range(of: "message: \"") ??
                      raw.range(of: "message: Optional(\"") else { return nil }
        let rest = raw[r.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        let text = String(rest[..<end])
        return text.isEmpty ? nil : text
    }
}
