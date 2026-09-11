import SwiftUI

/// The shop. Everything in it is already yours — this is where the cosmetics
/// that exist are shown as things you can choose rather than buried in a
/// settings screen, and where paid ones will slot in when there are any.
///
/// Three shelves, matching the three kinds of thing the app can wear.
struct ShopSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var shelf: Shelf = .emblems

    private enum Shelf: String, CaseIterable, Identifiable {
        case emblems, banners, crests
        var id: String { rawValue }
        var title: String {
            switch self {
            case .emblems: return "EMBLEMS"
            case .banners: return "BANNERS"
            case .crests:  return "CRESTS"
            }
        }
        var blurb: String {
            switch self {
            case .emblems: return "\(IconSet.avatars.count) marks and \(Tint.emblem.count) tints — that is over a thousand combinations, and no two people need look alike."
            case .banners: return "\(SkinCatalog.player.count) for a person, \(SkinCatalog.league.count) for a league. All drawn, none downloaded."
            case .crests:  return "\(IconSet.crests.count) heraldic marks across \(CrestShape.allCases.count) shapes. Only the person who made a league can change its crest."
            }
        }
    }

    private var isOwner: Bool { session.league?.ownerId == session.profile?.id }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    shelves

                    Panel(padding: 14, tint: Theme.gold) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(shelf.title)
                                .font(Theme.display(15, .black)).italic()
                                .foregroundStyle(Theme.gold)
                            Text(shelf.blurb)
                                .font(.caption).foregroundStyle(Theme.inkMuted)
                        }
                    }

                    switch shelf {
                    case .emblems: emblems
                    case .banners: banners
                    case .crests:  crests
                    }

                    comingSoon

                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .animation(Motion.settle, value: shelf)
            }
            .background(Theme.void.opacity(0.6))
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.display(15, .bold))
                        .foregroundStyle(Theme.flame)
                }
            }
        }
    }

    private var shelves: some View {
        HStack(spacing: 8) {
            ForEach(Shelf.allCases) { s in
                Button {
                    Haptic.tap()
                    withAnimation(Motion.tap) { shelf = s }
                } label: {
                    Text(s.title)
                        .font(Theme.display(12, .black)).kerning(1)
                        .foregroundStyle(shelf == s ? Theme.void : Theme.inkMuted)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(shelf == s ? AnyShapeStyle(Theme.heat)
                                                 : AnyShapeStyle(Theme.raised))
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emblems: some View {
        EmblemPicker(current: session.profile?.avatar) { spec in
            Task { await session.setAvatar(spec) }
        }
    }

    private var banners: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                shelfLabel("YOURS TO WEAR")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(SkinCatalog.player) { skin in
                        SkinSwatch(skin: skin, selected: session.profile?.banner == skin.key) {
                            Task { await session.setBanner(skin.key) }
                        }
                    }
                }
            }

            VStack(spacing: 8) {
                shelfLabel(isOwner ? "FOR YOUR LEAGUE" : "FOR A LEAGUE YOU RUN")
                if !isOwner {
                    Text("You did not make the league you are looking at, so these are shown but not yours to set.")
                        .font(.caption2).foregroundStyle(Theme.inkFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(SkinCatalog.league) { skin in
                        SkinSwatch(skin: skin,
                                   selected: session.league?.badge?.skin == skin.key) {
                            guard isOwner else {
                                session.show("Only the person who made a league can change it.")
                                return
                            }
                            var badge = session.league?.badge ?? League.Badge()
                            badge.skin = skin.key
                            Task { await session.saveCrest(badge) }
                        }
                    }
                }
                .opacity(isOwner ? 1 : 0.55)
            }
        }
    }

    private var crests: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                ForEach(CrestShape.allCases, id: \.self) { shape in
                    VStack(spacing: 6) {
                        ZStack {
                            shape.silhouette
                                .fill(LinearGradient(colors: [Theme.gold, Theme.gold.opacity(0.4)],
                                                     startPoint: .top, endPoint: .bottom))
                            GameIcon(key: "laurel-crown")
                                .foregroundStyle(Theme.void.opacity(0.75))
                                .padding(11)
                        }
                        .frame(width: 46, height: 46)
                        Text(shape.title)
                            .font(Theme.display(8, .heavy)).kerning(0.6)
                            .foregroundStyle(Theme.inkFaint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 6)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 7)], spacing: 7) {
                ForEach(IconSet.crests, id: \.self) { key in
                    GameIcon(key: key)
                        .foregroundStyle(Theme.inkMuted)
                        .padding(8)
                        .frame(height: 48)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.raised))
                }
            }

            Text(isOwner
                 ? "Set your league's crest in League Settings."
                 : "A crest belongs to whoever made the league.")
                .font(.caption2).foregroundStyle(Theme.inkFaint)
        }
    }

    /// The placeholder shelf. It exists so the shape of the thing is agreed
    /// now rather than bolted on later — nothing here charges anybody.
    private var comingSoon: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ELEMENTS TO COME")
                    .font(Theme.display(9, .heavy)).kerning(1.6)
                    .foregroundStyle(Theme.inkFaint)
                ForEach(Self.planned) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkFaint)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(Theme.display(12, .heavy))
                                .foregroundStyle(Theme.inkMuted)
                            Text(item.detail)
                                .font(.caption2).foregroundStyle(Theme.inkFaint)
                        }
                        Spacer()
                        Chip(text: "SOON", color: Theme.inkFaint)
                    }
                }
            }
        }
    }

    private struct Planned: Identifiable {
        let title: String
        let detail: String
        var id: String { title }
    }

    private static let planned = [
        Planned(title: "LEAGUE HOST PASS",
                detail: "Run a league bigger than thirty, with its own season rules."),
        Planned(title: "TOURNAMENT ENTRY",
                detail: "A pooled prize between leagues. US only at first, where the law is clear."),
        Planned(title: "MERCH",
                detail: "Real things, shipped — a shirt for the people who actually turned up.")
    ]

    private func shelfLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.display(9, .heavy)).kerning(1.4)
            .foregroundStyle(Theme.inkFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
