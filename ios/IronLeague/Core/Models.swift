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

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatar
        case restoreCode = "restore_code"
        case bodyweight, units, banner
        case nameColor = "name_color"
        case pinnedBadges = "pinned_badges"
        case isAdmin = "is_admin"
    }

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

    var id: String { key }

    struct Mode: Codable, Hashable {
        var rate: Double?
        var k: Double?
        var equip: Double?
        var legs: Bool?
        var pattern: String?
        var isGym: Bool { k != nil }
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

struct StatRow: Codable, Identifiable, Hashable {
    let exerciseKey: String
    var category: String
    var mode: String
    var totalAmount: Double
    var totalPoints: Double
    var entries: Int
    var activeDays: Int

    var id: String { "\(exerciseKey)-\(mode)" }

    enum CodingKeys: String, CodingKey {
        case exerciseKey = "exercise_key"
        case category, mode, entries
        case totalAmount = "total_amount"
        case totalPoints = "total_points"
        case activeDays = "active_days"
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
