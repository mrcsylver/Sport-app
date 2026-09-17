import Foundation

/// The repetition discount, and it must agree with `tier_points()` in SQL and
/// `tierPoints()` in app.js to the last decimal. The server is what scores;
/// this only draws the budget and the preview — but a preview that disagrees
/// with the board is how a rule turns into a bug report.
///
/// Points are linear in reps and effort is not. The ceiling on a hard movement
/// is what a body can do; the ceiling on an easy one is only boredom. So the
/// first `cap` points of ONE exercise in ONE week pay in full, the next `cap`
/// pay half, everything past that pays a quarter. It never reaches zero, so no
/// total is capped and nobody is told to stop: repeating one movement simply
/// stops being the best way to score, and the best move left is something else.
enum Scoring {
    /// What a movement pays in full when the server has not said otherwise.
    /// Generous on purpose: 200 push-ups, 100 pull-ups, 400 squats, 800
    /// Russian twists, twenty minutes of plank.
    static let defaultCap: Double = 200

    /// What a whole week of one exercise scores.
    static func tierPoints(_ sum: Double, cap: Double) -> Double {
        let v = max(sum, 0), a = max(cap, 1)
        let full = min(v, a)
        let half = max(min(v, a * 2) - a, 0) * 0.5
        let quarter = max(v - a * 2, 0) * 0.25
        return ((full + half + quarter) * 100).rounded() / 100
    }

    /// What `raw` MORE points of an exercise are worth, given what the week
    /// already holds. Marginal, not total — it is the number somebody is about
    /// to earn, so it is the number the big digits have to show.
    static func delta(raw: Double, used: Double, cap: Double) -> Double {
        ((tierPoints(used + raw, cap: cap) - tierPoints(used, cap: cap)) * 100)
            .rounded() / 100
    }

    /// How the budget reads in the log sheet. Never a subtraction: the words
    /// are about a week filling up and about what to do next, because the
    /// arithmetic that reads as a rule when you meet it up front reads as a
    /// bug when you meet it afterwards.
    enum Tier { case full, half, quarter }

    static func tier(after: Double, cap: Double) -> Tier {
        if after > cap * 2 { return .quarter }
        if after > cap { return .half }
        return .full
    }

    static func budgetLine(name: String, after: Double, cap: Double,
                           movements: Int) -> String {
        let tail = movements > 0
            ? " · \(movements) movement\(movements == 1 ? "" : "s") this week" : ""
        switch tier(after: after, cap: cap) {
        case .quarter:
            return "\(name) is full for this week — quarter points from here.\(tail)"
        case .half:
            return "\(name) \(n(after))/\(n(cap)) this week — half points from here.\(tail)"
        case .full:
            return "\(name) \(n(after))/\(n(cap)) of this week at full price.\(tail)"
        }
    }

    private static func n(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}
