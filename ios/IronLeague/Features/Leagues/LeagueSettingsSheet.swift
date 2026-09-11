import SwiftUI

/// What the person who made a league gets to decide: when it rests, how long
/// the season runs, and what it looks like. The server checks ownership on
/// every one of these — this screen only exists for the people it applies to.
struct LeagueSettingsSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var rest: Set<Int> = [7]
    @State private var catchup: Int?
    @State private var weeks: Double = 12
    @State private var endless = true

    /// ISO weekdays: 1 is Monday, 7 is Sunday, matching the server.
    private struct Weekday: Identifiable {
        let number: Int
        let title: String
        var id: Int { number }
    }

    private static let days = [Weekday(number: 1, title: "MON"),
                               Weekday(number: 2, title: "TUE"),
                               Weekday(number: 3, title: "WED"),
                               Weekday(number: 4, title: "THU"),
                               Weekday(number: 5, title: "FRI"),
                               Weekday(number: 6, title: "SAT"),
                               Weekday(number: 7, title: "SUN")]

    private var league: League? { session.league }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    crestSection
                    restSection
                    catchupSection
                    seasonSection
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .background(Theme.void.opacity(0.6))
            .navigationTitle(league?.name ?? "League")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.display(15, .bold))
                        .foregroundStyle(Theme.flame)
                }
            }
        }
        .onAppear {
            rest = Set(league?.restDow ?? [7])
            catchup = league?.catchupDow
            if let w = league?.seasonWeeks {
                weeks = Double(w)
                endless = false
            } else {
                endless = true
            }
        }
    }

    // MARK: crest

    private var crestSection: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Crest(league: league, size: 62)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("THE CREST")
                            .font(Theme.display(9, .heavy)).kerning(1.6)
                            .foregroundStyle(Theme.inkFaint)
                        Text("A shape, a metal and a mark. Never a face — those belong to players.")
                            .font(.caption).foregroundStyle(Theme.inkMuted)
                    }
                }

                label("SHAPE")
                HStack(spacing: 7) {
                    ForEach(CrestShape.allCases, id: \.self) { shape in
                        Button {
                            save { $0.shape = shape.rawValue }
                        } label: {
                            Text(shape.title)
                                .font(Theme.display(9, .heavy)).kerning(0.6)
                                .foregroundStyle(current(\.shape) == shape.rawValue
                                                 ? Theme.void : Theme.inkMuted)
                                .frame(maxWidth: .infinity).padding(.vertical, 9)
                                .background {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(current(\.shape) == shape.rawValue
                                              ? AnyShapeStyle(Theme.heat)
                                              : AnyShapeStyle(Theme.raised))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                label("METAL")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 7)], spacing: 7) {
                    ForEach(Tint.emblem.dropFirst()) { swatch in
                        Button {
                            save { $0.color = swatch.key }
                        } label: {
                            Circle()
                                .fill(swatch.color)
                                .frame(height: 26)
                                .overlay(Circle().strokeBorder(
                                    current(\.color) == swatch.key ? Theme.ink : Theme.hairline,
                                    lineWidth: current(\.color) == swatch.key ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }

                label("MARK · \(IconSet.crests.count) TO CHOOSE FROM")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 7)], spacing: 7) {
                    ForEach(IconSet.crests, id: \.self) { key in
                        let chosen = current(\.emblem) == key
                        Button {
                            save { $0.emblem = key }
                        } label: {
                            GameIcon(key: key)
                                .foregroundStyle(Theme.inkMuted)
                                .padding(8)
                                .frame(height: 48)
                                .frame(maxWidth: .infinity)
                                .background {
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(chosen ? Theme.flame.opacity(0.16) : Theme.raised)
                                        .overlay(RoundedRectangle(cornerRadius: 9)
                                            .strokeBorder(chosen ? Theme.flame : .clear,
                                                          lineWidth: 1.5))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                label("LEAGUE BANNER")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(SkinCatalog.league) { skin in
                        SkinSwatch(skin: skin, selected: current(\.skin) == skin.key) {
                            save { $0.skin = skin.key }
                        }
                    }
                }
            }
        }
    }

    // MARK: rest days

    private var restSection: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                Text("REST DAYS")
                    .font(Theme.display(10, .heavy)).kerning(1.6)
                    .foregroundStyle(Theme.inkFaint)
                Text("On a rest day only a stretch counts, and only once. Three at most — a league that rests four days is not a league.")
                    .font(.caption).foregroundStyle(Theme.inkMuted)

                HStack(spacing: 5) {
                    ForEach(Self.days) { day in
                        let on = rest.contains(day.number)
                        Button {
                            Haptic.tap()
                            withAnimation(Motion.tap) {
                                if on { rest.remove(day.number) }
                                else if rest.count < 3 { rest.insert(day.number) }
                                else { session.show("Three rest days is the limit.") }
                            }
                        } label: {
                            Text(day.title)
                                .font(Theme.display(9, .heavy))
                                .foregroundStyle(on ? Theme.void : Theme.inkMuted)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(on ? AnyShapeStyle(Theme.jade)
                                                 : AnyShapeStyle(Theme.raised))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: the catch-up day

    /// One day a week where being behind is worth something. It is not a
    /// handicap — the leader still trains and still scores — it is a reason
    /// for somebody four days down to turn up rather than write the week off.
    private var catchupSection: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                Text("CATCH-UP DAY")
                    .font(Theme.display(10, .heavy)).kerning(1.6)
                    .foregroundStyle(Theme.inkFaint)
                Text("Everything logged that day is multiplied by how far off the lead you are — up to ×1.4 at 500 points back, nothing inside 150. Nobody loses anything, and it cannot be a rest day.")
                    .font(.caption).foregroundStyle(Theme.inkMuted)

                HStack(spacing: 5) {
                    ForEach(Self.days) { day in
                        let blocked = rest.contains(day.number)
                        let on = catchup == day.number
                        Button {
                            guard !blocked else { return }
                            Haptic.tap()
                            withAnimation(Motion.tap) {
                                catchup = on ? nil : day.number
                            }
                        } label: {
                            Text(day.title)
                                .font(Theme.display(9, .heavy))
                                .foregroundStyle(on ? Theme.void : Theme.inkMuted)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background {
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(on ? AnyShapeStyle(Theme.diamond)
                                                 : AnyShapeStyle(Theme.raised))
                                }
                                .opacity(blocked ? 0.3 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(blocked)
                    }
                }

                if catchup == nil {
                    Text("No catch-up day. Every day scores the same.")
                        .font(.caption2).foregroundStyle(Theme.inkFaint)
                }
            }
        }
    }

    // MARK: season

    private var seasonSection: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                Text("SEASON LENGTH")
                    .font(Theme.display(10, .heavy)).kerning(1.6)
                    .foregroundStyle(Theme.inkFaint)

                Toggle(isOn: $endless) {
                    Text("Keep going forever")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.flame)

                if !endless {
                    HStack {
                        Text("\(Int(weeks)) weeks")
                            .font(Theme.display(20, .black))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text(weeks >= 26 ? "six months — the maximum"
                                         : "about \(Int((weeks / 4.34).rounded())) months")
                            .font(.caption).foregroundStyle(Theme.inkFaint)
                    }
                    Slider(value: $weeks, in: 1...26, step: 1)
                        .tint(Theme.flame)
                }

                HeatButton(title: "SAVE SETTINGS", systemImage: "checkmark") {
                    Task {
                        await session.saveLeagueSettings(
                            restDow: rest.sorted(),
                            seasonWeeks: endless ? nil : Int(weeks),
                            catchupDow: catchup)
                    }
                }
            }
        }
    }

    // MARK: helpers

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Theme.display(9, .heavy)).kerning(1.4)
            .foregroundStyle(Theme.inkFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    private func current(_ path: KeyPath<League.Badge, String?>) -> String? {
        league?.badge?[keyPath: path]
    }

    /// Every crest control edits one field of the badge and saves the whole
    /// thing, so the other fields are never lost by a partial write.
    private func save(_ edit: (inout League.Badge) -> Void) {
        Haptic.tap()
        var badge = league?.badge ?? League.Badge()
        edit(&badge)
        Task { await session.saveCrest(badge) }
    }
}
