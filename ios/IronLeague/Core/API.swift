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
    ///
    /// It goes through Supabase's `signup` endpoint, which is one of the
    /// three a CAPTCHA guards once Attack Protection is on. `Captcha.token()`
    /// returns nil while no site key is configured, which is the shipped
    /// state, so this is the same call it has always been until both sides
    /// are switched on together.
    func ensureSignedIn() async throws {
        if client.auth.currentSession == nil {
            let token = try await Captcha.token()
            _ = try await client.auth.signInAnonymously(captchaToken: token)
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

    /// One line somebody writes about themselves, trimmed and bounded by the
    /// server rather than here — this is the courtesy, not the rule.
    func setBio(_ text: String) async throws -> Profile {
        try await rpc("set_bio", ["p_bio": .string(text)])
    }

    /// Nil when you share no league with them, which is the server saying no
    /// rather than an error: a card is not something you are owed.
    func playerCard(_ id: UUID) async throws -> PlayerCard? {
        let rows: [PlayerCard] = try await rpc(
            "player_card", ["p_profile": .string(id.uuidString)])
        return rows.first
    }

    func createProfile(name: String) async throws -> Profile {
        try await rpc("create_profile", ["p_name": .string(name)])
    }
    /// Zero rows for a code that matches nothing — not an error. The server
    /// has to record the failed attempt for its ten-an-hour throttle, and one
    /// call is one transaction, so raising would roll that write back. The
    /// whole story is in supabase/restore-throttle.sql.
    func restoreProfile(code: String) async throws -> Profile? {
        let rows: [Profile] = try await rpc(
            "restore_profile", ["p_code": .string(code.uppercased())])
        return rows.first
    }

    /// How full the app is. Asked BEFORE showing a name box: being told there
    /// is no room after picking a fighter name is the worst version of this.
    func signupState() async throws -> SignupState? {
        let rows: [SignupState] = try await rpc("signup_state")
        return rows.first
    }

    /// Un-park a profile. Raises APP_FULL if there is no seat to wake into,
    /// which is the whole point — the cap holds on the way back in too.
    func wakeMe() async throws -> Profile {
        try await rpc("wake_me")
    }

    // MARK: - The shop

    /// The shelf. One row per item on sale, with `owned` worked out per
    /// caller so the client never reasons about entitlements itself.
    func shopCatalogue() async throws -> [ShopItem] {
        try await rpc("shop_catalogue")
    }

    /// The avatar ring. Its own setter rather than a field on setAvatar,
    /// because the ring and the mark inside it are bought separately.
    func setFrame(_ key: String) async throws -> Profile {
        try await rpc("set_frame", ["p_frame": .string(key)])
    }

    /// Who in this league is wearing one. A separate call rather than a
    /// column on the seven functions that already return an avatar: widening
    /// a return type means dropping it first, and seven drops to carry one
    /// short text column is the wrong trade.
    func leagueFrames(_ league: UUID) async throws -> [FrameRow] {
        try await rpc("league_frames", ["p_league": .string(league.uuidString)])
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
    /// `size` is how many people the league holds, 2…100. The web app and
    /// this one both default to 36 — the five divisions come to exactly that
    /// — but a league advertised to a whole gym needs the real number, since
    /// somebody arriving at a full one is simply turned away.
    func createLeague(name: String, size: Int = 36) async throws -> League {
        try await rpc("create_league", [
            "p_name": .string(name),
            "p_size": .integer(max(2, min(100, size)))
        ])
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
            .select("id,exercise_key,mode,amount,points,boost,created_at,profile_id")
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
    func seasonTable(_ league: UUID, season: Int? = nil) async throws -> [SeasonRow] {
        try await rpc("league_season", [
            "p_league": .string(league.uuidString),
            // null means whichever season is running now
            "p_season": season.map { .integer($0) } ?? .null
        ])
    }
    func seasonInfo(_ league: UUID) async throws -> SeasonInfo? {
        let rows: [SeasonInfo] = try await rpc("league_season_state",
                                               ["p_league": .string(league.uuidString)])
        return rows.first
    }
    /// Where the cup stands. No row at all means there is no cup to show —
    /// an endless season, a season too short, too few people, or simply more
    /// than ten weeks still to run.
    func cupState(_ league: UUID, season: Int? = nil) async throws -> CupState? {
        let rows: [CupState] = try await rpc("league_cup_state", [
            "p_league": .string(league.uuidString),
            "p_season": season.map { .integer($0) } ?? .null
        ])
        return rows.first
    }
    /// The bracket: every tie of every round, in order.
    func cupBracket(_ league: UUID, season: Int? = nil) async throws -> [CupTie] {
        try await rpc("league_cup", [
            "p_league": .string(league.uuidString),
            "p_season": season.map { .integer($0) } ?? .null
        ])
    }
    func weeklyHistory(_ league: UUID) async throws -> [HistoryRow] {
        try await rpc("weekly_history", ["p_league": .string(league.uuidString)])
    }
    /// `from` bounds the range below, so a season is "everything since the
    /// Monday it opened". A third parameter rather than a range word, because
    /// replacing `p_all` would mean dropping a function the stats tab polls.
    func myStats(_ league: UUID, allTime: Bool,
                 from: String? = nil) async throws -> [StatRow] {
        try await rpc("my_stats", ["p_league": .string(league.uuidString),
                                   "p_all": .bool(allTime),
                                   "p_from": from.map { .string($0) } ?? .null])
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
    /// only accepts null or 1…52, so a zero would be rejected by the check.
    /// `seasonBreak` is weeks of off-season between seasons, 0…6.
    /// `maxMembers` is nil to leave the size alone. It can go up at any time
    /// and never below the people already in — nobody is removed to make a
    /// league smaller, so the server raises LEAGUE_SHRINK instead.
    func setLeagueSettings(_ id: UUID, restDow: [Int], seasonWeeks: Int?,
                           catchupDow: Int?, seasonBreak: Int?,
                           maxMembers: Int? = nil) async throws -> League {
        try await rpc("set_league_settings", [
            "p_league": .string(id.uuidString),
            "p_rest_dow": .array(restDow.map { .integer($0) }),
            "p_season_weeks": seasonWeeks.map { .integer($0) } ?? .null,
            "p_catchup_dow": catchupDow.map { .integer($0) } ?? .null,
            "p_season_break": seasonBreak.map { .integer($0) } ?? .null,
            "p_max_members": maxMembers.map { .integer(max(2, min(100, $0))) } ?? .null
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
            "APP_FULL": "Iron League is at capacity right now. Nothing of yours is lost — try again in a day or two, or ask for a seat.",
            "TOO_MANY_TRIES": "Too many wrong codes from this phone. Wait an hour and try again.",
            "LEAGUE_SHRINK": "That is fewer than the people already in. Nobody is removed to make a league smaller.",
            "BAD_SIZE": "A league holds between 2 and 100 people.",
            "BIO_TOO_LONG": "Your line has to fit in 140 characters.",
            "LOCKED_ITEM": "That one is not yours yet.",
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
