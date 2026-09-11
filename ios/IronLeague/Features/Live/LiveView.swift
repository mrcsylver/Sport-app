import SwiftUI

/// The screen people open the app for. Rules it follows:
///  · the table is visible without scrolling
///  · rows animate to their new position when points change, so a rank
///    change is something you *see* happen rather than discover
///  · everything else folds away
struct LiveView: View {
    @Environment(Session.self) private var session
    @State private var expanded: UUID?
    @State private var showWeekly = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10, pinnedViews: []) {
                WeeklyStrip(open: $showWeekly)
                    .padding(.horizontal, 16)

                SectionHead(title: "LIVE STANDINGS",
                            trailing: session.isRefreshing ? "SYNCING" : nil)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                if session.standings.isEmpty {
                    EmptyHint(text: "Nobody has logged anything yet. Be the first.")
                        .padding(.horizontal, 16)
                } else if session.divisions.isEmpty {
                    ForEach(ranked.ranked) { entry in
                        row(entry.value, rank: entry.index, division: nil)
                    }
                } else {
                    ForEach(session.divisions) { group in
                        DivisionHeader(division: group.division, count: group.rows.count,
                                       containsMe: group.rows.contains {
                                           $0.profileId == session.profile?.id })
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                        ForEach(group.rows.ranked) { entry in
                            row(entry.value, rank: entry.index, division: group.division)
                        }
                    }
                }

                Color.clear.frame(height: 24)
            }
            .padding(.top, 12)
            .animation(Motion.arrive, value: session.standings.map(\.points))
        }
        .scrollIndicators(.hidden)
        .refreshable { await session.refresh() }
    }

    private var ranked: [Standing] {
        session.standings.sorted { $0.points > $1.points }
    }

    @ViewBuilder
    private func row(_ s: Standing, rank: Int, division: Division?) -> some View {
        StandingRow(
            standing: s,
            rank: rank,
            division: division,
            isMe: s.profileId == session.profile?.id,
            isOpen: expanded == s.profileId,
            feed: session.feeds[s.profileId] ?? []
        ) {
            Haptic.tap()
            withAnimation(Motion.settle) {
                expanded = expanded == s.profileId ? nil : s.profileId
            }
            if expanded == s.profileId {
                Task { await session.loadFeed(s.profileId) }
            }
        }
        .padding(.horizontal, 16)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.96).combined(with: .opacity),
            removal: .opacity))
    }
}

struct EmptyHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.inkFaint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }
}

struct DivisionHeader: View {
    let division: Division
    let count: Int
    var containsMe: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: division.symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.metal(division))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("\(division.title) DIVISION")
                        .font(Theme.display(16, .black)).italic().kerning(1.6)
                        .foregroundStyle(Theme.metal(division))
                    if containsMe {
                        Text("· YOU").font(Theme.display(9, .heavy))
                            .foregroundStyle(Theme.metal(division).opacity(0.7))
                    }
                }
                Text(division.subtitle)
                    .font(.caption2).foregroundStyle(Theme.inkFaint)
            }
            Spacer()
            Text("\(count)")
                .font(Theme.mono(12, .bold))
                .foregroundStyle(Theme.metal(division).opacity(0.7))
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.metal(division).opacity(0.55)).frame(height: 2)
        }
    }
}
