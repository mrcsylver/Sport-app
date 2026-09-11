import SwiftUI
import Observation

/// The whole app's state in one observable object. Views read it, nothing
/// else writes to it. Keeping it flat like this is deliberate: the app is
/// small, and one source of truth beats five coordinated ones.
@Observable
@MainActor
final class Session {
    enum Phase { case booting, needsProfile, ready, failed(String) }

    var phase: Phase = .booting
    var profile: Profile?
    var leagues: [League] = []
    var leagueId: UUID?

    var standings: [Standing] = []
    var raid: Raid?
    var bounty: Bounty?
    var combo: [ComboSlice] = []
    var streaks: [Streak] = []
    var rivalries: [Rivalry] = []
    var badges: [BadgeRow] = []
    var exercises: [Exercise] = []
    var history: [HistoryRow] = []
    var stats: [StatRow] = []
    var statsAllTime = false
    var duel: DuelRecord?
    var challenges: [Challenge] = []

    var feeds: [UUID: [WorkoutRow]] = [:]
    var toast: String?
    var isRefreshing = false

    var league: League? { leagues.first { $0.id == leagueId } }
    var me: Standing? { standings.first { $0.profileId == profile?.id } }

    /// Divisions: ten per division, ranked on live points. Below eleven
    /// people there is only one group, so showing divisions would be theatre.
    var divisions: [DivisionGroup] {
        guard standings.count >= Tuning.divisionMinimum else { return [] }
        let sorted = standings.sorted { $0.points > $1.points }
        var out: [DivisionGroup] = []
        var i = 0
        var counted = 0
        var numbering: String?
        for d in Division.allCases {
            guard i < sorted.count else { break }
            let end = min(i + d.size, sorted.count)
            var slice = Array(sorted[i..<end])
            // whoever spills past the last division joins it rather than
            // forming a sixth
            if d == .commoner && end < sorted.count { slice += sorted[end...] }
            // the Royal Guard and the Apex share a numbering; everything
            // below starts again at 1
            if d.rankGroup != numbering {
                counted = 0
                numbering = d.rankGroup
            }
            out.append(DivisionGroup(division: d, rows: slice, firstRank: counted + 1))
            counted += slice.count
            i = end
        }
        return out
    }

    // MARK: - Boot

    func boot() async {
        do {
            try await API.shared.ensureSignedIn()
            profile = try await API.shared.myProfile()

            guard profile != nil else {
                // A fresh device: signed in, but nobody yet.
                phase = .needsProfile
                return
            }

            let mine = try await API.shared.myLeagues()
            if exercises.isEmpty { exercises = try await API.shared.exercises() }

            guard !mine.isEmpty else {
                // A profile with no league — onboarding picks up at step two.
                phase = .needsProfile
                return
            }

            leagues = mine
            leagueId = mine.first?.id
            phase = .ready
            await refresh()
        } catch {
            phase = .failed(Friendly.message(error))
        }
    }

    func adopt(profile p: Profile) async {
        profile = p
        do {
            leagues = try await API.shared.myLeagues()
            leagueId = leagues.first?.id
            if exercises.isEmpty { exercises = try await API.shared.exercises() }
            phase = leagues.isEmpty ? .needsProfile : .ready
            if !leagues.isEmpty { await refresh() }
        } catch {
            show(Friendly.message(error))
        }
    }

    // MARK: - Refresh

    /// Each widget is loaded independently, so one failing call can never
    /// blank the leaderboard — the only thing on the screen that matters.
    func refresh() async {
        guard let id = leagueId else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let a = try? API.shared.leaderboard(id)
        async let b = try? API.shared.currentRaid(id)
        async let c = try? API.shared.currentBounty(id)
        async let d = try? API.shared.combo(id)
        async let e = try? API.shared.streaks(id)

        if let v = await a { standings = v }
        raid = await b ?? nil
        bounty = await c ?? nil
        if let v = await d { combo = v }
        if let v = await e { streaks = v }
    }

    func loadFeed(_ profileId: UUID) async {
        guard let id = leagueId, feeds[profileId] == nil else { return }
        feeds[profileId] = (try? await API.shared.feed(id, profile: profileId)) ?? []
    }

    func loadDuelsTab() async {
        guard let id = leagueId else { return }
        async let r = try? API.shared.rivalries(id)
        async let c = try? API.shared.myChallenges()
        async let d = try? API.shared.duelRecord(id)
        rivalries = await r ?? []
        challenges = await c ?? []
        duel = await d ?? nil
    }

    func loadBadges() async {
        guard let id = leagueId else { return }
        badges = (try? await API.shared.badges(id)) ?? []
    }

    func loadHall() async {
        guard let id = leagueId else { return }
        async let h = try? API.shared.weeklyHistory(id)
        async let s = try? API.shared.streaks(id)
        history = await h ?? []
        if let v = await s { streaks = v }
    }

