import SwiftUI

/// THE CUP.
///
/// The season table rewards turning up, which is the right thing to reward and
/// a quiet thing to watch — the leader on week 30 is usually the leader on week
/// 31. This is the other half: a straight knockout for the top of the season
/// over its last four weeks, where one bad week ends you however good the year
/// has been.
///
/// Nothing here is computed. The server derives the field, the draw and every
/// result from the same weekly history the hall tab reads, so this view draws a
/// bracket and never decides one.
///
/// A tree is the natural shape for a bracket and the wrong shape for a phone,
/// so a round is a LIST of ties and a tie is two stacked sides. The round on
/// show is a picker, defaulting to the one being played.
struct CupSection: View {
    @Environment(Session.self) private var session

    private var info: CupState? { session.cupInfo }
    private var ties: [CupTie] { session.cup }

    private var rounds: Int { info?.rounds ?? 0 }
    private var round: Int { min(max(session.cupRound ?? 1, 1), max(rounds, 1)) }
    private var shown: [CupTie] { ties.filter { $0.round == round } }
    private var finalTie: CupTie? { ties.first { $0.round == rounds } }

    var body: some View {
        if let info, !ties.isEmpty {
            SectionHead(title: "THE CUP", trailing: headline(info))
            mine(info)
            picker
            if let head = shown.first {
                HStack {
                    Text(head.roundName)
                        .font(Theme.display(13, .black)).kerning(1.4)
                    Spacer()
                    Text(Self.week(head.weekStart))
                        .font(Theme.mono(10)).foregroundStyle(Theme.inkMuted)
                }
                .padding(.top, 2)
            }
            ForEach(shown) { TieCard(tie: $0) }
            Text(hint(info))
                .font(.caption).foregroundStyle(Theme.inkMuted)
                .padding(.top, 2)
            Color.clear.frame(height: 10)
        }
    }

    private func headline(_ info: CupState) -> String {
        if let f = finalTie, f.winner != nil {
            return "WON BY \(f.winner == f.aId ? (f.aName ?? "") : (f.bName ?? ""))"
        }
        switch info.phase {
        case "PROJECTED":
            let n = info.weeksToLock ?? 0
            let unit = n == 1 ? "WEEK" : "WEEKS"
            return "LOCKS IN \(n) \(unit)"
        case "DONE":  return "FINISHED"
        default:      return info.roundName ?? "CUP"
        }
    }

