import Foundation

// Shapes returned by the Postgres functions. Field names match the SQL
// exactly so the default snake_case decoding strategy does the work.

struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var avatar: String?
    var restoreCode: String
    var bodyweight: Double?
    var units: String?
    var banner: String?
    var nameColor: String?
    var pinnedBadges: [String]?
    var isAdmin: Bool?
    /// Set when an admin parked this account to free a seat. Nothing is
    /// deleted; the profile simply does not count against the cap and cannot
    /// be used until a seat frees up.
    var dormantAt: Date?
    /// A ring drawn around the avatar, on every row of every board. The one
    /// cosmetic slot that is uploaded artwork rather than something drawn.
    var frame: String?
    /// One line this person wrote about themselves, shown on their card. The
    /// only free text in this app that other people read.
    var bio: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatar
        case restoreCode = "restore_code"
        case bodyweight, units, banner
        case nameColor = "name_color"
        case pinnedBadges = "pinned_badges"
        case isAdmin = "is_admin"
        case dormantAt = "dormant_at"
        case frame, bio
    }

    var isParked: Bool { dormantAt != nil }

    var usesPounds: Bool { units == "lb" }
}

struct League: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var code: String
    var ownerId: UUID
    var members: Int
    var maxMembers: Int
    var badge: Badge?
    var restDow: [Int]?
    var seasonWeeks: Int?
    /// The weekday, 1 = Monday, where being behind is worth a multiplier.
    /// Nil means the league does not have one.
    var catchupDow: Int?
    enum CodingKeys: String, CodingKey {
        case id, name, code, badge
        case ownerId = "owner_id"
        case members
        case maxMembers = "max_members"
        case restDow = "rest_dow"
        case seasonWeeks = "season_weeks"
        case catchupDow = "catchup_dow"
    }

    /// `my_leagues()` counts the members for us; the functions that return a
    /// bare `leagues` row (create, join, settings) do not. Rather than have
    /// two types for one thing, the count is simply allowed to be absent and
    /// the next refresh fills it in.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self, forKey: .id)
        name        = try c.decode(String.self, forKey: .name)
        code        = try c.decode(String.self, forKey: .code)
        ownerId     = try c.decode(UUID.self, forKey: .ownerId)
        members     = try c.decodeIfPresent(Int.self, forKey: .members) ?? 0
        maxMembers  = try c.decodeIfPresent(Int.self, forKey: .maxMembers) ?? 30
        badge       = try c.decodeIfPresent(Badge.self, forKey: .badge)
        restDow     = try c.decodeIfPresent([Int].self, forKey: .restDow)
        seasonWeeks = try c.decodeIfPresent(Int.self, forKey: .seasonWeeks)
        catchupDow  = try c.decodeIfPresent(Int.self, forKey: .catchupDow)
    }

    struct Badge: Codable, Hashable {
        var shape: String?
        var color: String?
        var emblem: String?
        var skin: String?
        var text: String?
    }
}

struct Standing: Codable, Identifiable, Hashable {
    let profileId: UUID
    var displayName: String
    var avatar: String?
    var points: Double
    var basePoints: Double
    var bonus: Double
    var entries: Int
    var lifetime: Double
    var banner: String?
    var pinnedBadges: [String]?
    var nameColor: String?

    var id: UUID { profileId }

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case displayName = "display_name"
        case avatar, points, entries, bonus, lifetime, banner
        case basePoints = "base_points"
        case pinnedBadges = "pinned_badges"
        case nameColor = "name_color"
    }
}

struct Exercise: Codable, Identifiable, Hashable {
    let key: String
    var name: String
    var cat: String
    var variants: String
    var aliases: String
    var sort: Int
    var modes: [String: Mode]
    /// How many points of THIS movement one week pays in full before the
    /// repetition discount starts. Optional so the app still decodes against
    /// a server that has not run the migration yet; 200 is the default there
    /// too, so the fallback is the real answer and not a guess.
    var cap: Double?

    var id: String { key }
    var weekCap: Double { max(cap ?? Scoring.defaultCap, 1) }

