import Foundation

/// Every date the app reasons about, in the league's timezone.
///
/// The rule this exists to enforce: the clock belongs to the league, never to
/// the phone. Two people in the same league are in one week that ends at one
/// instant, and a device in Chicago must not think it is still Sunday when
/// Paris has turned Monday. Nothing here reads `TimeZone.current`.
///
/// It mirrors the web app function for function on purpose. The two clients
/// score against the same server, so a disagreement between them is a bug
/// report from somebody who is right.
enum LeagueClock {

    private static var cal: Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = Config.timeZone
        return c
    }

    /// ISO weekday, 1 = Monday … 7 = Sunday, in the league's timezone.
    static func isoDow(_ date: Date) -> Int {
        // Calendar gives 1 = Sunday; the server and the settings screen both
        // count 1 = Monday, so this is the translation and the only place it
        // should ever happen.
        let sundayFirst = cal.component(.weekday, from: date)
        return sundayFirst == 1 ? 7 : sundayFirst - 1
    }

    /// The days this league rests, as ISO weekdays.
    ///
    /// An unknown league rests on no day. It used to fall back to Sunday,
    /// which meant the app announced a Sunday rest day to a league that rests
    /// on Monday for as long as the league took to load. The server refuses
    /// the entry either way, and it refuses it naming the real day.
    static func restDows(_ league: League?) -> [Int] {
        (league?.restDow ?? []).filter { (1...7).contains($0) }
    }

    static func isRestDay(_ league: League?, now: Date = Date()) -> Bool {
        restDows(league).contains(isoDow(now))
    }

    /// Monday 00:00 of the current week, in the league's timezone.
    static func weekStart(_ now: Date = Date()) -> Date {
        cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    }

    /// Midnight tonight: when a rest day lifts, whichever day it falls on.
    static func restDayEnd(_ now: Date = Date()) -> Date {
        cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
    }

    /// The instant the league stops scoring this week: the end of the last day
    /// of the week that is not a rest day.
    ///
    /// A league resting on Sunday scores until Saturday night, which is what
    /// this always used to mean back when Sunday was the only rest day there
    /// was. A league resting on Monday scores until Sunday night. A league
    /// resting on Saturday and Sunday scores until Friday night.
    static func leagueClose(_ league: League?, now: Date = Date()) -> Date {
        guard let week = cal.dateInterval(of: .weekOfYear, for: now) else { return now }
        let rest = restDows(league)
        var day = 7                                   // Sunday, last of the week
        while day > 1 && rest.contains(day) { day -= 1 }
        return cal.date(byAdding: .day, value: day, to: week.start) ?? week.end
    }

    /// What the header counts down to, and what it should call it.
    static func countdown(_ league: League?, now: Date = Date()) -> (label: String, target: Date) {
        isRestDay(league, now: now)
            ? ("REST DAY · OPENS IN", restDayEnd(now))
            : ("LEAGUE CLOSES IN", leagueClose(league, now: now))
    }
}