    func loadStats() async {
        guard let id = leagueId else { return }
        async let s = try? API.shared.myStats(id, allTime: statsAllTime)
        async let b = try? API.shared.badges(id)
        stats = await s ?? []
        badges = await b ?? []
    }

    // MARK: - Actions

    func log(key: String, mode: String, amount: Double,
             bodyweightKg: Double? = nil, loadKg: Double? = nil) async -> Bool {
        guard let id = leagueId else { return false }
        do {
            try await API.shared.logWorkout(league: id, key: key, mode: mode,
                                            amount: amount,
                                            bodyweightKg: bodyweightKg, loadKg: loadKg)
            feeds.removeAll()
            await refresh()
            Haptic.win()
            return true
        } catch {
            show(Friendly.message(error))
            Haptic.refuse()
            return false
        }
    }

    func deleteLog(_ row: WorkoutRow) async {
        do {
            try await API.shared.deleteWorkout(row.id)
            feeds.removeAll()
            await refresh()
        } catch {
            show(Friendly.message(error))
        }
    }

    func switchLeague(_ id: UUID) async {
        leagueId = id
        feeds.removeAll()
        history = []
        stats = []
        badges = []
        rivalries = []
        await refresh()
    }

    // MARK: - Becoming somebody

    func createProfile(name: String) async -> Bool {
        do {
            let p = try await API.shared.createProfile(name: name.trimmingCharacters(in: .whitespaces))
            profile = p
            if exercises.isEmpty { exercises = (try? await API.shared.exercises()) ?? [] }
            Haptic.win()
            return true
        } catch {
            show(Friendly.message(error)); Haptic.refuse(); return false
        }
    }

    /// Moving a profile to another phone. The restore code is the only thing
    /// standing in for an account until accounts exist.
    func restore(code: String) async -> Bool {
        do {
            guard let p = try await API.shared.restoreProfile(code: code) else {
                show("No profile has that code."); Haptic.refuse(); return false
            }
            profile = p
            await adopt(profile: p)
            Haptic.win()
            return true
        } catch {
            show(Friendly.message(error)); Haptic.refuse(); return false
        }
    }

    // MARK: - Leagues

    func createLeague(name: String) async -> Bool {
        do {
            let made = try await API.shared.createLeague(
                name: name.trimmingCharacters(in: .whitespaces))
            leagues = try await API.shared.myLeagues()
            await switchLeague(made.id)
            phase = .ready
            Haptic.win()
            return true
        } catch {
            show(Friendly.message(error)); Haptic.refuse(); return false
        }
    }

    func joinLeague(code: String) async -> Bool {
        do {
            let joined = try await API.shared.joinLeague(code: code)
            leagues = try await API.shared.myLeagues()
            await switchLeague(joined.id)
            phase = .ready
            Haptic.win()
            return true
        } catch {
            show(Friendly.message(error)); Haptic.refuse(); return false
        }
    }

    func leaveLeague(_ id: UUID) async {
        do {
            try await API.shared.leaveLeague(id)
            await afterLeagueListChanged(dropping: id)
            show("You left that league.")
        } catch {
            show(Friendly.message(error))
        }
    }

    /// Only the person who made a league can delete it — the server enforces
    /// that, this is just the button.
    func deleteLeague(_ id: UUID) async {
        do {
            try await API.shared.deleteLeague(id)
            await afterLeagueListChanged(dropping: id)
            show("League deleted.")
        } catch {
            show(Friendly.message(error))
        }
    }

    private func afterLeagueListChanged(dropping id: UUID) async {
        leagues = (try? await API.shared.myLeagues()) ?? []
        feeds.removeAll()
        if leagueId == id { leagueId = leagues.first?.id }
        if leagues.isEmpty {
            standings = []; raid = nil; bounty = nil; combo = []
            phase = .needsProfile
        } else {
            await refresh()
        }
    }

    func saveLeagueSettings(restDow: [Int], seasonWeeks: Int?,
                            catchupDow: Int?) async {
        guard let id = leagueId else { return }
        do {
            _ = try await API.shared.setLeagueSettings(id, restDow: restDow,
                                                       seasonWeeks: seasonWeeks,
                                                       catchupDow: catchupDow)
            leagues = try await API.shared.myLeagues()
            show("League settings saved.")
            Haptic.win()
        } catch {
            show(Friendly.message(error)); Haptic.refuse()
        }
    }

    func saveCrest(_ badge: League.Badge) async {
        guard let id = leagueId else { return }
        do {
            _ = try await API.shared.setLeagueBadge(id, badge: badge)
            leagues = try await API.shared.myLeagues()
            Haptic.tap()
        } catch {
            show(Friendly.message(error)); Haptic.refuse()
        }
    }

    // MARK: - Your own look and numbers

    private func apply(_ work: () async throws -> Profile) async {
        do {
            profile = try await work()
            Haptic.tap()
        } catch {
            show(Friendly.message(error)); Haptic.refuse()
        }
    }

