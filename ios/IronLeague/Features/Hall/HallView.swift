import SwiftUI

/// What already happened. Finished weeks first, because a league's history is
/// the thing that makes this week matter, then Iron Will — the streak table,
/// which rewards turning up rather than turning up big.
struct HallView: View {
    @Environment(Session.self) private var session
    @State private var openWeek: String?
    @State private var pastOpen = false
    @State private var payoutOpen = false

    private struct Week: Identifiable {
        let id: String
        let label: String
        let rows: [HistoryRow]
    }

    private var weeks: [Week] {
        let grouped = Dictionary(grouping: session.history, by: \.weekStart)
        return grouped.keys.sorted(by: >).map { key in
            Week(id: key,
                 label: Self.label(key),
                 rows: grouped[key]!.sorted { $0.points > $1.points })
        }
    }


    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                SectionHead(title: "SEASON", trailing: seasonTrailing)
                if session.season.isEmpty || session.seasonInfo?.weeksDone ?? 0 == 0 {
                    EmptyHint(text: "The season opens with the first Sunday at 23:59. "
                              + "Every finished week pays by where you came — 5.00 for "
                              + "a win, down to 0.10 for twentieth.")
                } else {
                    seasonTable
                }

                SectionHead(title: "HALL OF FAME",
                            trailing: weeks.isEmpty ? nil : "\(weeks.count) WEEKS")
                    .padding(.top, 10)