    struct Mode: Codable, Hashable {
        var rate: Double?
        var k: Double?
        var equip: Double?
        var legs: Bool?
        /// How much of the lifter's own body this movement already carries
        /// before a plate goes on: 0.85 on a standing leg lift, 1.0 on a dip
        /// or a pull-up you hang from, 0 on a bench or a seated machine.
        /// Optional, and falls back to the old `legs` flag, so the app still
        /// scores correctly against a server that has not taken the new seed.
        var own: Double?
        var pattern: String?
        var isGym: Bool { k != nil }
        var bodyShare: Double { own ?? ((legs ?? false) ? 0.85 : 0) }
    }

    var isGym: Bool { cat == "GYM" }
    var firstMode: String { modes.keys.sorted().first ?? "reps" }

    func matches(_ q: String) -> Bool {
        guard !q.isEmpty else { return true }
        let hay = "\(name) \(cat) \(aliases)".lowercased()
        return hay.contains(q.lowercased())
    }
}

struct WorkoutRow: Codable, Identifiable, Hashable {
    let id: UUID
    var exerciseKey: String
    var mode: String
    var amount: Double
    var points: Double
    var createdAt: Date?
    var profileId: UUID?
    /// What the catch-up day multiplied this by. 1 on every other day.
    var boost: Double?

    enum CodingKeys: String, CodingKey {
        case id, mode, amount, points, boost
        case exerciseKey = "exercise_key"
        case createdAt = "created_at"
        case profileId = "profile_id"
    }
}

struct Raid: Codable, Hashable {
    var idx: Int
    var name: String
    var descr: String
    var unit: String
    var target: Double
    var progress: Double
    var members: Int
    var done: Bool
    var topName: String?
    var topAmount: Double?

    enum CodingKeys: String, CodingKey {
        case idx, name, descr, unit, target, progress, members, done
        case topName = "top_name"
        case topAmount = "top_amount"
    }

    var fraction: Double { target > 0 ? min(progress / target, 1) : 0 }
}

struct Bounty: Codable, Hashable {
    var idx: Int
    var name: String
    var descr: String
    var points: Double
    var onDate: String?
    var mine: Bool
    var winners: Int
    var firstName: String?

    enum CodingKeys: String, CodingKey {
        case idx, name, descr, points, mine, winners
        case onDate = "on_date"
        case firstName = "first_name"
    }
}

struct Streak: Codable, Identifiable, Hashable {
    let profileId: UUID
    var displayName: String
    var avatar: String?
    var banner: String?
    var currentStreak: Int
    var bestStreak: Int
    var activeDays: Int

    var id: UUID { profileId }

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case displayName = "display_name"
        case avatar, banner
        case currentStreak = "current_streak"
        case bestStreak = "best_streak"
        case activeDays = "active_days"
    }
}

struct Rivalry: Codable, Identifiable, Hashable {
    var aId: UUID
    var aName: String
    var aAvatar: String?
    var aPoints: Double
    var bId: UUID
    var bName: String
    var bAvatar: String?
    var bPoints: Double
    var seed: Int
    var mine: Bool

    var id: Int { seed }

    enum CodingKeys: String, CodingKey {
        case aId = "a_id", aName = "a_name", aAvatar = "a_avatar", aPoints = "a_points"
        case bId = "b_id", bName = "b_name", bAvatar = "b_avatar", bPoints = "b_points"
        case seed, mine
    }
}

struct BadgeRow: Codable, Identifiable, Hashable {
    let key: String
    var name: String
    var descr: String
    var earned: Bool
    var progress: Double
    var target: Double

    var id: String { key }
    var fraction: Double { target > 0 ? min(progress / target, 1) : 0 }
}

struct ComboSlice: Codable, Hashable {
    var category: String
    var points: Double
}

/// A finished week. `week_start` is a bare Postgres `date`, so it is decoded
/// as text and formatted here rather than trusting a date strategy with it.
struct HistoryRow: Codable, Identifiable, Hashable {
    let weekStart: String
    let profileId: UUID
    var displayName: String
    var avatar: String?
    var points: Double
    var entries: Int