    func rename(_ name: String) async {
        await apply { try await API.shared.renameProfile(name.trimmingCharacters(in: .whitespaces)) }
    }
    func setAvatar(_ spec: String) async {
        await apply { try await API.shared.setAvatar(spec) }
        await refresh()
    }
    func setBanner(_ key: String) async {
        await apply { try await API.shared.setBanner(key) }
        await refresh()
    }
    func setNameColor(_ key: String) async {
        await apply { try await API.shared.setNameColor(key) }
        await refresh()
    }
    func setBodyweight(_ kg: Double?) async {
        await apply { try await API.shared.setBodyweight(kg) }
    }
    func setUnits(_ units: String) async {
        await apply { try await API.shared.setUnits(units) }
    }
    func setPinnedBadges(_ keys: [String]) async {
        await apply { try await API.shared.setPinnedBadges(keys) }
        await refresh()
    }

    // MARK: - Duels

    func openDuel() async {
        guard let id = leagueId else { return }
        do {
            _ = try await API.shared.createChallenge(id)
            await loadDuelsTab()
            Haptic.win()
        } catch {
            show(Friendly.message(error)); Haptic.refuse()
        }
    }

    func acceptDuel(code: String) async -> Bool {
        do {
            try await API.shared.acceptChallenge(code: code)
            await loadDuelsTab()
            Haptic.win()
            return true
        } catch {
            show(Friendly.message(error)); Haptic.refuse(); return false
        }
    }

    func cancelDuel(_ id: UUID) async {
        do {
            try await API.shared.cancelChallenge(id)
            await loadDuelsTab()
        } catch {
            show(Friendly.message(error))
        }
    }

    func show(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(3))
            if toast == message { toast = nil }
        }
    }

    // MARK: - Points preview
    //
    // Mirrors calc_points() in SQL to the decimal. This only draws the
    // preview; the server is what actually scores, and it is the authority.

    func exercise(_ key: String) -> Exercise? { exercises.first { $0.key == key } }

    func points(key: String, mode: String, amount: Double,
                bodyweightKg: Double? = nil, loadKg: Double? = nil) -> Double {
        guard let ex = exercise(key), let m = ex.modes[mode] else { return 0 }
        if let k = m.k {
            guard let bw = bodyweightKg, bw >= 30, bw <= 250,
                  let load = loadKg, load >= 0, load <= 500 else { return 0 }
            let r = (load * (m.equip ?? 1) + ((m.legs ?? false) ? 0.85 * bw : 0)) / bw
            return ((amount * k * r) * 100).rounded() / 100
        }
        return ((amount * (m.rate ?? 0)) * 100).rounded() / 100
    }
}

struct DivisionGroup: Identifiable {
    let division: Division
    let rows: [Standing]
    /// The number the first row in this division wears. Not a league-wide
    /// position: the Royal Guard and the Apex share a run of 1 to 5, and
    /// every division below counts from 1 again.
    let firstRank: Int
    var id: String { division.rawValue }
}

enum Tuning {
    /// Below this many people a division is just the table with headings in it.
    static let divisionMinimum = 10
    static let comboMinimum: Double = 10
    static let comboGroups = ["PUSH", "PULL", "LEGS", "CORE", "CARDIO"]
}

/// The rank ladder, matching the web app exactly so a person's grade does not
/// change when they switch device.
struct Grade: Identifiable {
    let at: Double
    let name: String
    let tier: Int

    var id: String { name }

    static let ladder: [Grade] = {
        let spec: [(String, Int, [Double])] = [
            ("SPARK", 0, [25]), ("ROOKIE", 0, [50]), ("REGULAR", 1, [100]),
            ("GRINDER", 1, [200, 350, 550]), ("MACHINE", 2, [800, 1100, 1500]),
            ("BEAST", 2, [2000, 2600, 3300]), ("WARLORD", 3, [4200, 5300, 6600]),
            ("TITAN", 3, [8200, 10000, 12500]), ("IMMORTAL", 4, [15500, 19000, 23000]),
            ("ASCENDANT", 4, [28000, 34000, 41000]), ("ETERNAL", 5, [50000])
        ]
        let roman = ["I", "II", "III"]
        return spec.flatMap { name, tier, marks in
            marks.enumerated().map { i, at in
                Grade(at: at, name: marks.count > 1 ? "\(name) \(roman[i])" : name, tier: tier)
            }
        }
    }()

    static func reached(_ lifetime: Double) -> Grade? {
        ladder.last { lifetime >= $0.at }
    }
    static func next(_ lifetime: Double) -> Grade? {
        ladder.first { lifetime < $0.at }
    }
    static func color(tier: Int) -> Color {
        switch tier {
        case 0: return Theme.inkFaint
        case 1: return Theme.azure
        case 2: return Theme.violet
        case 3: return Theme.gold
        case 4: return Theme.flame
        default: return Theme.jade
        }
    }
}