                if weeks.isEmpty {
                    EmptyHint(text: "No week has finished yet. Sunday midnight is when this fills up.")
                } else {
                    // The newest week stays out in the open. This list only ever
                    // grows, and the week people care about is the one that just
                    // ended, so everything before it goes behind one tap.
                    if let latest = weeks.first { weekBlock(latest) }
                    if weeks.count > 1 {
                        DisclosureGroup(isExpanded: $pastOpen) {
                            VStack(spacing: 12) {
                                ForEach(weeks.dropFirst()) { week in weekBlock(week) }
                            }
                            .padding(.top, 10)
                        } label: {
                            HStack {
                                Text("EARLIER WEEKS")
                                    .font(Theme.display(11, .heavy)).kerning(1.4)
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(weeks.count - 1)")
                                    .font(Theme.mono(10, .bold))
                                    .foregroundStyle(Theme.inkFaint)
                            }
                        }
                        .tint(Theme.inkFaint)
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background {
                            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                                .fill(Theme.surface)
                                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall,
                                                          style: .continuous)
                                    .strokeBorder(Theme.hairline))
                        }
                    }
                }

                SectionHead(title: "IRON WILL", trailing: "CONSISTENCY")
                    .padding(.top, 10)

                if session.streaks.isEmpty {
                    EmptyHint(text: "A streak day is any day you score 20 points or more.")
                } else {
                    ForEach(session.streaks.ranked) { entry in
                        StreakRow(streak: entry.value, rank: entry.index,
                                  isMe: entry.value.profileId == session.profile?.id)
                    }
                }

                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .animation(Motion.settle, value: session.history.count)
        }
        .scrollIndicators(.hidden)
        .refreshable { await session.loadHall() }
    }

    /// "S2 · WEEK 7/38 · YOU 4th" — worth reading without opening anything.
    /// During the off-season it says so instead, because the table underneath
    /// is then a finished one.
    private var seasonTrailing: String? {
        guard let info = session.seasonInfo, info.weeksDone > 0 else { return nil }
        let mine = session.season.firstIndex(where: { $0.mine }).map { $0 + 1 }
        if info.resting {
            return "OFF SEASON"
                + (mine.map { " · YOU FINISHED " + RankPoints.ordinal($0) } ?? "")
        }
        var parts: [String] = []
        if info.seasons > 1 { parts.append("S\(info.season + 1)") }
        parts.append("WEEK \(info.weeksDone)"
                     + (info.seasonWeeks.map { "/\($0)" } ?? ""))
        if let i = mine { parts.append("YOU " + RankPoints.ordinal(i)) }
        return parts.joined(separator: " · ")
    }

    /// One line under the table saying what the break means, so nobody reads a
    /// frozen table as a broken one.
    private var seasonFootnote: String? {
        guard let info = session.seasonInfo, info.resting else { return nil }
        let opens = info.nextStart.map { " Season \(info.season + 2) opens \($0)." } ?? ""
        return "The season is over — this is the final table." + opens
            + " Nothing scores towards a season until then, but the league is open"
            + " and every week still counts for the hall of fame."
    }

    private var seasonTable: some View {
        let top = max(session.season.first?.points ?? 1, 0.01)
        return VStack(spacing: 7) {
            ForEach(Array(session.season.enumerated()), id: \.element.id) { pair in
                let row = pair.element
                let place = pair.offset + 1
                seasonRow(row, place: place, share: row.points / top)
            }
            if let note = seasonFootnote {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 2).padding(.top, 2)
            }
            // Read once, then never again — so it is folded away.
            DisclosureGroup(isExpanded: $payoutOpen) {
                payoutGrid.padding(.top, 10)
            } label: {
                Text("WHAT EACH PLACE PAYS")
                    .font(Theme.display(10, .heavy)).kerning(1.4)
                    .foregroundStyle(Theme.inkFaint)
            }
            .tint(Theme.inkFaint)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall,
                                              style: .continuous)
                        .strokeBorder(Theme.hairline))
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func seasonRow(_ row: SeasonRow, place: Int, share: Double) -> some View {
        let leading = place == 1 && row.points > 0
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Text("\(place)")
                    .font(Theme.mono(13, .bold))
                    .foregroundStyle(leading ? Theme.gold : Theme.inkFaint)
                    .frame(width: 20, alignment: .trailing)
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(row.displayName)
                            .font(Theme.display(14, .bold)).kerning(0.6)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        if row.wins > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Theme.gold)
                                if row.wins > 1 {
                                    Text("×\(row.wins)")
                                        .font(Theme.mono(9, .bold))
                                        .foregroundStyle(Theme.gold)
                                }
                            }
                        }
                    }
                    Text(subtitle(row))
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(row.points == row.points.rounded()
                     ? String(Int(row.points)) : String(format: "%.1f", row.points))
                    .font(Theme.display(20, .black))
                    .foregroundStyle(Theme.gold)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline)
                    Capsule().fill(row.mine ? Theme.flame : Theme.gold)
                        .frame(width: geo.size.width * min(1, max(row.points > 0 ? 0.03 : 0, share)))
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .strokeBorder(row.mine ? Theme.flame.opacity(0.4)
                                  : leading ? Theme.gold.opacity(0.5) : Theme.hairline))
        }
    }

    private func subtitle(_ row: SeasonRow) -> String {
        guard row.weeks > 0 else { return "no finished week yet" }
        var parts = ["\(row.weeks) week" + (row.weeks == 1 ? "" : "s")]
        if let best = row.bestRank { parts.append("best " + RankPoints.ordinal(best)) }
        if row.lifetimeWins > row.wins { parts.append("\(row.lifetimeWins) all time") }
        return parts.joined(separator: " · ")
    }

    private var payoutGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5),
                                     count: 5), spacing: 5) {
                ForEach(Array(RankPoints.table.enumerated()), id: \.offset) { pair in
                    VStack(spacing: 2) {
                        Text(RankPoints.ordinal(pair.offset + 1))
                            .font(Theme.display(9, .heavy)).kerning(0.8)
                            .foregroundStyle(Theme.inkFaint)
                        Text(String(format: "%.2f", pair.element))
                            .font(Theme.mono(12, .bold))
                            .foregroundStyle(pair.offset == 0 ? Theme.gold : Theme.ink)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.raised)
                            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(pair.offset == 0 ? Theme.gold.opacity(0.5)
                                              : Theme.hairline))
                    }
                }
            }
            Text("21st and below score nothing. A win is worth 39% more than "
                 + "second, and climbing from 16th to 11th more than doubles your week.")
                .font(.caption2)
                .foregroundStyle(Theme.inkFaint)
        }
    }

    @ViewBuilder
    private func weekBlock(_ week: Week) -> some View {
        let open = openWeek == week.id
        let champ = week.rows.first

        VStack(spacing: 0) {
            Button {
                Haptic.tap()
                withAnimation(Motion.settle) { openWeek = open ? nil : week.id }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Theme.gold.opacity(0.16))
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.gold)
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(champ?.displayName ?? "No entries")
                            .font(Theme.display(17, .black))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text(week.label)
                            .font(Theme.mono(10))
                            .foregroundStyle(Theme.inkFaint)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: -1) {
                        Text("\(Int(champ?.points ?? 0))")
                            .font(Theme.display(19, .black))
                            .foregroundStyle(Theme.gold)
                        Text("PTS").font(Theme.display(8, .heavy)).kerning(1)
                            .foregroundStyle(Theme.inkFaint)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(spacing: 4) {
                    ForEach(week.rows.ranked) { entry in
                        let row = entry.value
                        HStack(spacing: 10) {
                            Text("\(entry.index)")
                                .font(Theme.display(12, .black))
                                .foregroundStyle(place(entry.index))
                                .frame(width: 18, alignment: .leading)
                            Mark(spec: row.avatar, name: row.displayName)
                                .frame(width: 22, height: 22)
                            Text(row.displayName)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(row.profileId == session.profile?.id
                                                 ? Theme.flame : Theme.ink)
                                .lineLimit(1)
                            Spacer()
                            Text("\(row.entries) entries")
                                .font(.caption2).foregroundStyle(Theme.inkFaint)
                            Text("\(Int(row.points))")
                                .font(Theme.mono(12, .bold))
                                .foregroundStyle(Theme.inkMuted)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(open ? Theme.gold.opacity(0.4) : Theme.hairline))
        }
    }

    private func place(_ rank: Int) -> Color {
        switch rank {
        case 1: return Theme.gold
        case 2: return Theme.silver
        case 3: return Theme.bronze
        default: return Theme.inkFaint
        }
    }

    /// "2026-09-07" → "WEEK OF 7 SEP"
    private static func label(_ iso: String) -> String {
        let parse = DateFormatter()
        parse.dateFormat = "yyyy-MM-dd"
        parse.timeZone = Config.timeZone
        guard let d = parse.date(from: String(iso.prefix(10))) else { return iso }
        let out = DateFormatter()
        out.dateFormat = "d MMM yyyy"
        out.timeZone = Config.timeZone
        return "WEEK OF \(out.string(from: d).uppercased())"
    }
}

/// One row of the streak table. The flame is lit while the run is alive.
struct StreakRow: View {
    let streak: Streak
    let rank: Int
    let isMe: Bool

    private var hot: Bool { streak.currentStreak >= 3 }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(Theme.display(16, .black)).italic()
                .foregroundStyle(Theme.inkFaint)
                .frame(width: 20, alignment: .leading)

            Mark(spec: streak.avatar, name: streak.displayName)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(streak.displayName)
                    .font(Theme.display(15, .heavy))
                    .foregroundStyle(isMe ? Theme.flame : Theme.ink)
                    .lineLimit(1)
                Text("best \(streak.bestStreak) · \(streak.activeDays) active days")
                    .font(.caption2).foregroundStyle(Theme.inkFaint)
            }

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: hot ? "flame.fill" : "flame")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(hot ? Theme.ember : Theme.inkFaint)
                    .symbolEffect(.pulse, options: hot ? .repeating : .nonRepeating,
                                  value: streak.currentStreak)
                Text("\(streak.currentStreak)")
                    .font(Theme.display(20, .black))
                    .foregroundStyle(hot ? Theme.ember : Theme.inkMuted)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .strokeBorder(isMe ? Theme.flame.opacity(0.45) : Theme.hairline))
        }
    }
}