    var id: String { "\(weekStart)-\(profileId.uuidString)" }

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case profileId = "profile_id"
        case displayName = "display_name"
        case avatar, points, entries
    }
}

/// One line of the season table. Every finished week pays by FINISHING PLACE
/// — 5.00 for a win down to 0.10 for twentieth, nothing below that — and the
/// season adds them up. It replaced a "first to five crowns" race whose fatal
/// hole was that only a winner ever moved, so anybody who could not
/// realistically top the board had nothing to chase.
struct SeasonRow: Codable, Identifiable, Hashable {
    let profileId: UUID
    var displayName: String
    var avatar: String?
    var banner: String?
    var nameColor: String?
    var points: Double
    var weeks: Int
    var wins: Int
    /// Best finish of the season, nil for somebody who has not finished a week.
    var bestRank: Int?
    /// Crowns follow the person across every season; `wins` is this one only.
    var lifetimeWins: Int
    var mine: Bool

    var id: UUID { profileId }

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case displayName = "display_name"
        case avatar, banner, points, weeks, wins, mine
        case nameColor = "name_color"
        case bestRank = "best_rank"
        case lifetimeWins = "lifetime_wins"
    }
}

/// Where the cup stands. A straight knockout for the top of the season over
/// its last four weeks — the other half of a table that rewards turning up.
/// Every field here is derived on the server from the weeks already logged;
/// nothing about a bracket is stored, so nothing about one can go stale.
struct CupState: Codable, Hashable {
    /// PROJECTED while the draw still moves, RUNNING once it locks, DONE after
    /// the final. The server returns no row at all when there is no cup.
    var phase: String
    /// Zero-based, like the season table.
    var season: Int
    var seasons: Int
    /// 16, 8 or 4 — the biggest power of two the league can fill.
    var field: Int
    var rounds: Int
    /// How many people played a week that counts for the draw.
    var entrants: Int
    /// Weeks before this count for the seeding; after it the draw is fixed.
    var lockWeek: String?
    /// The Monday the first round is played, and the Monday of the final.
    var firstWeek: String?
    var finalWeek: String?
    /// 1…rounds while RUNNING, nil otherwise.
    var round: Int?
    var roundName: String?
    var weekStart: String?
    var weeksToLock: Int?
    /// Where you are in the seeding, even when that is outside the field.
    var myRank: Int?
    /// Your seed, or nil when you did not make the cut.
    var mySeed: Int?
    /// What the last qualifying place is worth, so "how far off" is answerable.
    var cutPoints: Double?

    enum CodingKeys: String, CodingKey {
        case phase, season, seasons, field, rounds, entrants, round
        case lockWeek = "lock_week"
        case firstWeek = "first_week"
        case finalWeek = "final_week"
        case roundName = "round_name"
        case weekStart = "week_start"
        case weeksToLock = "weeks_to_lock"
        case myRank = "my_rank"
        case mySeed = "my_seed"
        case cutPoints = "cut_points"
    }
}

/// One tie. `aFrom` and `bFrom` are the seeds that can still arrive on each
/// side, which is what makes a bracket worth looking at before it is played:
/// a quarter-final reads "1/16 v 8/9" until both halves are settled.
struct CupTie: Codable, Hashable, Identifiable {
    var round: Int
    var roundName: String
    var slot: Int
    var aSeed: Int?
    var aId: UUID?
    var aName: String?
    var aAvatar: String?
    var aPoints: Double?
    var aFrom: [Int]
    var bSeed: Int?
    var bId: UUID?
    var bName: String?
    var bAvatar: String?
    var bPoints: Double?
    var bFrom: [Int]
    var winner: UUID?
    var winnerSeed: Int?
    /// SCHEDULED, LIVE or DONE — the week this tie is played in.
    var status: String
    var weekStart: String
    var mine: Bool

    var id: String { "\(round)-\(slot)" }

