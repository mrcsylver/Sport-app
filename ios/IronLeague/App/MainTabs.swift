import SwiftUI

/// Five destinations, a custom bar so it can carry the log button in the
/// middle the way a training app should — the thing you open the app to do
/// is never more than one thumb-reach away.
struct MainTabs: View {
    @Environment(Session.self) private var session
    @State private var tab: Tab = .live
    @State private var showingLog = false
    @Namespace private var indicator

    enum Tab: String, CaseIterable, Identifiable {
        case live, duels, hall, stats, leagues
        var id: String { rawValue }
        var title: String {
            switch self {
            case .live: return "LIVE"; case .duels: return "DUELS"
            case .hall: return "HALL"; case .stats: return "STATS"
            case .leagues: return "LEAGUES"
            }
        }
        var symbol: String {
            switch self {
            case .live: return "chart.bar.fill"
            case .duels: return "flame.fill"
            case .hall: return "crown.fill"
            case .stats: return "chart.xyaxis.line"
            case .leagues: return "person.3.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            LeagueHeader()

            ZStack {
                switch tab {
                case .live:    LiveView()
                case .duels:   DuelsView()
                case .hall:    HallView()
                case .stats:   StatsView()
                case .leagues: LeaguesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(tab: $tab, indicator: indicator) { showingLog = true }
        }
        .sheet(isPresented: $showingLog) {
            LogSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        // Each tab loads its own data the first time it is opened, so the
        // launch only ever pays for the leaderboard.
        .task(id: tab) {
            switch tab {
            case .duels: await session.loadDuelsTab()
            case .hall:  await session.loadHall()
            case .stats: await session.loadStats()
            default: break
            }
        }
        .task(id: session.leagueId) {
            // switching league invalidates every tab's data, not just LIVE
            switch tab {
            case .duels: await session.loadDuelsTab()
            case .hall:  await session.loadHall()
            case .stats: await session.loadStats()
            default: break
            }
        }
    }
}

private struct TabBar: View {
    @Binding var tab: MainTabs.Tab
    var indicator: Namespace.ID
    var onLog: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            item(.live); item(.duels)
            logButton
            item(.stats); item(.leagues)
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
        .background {
            Rectangle().fill(.ultraThinMaterial)
                .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var logButton: some View {
        Button(action: onLog) {
            ZStack {
                Circle().fill(Theme.heat)
                    .shadow(color: Theme.flame.opacity(0.55), radius: 14, y: 4)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)
            .offset(y: -14)
        }
        .pressable(scale: 0.9)
        .frame(maxWidth: .infinity)
    }

    private func item(_ t: MainTabs.Tab) -> some View {
        Button {
            Haptic.tap()
            withAnimation(Motion.tap) { tab = t }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: t.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolEffect(.bounce, value: tab == t)
                Text(t.title)
                    .font(Theme.display(9, .heavy)).kerning(0.6)
            }
            .foregroundStyle(tab == t ? Theme.ink : Theme.inkFaint)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 6)
            .overlay(alignment: .top) {
                if tab == t {
                    Capsule().fill(Theme.flame).frame(width: 22, height: 3)
                        .offset(y: -8)
                        .matchedGeometryEffect(id: "tab", in: indicator)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
