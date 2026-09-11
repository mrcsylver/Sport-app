import SwiftUI

/// Your own numbers, ordered by what a person actually asks: what rank am I,
/// how far to the next one, what have I been doing, and what have I earned.
/// Badges fold away — there are eleven of them and they are not the headline.
struct StatsView: View {
    @Environment(Session.self) private var session
    @State private var openBadges = false
    @State private var openCat: String?

    private var lifetime: Double { session.me?.lifetime ?? 0 }
    private var grade: Grade? { Grade.reached(lifetime) }
    private var next: Grade? { Grade.next(lifetime) }

    private var weekPoints: Double { session.stats.reduce(0) { $0 + $1.totalPoints } }
    private var weekEntries: Int { session.stats.reduce(0) { $0 + $1.entries } }
    private var activeDays: Int { session.stats.map(\.activeDays).max() ?? 0 }

    private struct CategoryTotal: Identifiable {
        let name: String
        let points: Double
        var id: String { name }
    }

    private var byCategory: [CategoryTotal] {
        var total: [String: Double] = [:]
        for row in session.stats { total[row.category, default: 0] += row.totalPoints }
        return total.sorted { $0.value > $1.value }
            .map { CategoryTotal(name: $0.key, points: $0.value) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                gradeCard
                ladder
                scopeToggle
                totals

                if !byCategory.isEmpty {
                    SectionHead(title: "WHERE IT CAME FROM")
                    Panel(padding: 14) {
                        VStack(spacing: 10) {
                            ForEach(byCategory) { row in
                                categoryBar(row.name, row.points)
                            }
                        }
                    }
                }

                if !session.stats.isEmpty {
                    SectionHead(title: "EVERY EXERCISE", trailing: "\(session.stats.count)")
                    ForEach(byCategory) { row in
                        exerciseFolder(row.name)
                    }
                } else {
                    EmptyHint(text: session.statsAllTime
                              ? "Nothing logged in this league yet."
                              : "Nothing logged this week yet.")
                }

                badgeSection

                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .animation(Motion.settle, value: session.stats.count)
        }
        .scrollIndicators(.hidden)
        .refreshable { await session.loadStats() }
    }

    // MARK: rank