    enum CodingKeys: String, CodingKey {
        case round, slot, winner, status, mine
        case roundName = "round_name"
        case aSeed = "a_seed"
        case aId = "a_profile"
        case aName = "a_name"
        case aAvatar = "a_avatar"
        case aPoints = "a_points"
        case aFrom = "a_from"
        case bSeed = "b_seed"
        case bId = "b_profile"
        case bName = "b_name"
        case bAvatar = "b_avatar"
        case bPoints = "b_points"
        case bFrom = "b_from"
        case winnerSeed = "winner_seed"
        case weekStart = "week_start"
    }
}

/// Where the season stands, so the header never does arithmetic.
struct SeasonInfo: Codable, Hashable {
    /// Zero-based: season 0 is the first one.
    var season: Int
    var seasons: Int
    /// nil means one open season that never ends.
    var seasonWeeks: Int?
    /// Weeks of rest between one season and the next.
    var seasonBreak: Int?
    var weeksDone: Int
    /// True while the league sits in the off-season. The table then shows the
    /// final standings of the season that just ended.
    var onBreak: Bool?
    /// The Monday the next season opens.
    var nextStart: String?
    /// The Monday this season's first finished week began — the lower bound the
    /// stats tab uses for its season range.
    var firstWeek: String?

    var weeksLeft: Int? {
        guard let total = seasonWeeks else { return nil }
        return max(0, total - weeksDone)
    }
    var resting: Bool { onBreak == true }

    enum CodingKeys: String, CodingKey {
        case season, seasons
        case seasonWeeks = "season_weeks"
        case seasonBreak = "season_break"
        case weeksDone = "weeks_done"
        case onBreak = "on_break"
        case nextStart = "next_start"
        case firstWeek = "first_week"
    }
}

/// What each finishing place pays. Must agree with rank_points() in SQL and
/// RANK_POINTS in app.js to the last decimal.
enum RankPoints {
    static let table: [Double] = [5.00, 3.60, 2.80, 2.30, 1.90, 1.60, 1.35, 1.15,
                                  1.00, 0.85, 0.70, 0.60, 0.50, 0.40, 0.33, 0.27,
                                  0.21, 0.16, 0.13, 0.10]
    static func forPlace(_ place: Int) -> Double {
        guard place >= 1, place <= table.count else { return 0 }
        return table[place - 1]
    }
    static func ordinal(_ n: Int) -> String {
        let last = n % 100
        if (11...13).contains(last) { return "\(n)th" }
        switch n % 10 {
        case 1: return "\(n)st"
        case 2: return "\(n)nd"
        case 3: return "\(n)rd"
        default: return "\(n)th"
        }
    }
}

struct StatRow: Codable, Identifiable, Hashable {
    let exerciseKey: String
    var category: String
    var mode: String
    var totalAmount: Double
    /// What the work scored, after the repetition discount.
    var totalPoints: Double
    var entries: Int
    var activeDays: Int
    /// What the movement is worth before the discount, and the budget it is
    /// measured against. Both optional for an un-migrated server.
    var rawPoints: Double?
    var cap: Double?

    var id: String { "\(exerciseKey)-\(mode)" }
    /// True only when this row actually met its budget. Most never will.
    var wasDiscounted: Bool { (rawPoints ?? totalPoints) > totalPoints + 0.001 }

    enum CodingKeys: String, CodingKey {
        case exerciseKey = "exercise_key"
        case category, mode, entries, cap
        case totalAmount = "total_amount"
        case totalPoints = "total_points"
        case activeDays = "active_days"
        case rawPoints = "raw_points"
    }
}

struct DuelRecord: Codable, Hashable {
    var played: Int
    var won: Int
    var lost: Int
    var drawn: Int
    var bestStreak: Int

    enum CodingKeys: String, CodingKey {
        case played, won, lost, drawn
        case bestStreak = "best_streak"
    }
}

struct Challenge: Codable, Identifiable, Hashable {
    let id: UUID
    var code: String
    var status: String          // PENDING · LIVE · FINISHED · CANCELLED
    var leagueName: String
    var meName: String
    var meAvatar: String?
    var mePoints: Double
    var foeName: String?
    var foeAvatar: String?
    var foePoints: Double?
    var createdAt: Date?
    var endsAt: Date?
    var iStarted: Bool

