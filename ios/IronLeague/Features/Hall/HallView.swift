import SwiftUI

/// What already happened. Finished weeks first, because a league's history is
/// the thing that makes this week matter, then Iron Will — the streak table,
/// which rewards turning up rather than turning up big.
struct HallView: View {
    @Environment(Session.self) private var session
    @State private var openWeek: String?

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

    private struct Title: Identifiable {
        let name: String
        let wins: Int
        var id: String { name }
    }

    /// Who has won the most weeks — the only all-time table worth having.
    private var titles: [Title] {
        var count: [String: Int] = [:]
        for w in weeks { if let champ = w.rows.first { count[champ.displayName, default: 0] += 1 } }
        return count
            .sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }
            .map { Title(name: $0.key, wins: $0.value) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                SectionHead(title: "HALL OF FAME",
                            trailing: weeks.isEmpty ? nil : "\(weeks.count) WEEKS")

                if weeks.isEmpty {
                    EmptyHint(text: "No week has finished yet. Sunday midnight is when this fills up.")
                } else {
                    if titles.count > 1 { titleBar }
                    ForEach(weeks) { week in weekBlock(week) }
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

    private var titleBar: some View {
        Panel(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("WEEKS WON")
                    .font(Theme.display(9, .heavy)).kerning(1.6)
                    .foregroundStyle(Theme.inkFaint)
                HStack(spacing: 8) {
                    ForEach(titles.prefix(4)) { title in
                        HStack(spacing: 5) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.gold)
                            Text(title.name)
                                .font(Theme.display(12, .heavy))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Text("×\(title.wins)")
                                .font(Theme.mono(10, .bold))
                                .foregroundStyle(Theme.gold)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Capsule().fill(Theme.gold.opacity(0.12)))
                    }
                }
            }
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
