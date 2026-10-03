import SwiftUI

/// An account with no league at all.
///
/// This used to be routed into onboarding, which is wrong in a way that only
/// shows up once somebody actually leaves: the person already HAS a profile —
/// a name, a rank, a restore code, a shop full of things they picked — and
/// being handed a "pick a fighter name" screen says all of that is gone. It
/// is not. The leagues tab on its own says the true thing instead: you are
/// between leagues, here is the door back in, and here is everything of yours
/// that is still sitting where you left it.
struct NoLeagueView: View {
    @Environment(Session.self) private var session

    var body: some View {
        VStack(spacing: 0) {
            header
            LeaguesView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NO LEAGUE")
                .font(Theme.display(11, .black)).kerning(1.8)
                .foregroundStyle(Theme.inkFaint)
            Text(session.profile?.displayName ?? "You")
                .font(Theme.display(28, .black)).italic()
                .foregroundStyle(Theme.ink)
            Text("Nothing is lost — your rank follows you, not a league. Join one with a code, or start your own.")
                .font(.caption).foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
}
