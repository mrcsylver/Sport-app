import SwiftUI

@main
struct IronLeagueApp: App {
    @State private var session = Session()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .preferredColorScheme(.dark)
                .task { await session.boot() }
        }
    }
}