    private var picker: some View {
        HStack(spacing: 6) {
            ForEach(1...max(rounds, 1), id: \.self) { r in
                Button {
                    Haptic.tap()
                    session.cupRound = r
                } label: {
                    Text(Self.shortRound(r, rounds))
                        .font(Theme.display(11, .black)).kerning(0.8)
                        .foregroundStyle(r == round ? Theme.void : Theme.inkMuted)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(r == round ? AnyShapeStyle(Theme.heat)
                                                 : AnyShapeStyle(Theme.raised))
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Your own tie, lifted out above the round so it is never hunted for.
    /// Somebody outside the field gets the only number that matters to them:
    /// how far off the cut they are.
    @ViewBuilder
    private func mine(_ info: CupState) -> some View {
        if let seed = info.mySeed {
            let mine = ties.filter { $0.mine }
            let live = mine.first { $0.status != "DONE" }
            if let live {
                let iAmA = live.aId == session.profile?.id
                let foe = iAmA ? live.bName : live.aName
                let foeSeed = iAmA ? live.bSeed : live.aSeed
                let open = iAmA ? live.bFrom : live.aFrom
                card(tint: Theme.flame,
                     tag: live.status == "LIVE" ? "YOUR TIE · THIS WEEK"
                                                : "YOUR TIE · \(Self.week(live.weekStart))",
                     title: "\(live.roundName) · V " + (foe.map { "\($0) (\(foeSeed ?? 0))" }
                             ?? open.map { "#\($0)" }.joined(separator: " / ")),
                     note: live.status == "LIVE"
                        ? "Seeded \(seed). \(Self.pts(iAmA ? live.aPoints ?? 0 : live.bPoints ?? 0)) against \(Self.pts(iAmA ? live.bPoints ?? 0 : live.aPoints ?? 0)) — whoever scores more this week goes through."
                        : "Seeded \(seed). Whoever scores more points that week goes through.")
            } else if let last = mine.last {
                let beaten = last.winner != session.profile?.id
                card(tint: beaten ? Theme.hairline : Theme.gold,
                     tag: beaten ? "KNOCKED OUT" : "CUP WINNER",
                     title: last.roundName,
                     note: beaten ? "Seeded \(seed). The cup is somebody else's."
                                  : "Seeded \(seed), and you won the thing.")
            }
        } else {
            let rank = info.myRank
            card(tint: Theme.hairline, tag: "NOT IN THE CUP",
                 title: rank.map { "\(RankPoints.ordinal($0)) IN THE SEASON" } ?? "NO FINISHED WEEK",
                 note: info.phase == "PROJECTED"
                    ? (rank != nil
                        ? "The top \(info.field) get in. \(info.cutPoints.map { "\(Self.pts($0)) season points is where the cut sits." } ?? "")"
                        : "Finish a week and you are on the table.")
                      + " The draw locks in \(info.weeksToLock ?? 0) weeks."
                    : "The field closed when the cup started. Next season.")
        }
    }

    private func card(tint: Color, tag: String, title: String, note: String) -> some View {
        Panel(padding: 14, tint: tint == Theme.hairline ? nil : tint) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tag)
                    .font(Theme.display(11, .black)).kerning(1.6)
                    .foregroundStyle(tint == Theme.hairline ? Theme.inkMuted : tint)
                Text(title).font(Theme.display(19, .black)).foregroundStyle(Theme.ink)
                Text(note).font(.caption).foregroundStyle(Theme.inkMuted)
            }
        }
    }

    private func hint(_ info: CupState) -> String {
        switch info.phase {
        case "PROJECTED":
            return "The top \(info.field) of the season go in, and this is the draw as the table stands today — it moves every week until it locks. Then one round a week, with the final in the season's last week."
        case "DONE":
            return "Season over. The next cup shows up ten weeks before the next final."
        default:
            return "A tie is won on the points you score this week in this league — nothing extra to log. Level on points goes to the higher seed, so the season is still worth playing."
        }
    }

    static func shortRound(_ r: Int, _ rounds: Int) -> String {
        switch rounds - r {
        case 0:  return "FINAL"
        case 1:  return "SEMIS"
        case 2:  return "QF"
        default: return "R\(Int(pow(2.0, Double(rounds - r + 1))))"
        }
    }

    /// Whole where it is whole, one decimal where it is not — the same way the
    /// hall tab writes a week's points.
    static func pts(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    static func week(_ iso: String) -> String {
        let parse = DateFormatter()
        parse.dateFormat = "yyyy-MM-dd"
        parse.timeZone = Config.timeZone
        guard let d = parse.date(from: String(iso.prefix(10))) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "d MMM"
        out.timeZone = Config.timeZone
        return out.string(from: d).uppercased()
    }
}

/// One tie, as two stacked sides: a seed, a name and what that side scored in
/// the tie's week. A side nobody has reached yet shows the seeds that still
/// could, which is the whole reason a bracket is worth looking at early.
struct TieCard: View {
    let tie: CupTie

    var body: some View {
        Panel(padding: 11, tint: tie.mine ? Theme.flame
                                          : (tie.status == "LIVE" ? Theme.gold : nil)) {
            VStack(spacing: 0) {
                side(seed: tie.aSeed, name: tie.aName, avatar: tie.aAvatar,
                     points: tie.aPoints, from: tie.aFrom, id: tie.aId)
                Rectangle().fill(Theme.hairline).frame(height: 1)
                side(seed: tie.bSeed, name: tie.bName, avatar: tie.bAvatar,
                     points: tie.bPoints, from: tie.bFrom, id: tie.bId)
            }
        }
    }

    @ViewBuilder
    private func side(seed: Int?, name: String?, avatar: String?, points: Double?,
                      from: [Int], id: UUID?) -> some View {
        let won = tie.winner != nil && tie.winner == id
        let lost = tie.winner != nil && !won
        HStack(spacing: 10) {
            Text(seed.map(String.init) ?? "")
                .font(Theme.mono(10, .bold))
                .foregroundStyle(won ? Theme.gold : Theme.inkFaint)
                .frame(width: 18, alignment: .trailing)
            if let name {
                Mark(spec: avatar, name: name, tint: won ? Theme.gold : nil)
                    .frame(width: 26, height: 26)
                Text(name)
                    .font(Theme.display(16, .heavy))
                    .foregroundStyle(won ? Theme.gold : Theme.ink)
                    .lineLimit(1)
            } else {
                Text(from.map { "#\($0)" }.joined(separator: " / "))
                    .font(Theme.mono(11)).foregroundStyle(Theme.inkMuted)
                    .lineLimit(1)
            }
            Spacer()
            if tie.status != "SCHEDULED", let points {
                Text(CupSection.pts(points))
                    .font(Theme.mono(14, .bold))
                    .foregroundStyle(won ? Theme.gold : Theme.ink)
            }
        }
        .opacity(lost ? 0.45 : 1)
        .padding(.vertical, 7)
    }
}
