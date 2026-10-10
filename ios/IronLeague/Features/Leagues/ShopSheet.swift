import SwiftUI

/// The armoury.
///
/// Everything is drawn from `shop_catalogue()` rather than from the app's own
/// lists, because the server is the authority on what is yours: the setters
/// refuse anything the catalogue says you do not own, so a locked tile is the
/// label on a rule and not the rule itself. Tapping one says so rather than
/// making a round trip that comes back refused.
struct ShopSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var shelf: Shelf = .rings

    private enum Shelf: String, CaseIterable, Identifiable {
        case rings, emblems, banners, crests
        var id: String { rawValue }
        var title: String {
            switch self {
            case .rings:   return "RINGS"
            case .emblems: return "EMBLEMS"
            case .banners: return "BANNERS"
            case .crests:  return "CRESTS"
            }
        }
    }

    private var isOwner: Bool { session.league?.ownerId == session.profile?.id }
    private var rings: [ShopItem] { session.shelf("frame") }
    /// Rings are the one shelf that can be empty: there are none until
    /// somebody uploads one, and an empty tab is worse than no tab.
    private var tabs: [Shelf] {
        Shelf.allCases.filter { $0 != .rings || !rings.isEmpty }
    }
    private var priced: Bool { session.shop.contains { $0.priceCents != nil } }

    private var blurb: String {
        switch shelf {
        case .rings:
            return "Drawn around your emblem on every board, every duel and every quest you turn up for. The only thing in here other people see without opening anything."
        case .emblems:
            return "\(IconSet.avatars.count) marks and \(Tint.emblem.count) tints — that is over a thousand combinations, and no two people need look alike."
        case .banners:
            return "\(SkinCatalog.player.count) for a person, \(SkinCatalog.league.count) for a league. The shipped ones are drawn rather than downloaded."
        case .crests:
            return "\(IconSet.crests.count) heraldic marks across \(CrestShape.allCases.count) shapes. Only the person who made a league can change its crest."
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    shelves

                    Panel(padding: 14, tint: Theme.gold) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(shelf.title)
                                    .font(Theme.display(15, .black)).italic()
                                    .foregroundStyle(Theme.gold)
                                Spacer()
                                Chip(text: priced ? "ARMOURY" : "ALL FREE",
                                     color: priced ? Theme.gold : Theme.jade)
                            }
                            Text(blurb)
                                .font(.caption).foregroundStyle(Theme.inkMuted)
                        }
                    }

                    switch shelf {
                    case .rings:   ringShelf
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
            .navigationTitle("Armoury")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.display(15, .bold))
                        .foregroundStyle(Theme.flame)
                }
            }
            .onAppear {
                // Cheap, and it means a ring bought on another device is here
                // the first time this sheet is opened rather than after a
                // restart.
                Task { session.shop = (try? await API.shared.shopCatalogue()) ?? session.shop }
            }
            .task { if shelf == .rings && rings.isEmpty { shelf = .emblems } }
        }
    }

    private var shelves: some View {
        HStack(spacing: 8) {
            ForEach(tabs) { s in
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

    // MARK: rings

    private var ringShelf: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)],
                      spacing: 10) {
                ForEach(rings) { it in
                    RingTile(item: it,
                             selected: session.profile?.frame == it.item,
                             price: it.owned ? nil : session.priceTag(it)) {
                        Task { await session.choose(it) { await session.setFrame(it.item) } }
                    }
                }
            }
            if session.profile?.frame != nil {
                Button {
                    Task { await session.setFrame("") }
                } label: {
                    Text("TAKE THE RING OFF")
                        .font(Theme.display(12, .black)).kerning(1)
                        .foregroundStyle(Theme.inkMuted)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: the rest

    private var emblems: some View {
        EmblemPicker(current: session.profile?.avatar) { spec in
            Task { await session.setAvatar(spec) }
        }
    }

    private var banners: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                shelfLabel("YOURS TO WEAR")
                bannerGrid(kind: "player_banner", chosen: session.profile?.banner) { it in
                    Task { await session.choose(it) { await session.setBanner(it.item) } }
                }
            }

            VStack(spacing: 8) {
                shelfLabel(isOwner ? "FOR YOUR LEAGUE" : "FOR A LEAGUE YOU RUN")
                if !isOwner {
                    Text("You did not make the league you are looking at, so these are shown but not yours to set.")
                        .font(.caption2).foregroundStyle(Theme.inkFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                bannerGrid(kind: "league_banner",
                           chosen: session.league?.badge?.skin) { it in
                    guard isOwner else {
                        session.show("Only the person who made a league can change it.")
                        return
                    }
                    var badge = session.league?.badge ?? League.Badge()
                    badge.skin = it.item
                    let next = badge
                    Task { await session.choose(it) { await session.saveCrest(next) } }
                }
                .opacity(isOwner ? 1 : 0.55)
            }
        }
    }

    /// A shipped banner is a drawn `Skin`; an uploaded one is a picture with
    /// no Skin behind it, so the swatch falls back to a plain one and shows
    /// the artwork instead.
    private func bannerGrid(kind: String, chosen: String?,
                            pick: @escaping (ShopItem) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(session.shelf(kind)) { it in
                let skin = SkinCatalog.find(it.item)
                    ?? Skin(key: it.item, name: it.name,
                            scope: kind == "league_banner" ? .league : .player,
                            base: [0x1A1D24, 0x0B0D11])
                SkinSwatch(skin: skin, selected: chosen == it.item,
                           art: it.assetPath == nil ? nil : it.thumbURL,
                           price: it.owned ? nil : session.priceTag(it)) {
                    pick(it)
                }
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
                ForEach(session.shelf("crest")) { it in
                    ZStack(alignment: .topTrailing) {
                        // Uploaded artwork is an image, never inlined: an SVG
                        // can carry script, which is why the bucket refuses
                        // them and why this never inlines anything either.
                        if let url = it.thumbURL {
                            AsyncImage(url: url) { $0.resizable().scaledToFit() }
                                placeholder: { Color.clear }
                                .padding(8)
                        } else {
                            GameIcon(key: it.item)
                                .foregroundStyle(Theme.inkMuted)
                                .padding(8)
                        }
                        if !it.owned {
                            Text(session.priceTag(it))
                                .font(Theme.display(8, .heavy))
                                .foregroundStyle(Theme.gold)
                                .padding(3)
                        }
                    }
                    .frame(height: 48)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.raised))
                    .opacity(it.owned ? 1 : 0.45)
                }
            }

            Text(isOwner
                 ? "Set your league's crest in League Settings."
                 : "A crest belongs to whoever made the league.")
                .font(.caption2).foregroundStyle(Theme.inkFaint)
        }
    }

    /// The shelf nothing is on yet. It exists so the shape of the thing is
    /// agreed now rather than bolted on later — nothing here charges anybody.
    private var comingSoon: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("NOT BUILT YET")
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
        Planned(title: "LEAGUE PASS",
                detail: "A season's rings and banners as they land, and your league's history as a file you keep."),
        Planned(title: "SEASON PRIZE",
                detail: "Something on the line for a whole season, settled between you — the app never touches money."),
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

/// A ring, drawn around your own face rather than around nothing — the point
/// of one is what it looks like on you.
private struct RingTile: View {
    @Environment(Session.self) private var session
    let item: ShopItem
    var selected: Bool
    var price: String?
    var action: () -> Void

    var body: some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            VStack(spacing: 6) {
                Mark(spec: session.profile?.avatar,
                     name: session.profile?.displayName ?? "?",
                     ring: item.thumbURL)
                    .frame(width: 58, height: 58)
                Text(item.name)
                    .font(Theme.display(9, .heavy)).kerning(0.6)
                    .foregroundStyle(selected ? Theme.flame : Theme.inkFaint)
                    .lineLimit(1)
                if let price {
                    Text(price)
                        .font(Theme.display(9, .heavy))
                        .foregroundStyle(Theme.gold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(Theme.raised)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                            .strokeBorder(selected ? Theme.flame : Theme.hairline,
                                          lineWidth: selected ? 2 : 1)
                    }
            }
            .opacity(price == nil ? 1 : 0.5)
        }
        .buttonStyle(.plain)
    }
}