    enum CodingKeys: String, CodingKey {
        case id, code, status
        case leagueName = "league_name"
        case meName = "me_name", meAvatar = "me_avatar", mePoints = "me_points"
        case foeName = "foe_name", foeAvatar = "foe_avatar", foePoints = "foe_points"
        case createdAt = "created_at", endsAt = "ends_at"
        case iStarted = "i_started"
    }

    var isLive: Bool { status == "LIVE" }
    var isPending: Bool { status == "PENDING" }
    var winning: Bool { mePoints > (foePoints ?? 0) }
}

struct ChallengePreview: Codable, Hashable {
    var code: String
    var leagueName: String
    var challengerName: String
    var challengerAvatar: String?
    var status: String

    enum CodingKeys: String, CodingKey {
        case code, status
        case leagueName = "league_name"
        case challengerName = "challenger_name"
        case challengerAvatar = "challenger_avatar"
    }
}

/// What `league_preview` gives before you join: enough to show what you are
/// about to walk into, and nothing that belongs to members only.
struct LeaguePreviewRow: Codable, Hashable {
    let id: UUID
    var name: String
    var code: String
    var members: Int
    var maxMembers: Int

    enum CodingKeys: String, CodingKey {
        case id, name, code, members
        case maxMembers = "max_members"
    }

    var isFull: Bool { members >= maxMembers }
}

/// How full the app is, straight from `signup_state()`. `cap` is nil when
/// there is no cap set at all, which is the normal state.
struct SignupState: Codable {
    var cap: Int?
    var used: Int
    var isFull: Bool

    enum CodingKeys: String, CodingKey {
        case cap, used
        case isFull = "is_full"
    }
}

/// One thing on a shelf. `owned` is worked out by the server per caller, so
/// the client never reasons about entitlements itself — and the setters
/// refuse anything this says is not yours, which makes a locked tile the
/// label on a rule rather than the rule.
struct ShopItem: Codable, Identifiable, Hashable {
    let key: String
    let kind: String
    let item: String
    let name: String
    var priceCents: Int?
    var assetPath: String?
    var assetKind: String?
    var thumbPath: String?
    var animated: Bool
    var sort: Int
    var owned: Bool

    var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, kind, item, name, animated, sort, owned
        case priceCents = "price_cents"
        case assetPath = "asset_path"
        case assetKind = "asset_kind"
        case thumbPath = "thumb_path"
    }

    /// A file in the designs bucket, as a URL. Public on purpose: the artwork
    /// is cosmetic and goes through the CDN, which is the only way the
    /// bandwidth works on a free project.
    static func assetURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: Config.supabaseURL.absoluteString
                   + "/storage/v1/object/public/" + path)
    }
    /// The still, when there is one. A shelf of twenty animations pulls
    /// twenty animations; a shelf of twenty stills pulls twenty small images.
    var thumbURL: URL? { ShopItem.assetURL(thumbPath ?? assetPath) }
    var artURL: URL? { ShopItem.assetURL(assetPath) }
}

/// Who in a league is wearing a ring.
struct FrameRow: Codable {
    let profileId: UUID
    let frame: String

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case frame
    }
}

/// Who somebody is, when you tap their face on the board. What the server
/// chose to send — no restore code, no bodyweight, no account id — because
/// `profiles` is readable only for your own row and a card has to be a
/// function that decides what it returns.
struct PlayerCard: Decodable, Identifiable {
    let profileId: UUID
    let displayName: String
    let avatar: String?
    let banner: String?
    let nameColor: String?
    let frame: String?
    let bio: String?
    let pinnedBadges: [String]
    let lifetime: Double
    let joinedAt: Date?

    var id: UUID { profileId }

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case displayName = "display_name"
        case avatar, banner, bio, lifetime
        case nameColor = "name_color"
        case frame
        case pinnedBadges = "pinned_badges"
        case joinedAt = "joined_at"
    }
}