    private var gradeCard: some View {
        Panel(tint: grade.map { Grade.color(tier: $0.tier) }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOUR GRADE")
                            .font(Theme.display(9, .heavy)).kerning(1.6)
                            .foregroundStyle(Theme.inkFaint)
                        Text(grade?.name ?? "UNRANKED")
                            .font(Theme.display(30, .black)).italic().kerning(0.5)
                            .foregroundStyle(grade.map { Grade.color(tier: $0.tier) } ?? Theme.inkMuted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: -2) {
                        RollingNumber(value: lifetime, font: Theme.display(26, .black))
                        Text("LIFETIME PTS")
                            .font(Theme.display(8, .heavy)).kerning(1)
                            .foregroundStyle(Theme.inkFaint)
                    }
                }

                if let n = next {
                    let floor = grade?.at ?? 0
                    let span = max(1, n.at - floor)
                    HeatBar(progress: (lifetime - floor) / span, height: 10)
                        .animation(Motion.arrive, value: lifetime)
                    HStack {
                        Text("NEXT · \(n.name)")
                            .font(Theme.display(11, .heavy)).kerning(0.8)
                            .foregroundStyle(Grade.color(tier: n.tier))
                        Spacer()
                        Text("\(Int(max(0, n.at - lifetime))) points to go")
                            .font(.caption).foregroundStyle(Theme.inkMuted)
                    }
                } else {
                    Text("ETERNAL. There is nothing above this.")
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.jade)
                }
            }
        }
    }

    /// The whole ladder, so the next milestone is never a mystery — 25 rungs
    /// from Spark to Eternal at fifty thousand.
    private var ladder: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Grade.ladder) { g in
                        let reached = lifetime >= g.at
                        let current = grade?.name == g.name
                        VStack(spacing: 3) {
                            Text(g.name)
                                .font(Theme.display(9, .heavy)).kerning(0.4)
                            Text(g.at >= 1000 ? "\(Int(g.at / 1000))K" : "\(Int(g.at))")
                                .font(Theme.mono(11, .bold))
                        }
                        .foregroundStyle(reached ? Grade.color(tier: g.tier) : Theme.inkFaint)
                        .padding(.horizontal, 10).padding(.vertical, 9)
                        .background {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(reached ? Grade.color(tier: g.tier).opacity(0.14) : Theme.surface)
                                .overlay(RoundedRectangle(cornerRadius: 9)
                                    .strokeBorder(current ? Grade.color(tier: g.tier) : .clear,
                                                  lineWidth: 1.5))
                        }
                        .id(g.id)
                    }
                }
                .padding(.horizontal, 2)
            }
            .onAppear {
                // open on the rung you are working towards, not on Spark
                if let i = Grade.ladder.firstIndex(where: { lifetime < $0.at }) {
                    let target = Grade.ladder[max(0, i - 1)]
                    withAnimation(Motion.settle) { proxy.scrollTo(target.id, anchor: .center) }
                }
            }
        }
    }

    // MARK: scope

    private var scopeToggle: some View {
        HStack(spacing: 8) {
            scopeTab("THIS WEEK", false)
            scopeTab("ALL TIME", true)
        }
    }

    private func scopeTab(_ title: String, _ all: Bool) -> some View {
        Button {
            Haptic.tap()
            session.statsAllTime = all
            Task { await session.loadStats() }
        } label: {
            Text(title)
                .font(Theme.display(12, .black)).kerning(1)
                .foregroundStyle(session.statsAllTime == all ? Theme.void : Theme.inkMuted)
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(session.statsAllTime == all
                              ? AnyShapeStyle(Theme.heat) : AnyShapeStyle(Theme.raised))
                }
        }
        .buttonStyle(.plain)
    }

    private var totals: some View {
        HStack(spacing: 10) {
            tile("POINTS", weekPoints, Theme.flame)
            tile("ENTRIES", Double(weekEntries), Theme.azure)
            tile("ACTIVE DAYS", Double(activeDays), Theme.jade)
        }
    }

    private func tile(_ label: String, _ value: Double, _ colour: Color) -> some View {
        VStack(spacing: 2) {
            RollingNumber(value: value, font: Theme.display(22, .black), color: colour)
            Text(label)
                .font(Theme.display(8, .heavy)).kerning(0.9)
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .strokeBorder(Theme.hairline))
        }
    }

    private func categoryBar(_ cat: String, _ points: Double) -> some View {
        let top = byCategory.first?.points ?? 1
        return HStack(spacing: 10) {
            Image(systemName: CategoryArt.symbol(cat))
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkMuted)
                .frame(width: 18)
            Text(cat)
                .font(Theme.display(11, .heavy)).kerning(0.6)
                .foregroundStyle(Theme.inkMuted)
                .frame(width: 64, alignment: .leading)
            HeatBar(progress: top > 0 ? points / top : 0, height: 7)
            Text("\(Int(points))")
                .font(Theme.mono(11, .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func exerciseFolder(_ cat: String) -> some View {
        let rows = session.stats.filter { $0.category == cat }
            .sorted { $0.totalPoints > $1.totalPoints }
        let open = openCat == cat

        VStack(spacing: 0) {
            Button {
                Haptic.tap()
                withAnimation(Motion.settle) { openCat = open ? nil : cat }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: CategoryArt.symbol(cat))
                        .font(.system(size: 13))
                        .foregroundStyle(open ? Theme.flame : Theme.inkMuted)
                        .frame(width: 18)
                    Text(cat)
                        .font(Theme.display(14, .black)).kerning(0.8)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(rows.count)")
                        .font(Theme.mono(10)).foregroundStyle(Theme.inkFaint)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(spacing: 5) {
                    ForEach(rows) { row in
                        HStack(spacing: 8) {
                            Text(session.exercise(row.exerciseKey)?.name ?? row.exerciseKey)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(volume(row))
                                .font(Theme.mono(10))
                                .foregroundStyle(Theme.inkFaint)
                            Text("\(Int(row.totalPoints))")
                                .font(Theme.display(13, .bold))
                                .foregroundStyle(Theme.flame)
                                .frame(width: 46, alignment: .trailing)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .strokeBorder(Theme.hairline))
        }
    }

    private func volume(_ row: StatRow) -> String {
        let n = row.totalAmount == row.totalAmount.rounded()
            ? String(Int(row.totalAmount))
            : String(format: "%.1f", row.totalAmount)
        switch row.mode {
        case "reps":    return "\(n) reps · \(row.entries) sets"
        case "seconds": return "\(n)s"
        case "minutes": return "\(n) min"
        case "km":      return "\(n) km"
        default:        return "\(row.entries)×"
        }
    }

    // MARK: badges

    private var badgeSection: some View {
        VStack(spacing: 10) {
            Button {
                Haptic.tap()
                withAnimation(Motion.settle) { openBadges.toggle() }
            } label: {
                HStack {
                    SectionHead(title: "BADGES",
                                trailing: "\(session.badges.filter(\.earned).count)/\(session.badges.count)")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                        .rotationEffect(.degrees(openBadges ? 180 : 0))
                        .padding(.leading, 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if openBadges {
                VStack(spacing: 10) {
                    Text("Tap an earned badge to wear it beside your name. Three at most.")
                        .font(.caption2).foregroundStyle(Theme.inkFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)],
                              spacing: 8) {
                        ForEach(session.badges) { badge in
                            BadgeTile(badge: badge,
                                      pinned: (session.profile?.pinnedBadges ?? []).contains(badge.key)) {
                                pin(badge)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 8)
    }

    private func pin(_ badge: BadgeRow) {
        guard badge.earned else {
            session.show("Earn it first: \(badge.descr.lowercased()).")
            return
        }
        var worn = session.profile?.pinnedBadges ?? []
        if let i = worn.firstIndex(of: badge.key) {
            worn.remove(at: i)
        } else {
            guard worn.count < 3 else {
                session.show("Three badges on show at a time — take one off first.")
                Haptic.refuse()
                return
            }
            worn.append(badge.key)
        }
        Task { await session.setPinnedBadges(worn) }
    }
}

struct BadgeTile: View {
    let badge: BadgeRow
    let pinned: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            VStack(spacing: 5) {
                GameIcon(key: BadgeArt.icon(badge.key))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(badge.earned ? Theme.gold : Theme.inkFaint)
                Text(badge.name)
                    .font(Theme.display(10, .heavy)).kerning(0.6)
                    .foregroundStyle(badge.earned ? Theme.ink : Theme.inkMuted)
                    .multilineTextAlignment(.center)
                Text(badge.descr)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.inkFaint)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if !badge.earned {
                    HeatBar(progress: badge.fraction, height: 3)
                        .padding(.top, 2)
                    Text("\(Int(badge.progress))/\(Int(badge.target))")
                        .font(Theme.mono(8))
                        .foregroundStyle(Theme.inkFaint)
                } else if pinned {
                    Text("WORN")
                        .font(Theme.display(8, .heavy)).kerning(1)
                        .foregroundStyle(Theme.gold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 9).padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(pinned ? Theme.gold.opacity(0.12) : Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                        .strokeBorder(pinned ? Theme.gold.opacity(0.7) : Theme.hairline))
            }
            .opacity(badge.earned ? 1 : 0.62)
        }
        .buttonStyle(.plain)
        .pressable()
    }
}
