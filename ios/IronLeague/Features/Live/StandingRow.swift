import SwiftUI

/// One fighter. Dense on purpose — this is the screen people scan, so the row
/// carries rank, mark, name, grade and points and nothing else. The banner is
/// a texture behind it, never a block of colour over the text.
struct StandingRow: View {
    let standing: Standing
    let rank: Int
    let division: Division?
    let isMe: Bool
    let isOpen: Bool
    let feed: [WorkoutRow]
    let onTap: () -> Void

    @Environment(Session.self) private var session

    private var grade: Grade? { Grade.reached(standing.lifetime) }
    private var isLeader: Bool { rank == 1 && standing.points > 0 }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) { header }
                .buttonStyle(.plain)

            if isOpen {
                FeedList(rows: feed, exercises: session.exercises,
                         onDelete: isMe ? { row in
                             Task { await session.deleteLog(row) }
                         } : nil)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.surface)
                .overlay {
                    if let skin = standing.banner {
                        BannerSkin(key: skin)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.corner,
                                                        style: .continuous))
                            .opacity(0.9)
                    }
                }
                .overlay {
                    // a scrim only where the text sits, so the artwork survives
                    LinearGradient(colors: [scrim, scrim.opacity(0)],
                                   startPoint: .leading, endPoint: .trailing)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner,
                                                    style: .continuous))
                }
                .overlay(alignment: .leading) {
                    // the grade edge — every row has one, unranked included
                    Rectangle()
                        .fill(grade.map { Grade.color(tier: $0.tier) } ?? Theme.inkFaint.opacity(0.5))
                        .frame(width: 3)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: isLeader || isMe ? 1.4 : 1)
                }
                .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
        }
    }

    /// The artwork survives because the scrim only covers the left third,
    /// where the text actually sits. A pale banner gets a pale scrim.
    private var scrim: Color {
        guard standing.banner != nil else { return .clear }
        return SkinCatalog.prefersDarkInk(standing.banner)
            ? .white.opacity(0.55) : .black.opacity(0.62)
    }

    private var borderColor: Color {
        if let d = division, d == .throne { return Theme.diamond.opacity(0.6) }
        if isLeader, let d = division { return Theme.metal(d).opacity(0.65) }
        if isLeader { return Theme.gold.opacity(0.6) }
        if isMe { return Theme.flame.opacity(0.5) }
        return Theme.hairline
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(standing.points > 0 ? "\(rank)" : "–")
                .font(Theme.display(20, .black)).italic()
                .foregroundStyle(rankColor)
                .frame(width: 24, alignment: .leading)

            Mark(spec: standing.avatar, name: standing.displayName,
                 tint: division.map { Theme.metal($0) })
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(standing.displayName)
                        .font(Theme.display(16, .heavy))
                        .foregroundStyle(nameTint)
                        .lineLimit(1)
                    if isMe {
                        Text("YOU").font(Theme.display(8, .heavy))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    ForEach(standing.pinnedBadges ?? [], id: \.self) { key in
                        WornBadge(key: key)
                    }
                }
                HStack(spacing: 6) {
                    if let g = grade {
                        Chip(text: g.name, color: Grade.color(tier: g.tier))
                    }
                    Text("\(standing.entries) \(standing.entries == 1 ? "entry" : "entries")")
                        .font(.caption2).foregroundStyle(Theme.inkFaint)
                    if standing.bonus > 0 {
                        Text("+\(Int(standing.bonus)) bonus")
                            .font(.caption2.weight(.bold)).foregroundStyle(Theme.gold)
                    }
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: -2) {
                RollingNumber(value: standing.points,
                              font: Theme.display(23, .black),
                              color: Theme.ink, decimals: standing.points < 100 ? 1 : 0)
                Text("PTS").font(Theme.display(9, .heavy)).kerning(1)
                    .foregroundStyle(Theme.inkFaint)
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
                .rotationEffect(.degrees(isOpen ? 180 : 0))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    /// In a divided league the rank wears its division's metal, so the two
    /// on the throne read as a pair. In a small league it is the old podium.
    private var rankColor: Color {
        if let d = division { return Theme.metal(d) }
        switch rank {
        case 1: return Theme.gold
        case 2: return Theme.silver
        case 3: return Theme.bronze
        default: return Theme.inkFaint
        }
    }

    /// A chosen colour always wins. Failing that, a pale banner gets dark ink
    /// so the name never disappears into its own artwork — the conflict that
    /// the colour picker was added to solve.
    private var nameTint: Color {
        if let chosen = Tint.nameColor(standing.nameColor) { return chosen }
        return SkinCatalog.prefersDarkInk(standing.banner)
            ? Color(hex: 0x14161B) : Theme.ink
    }
}

/// A person's mark: an emblem from the game-icons set, or the emoji they
/// picked before emblems existed, or their initial. The same three cases as
/// the web app, so a choice made there shows up here unchanged.
struct Mark: View {
    let spec: String?
    let name: String
    var tint: Color? = nil

    private var parsed: AvatarSpec { AvatarSpec(spec) }

    var body: some View {
        ZStack {
            Circle().fill(Theme.raised)
            Circle().strokeBorder(tint?.opacity(0.7) ?? Theme.hairline, lineWidth: 1.5)
            content.padding(5)
        }
    }

    @ViewBuilder private var content: some View {
        if let icon = parsed.icon {
            GameIcon(key: icon)
                .foregroundStyle(parsed.colorKey.map { Tint.emblemColor($0) }
                                 ?? tint ?? Theme.inkMuted)
        } else if let emoji = parsed.emoji {
            Text(emoji).font(.system(size: 17))
        } else {
            Text(String(name.prefix(1)))
                .font(Theme.display(14, .black))
                .foregroundStyle(Theme.inkFaint)
        }
    }
}

/// The badge artwork, keyed by the badge the server hands out. The mapping is
/// generated from the same vendored file the web app reads.
enum BadgeArt {
    static func icon(_ key: String) -> String {
        IconSet.badgeArt[key] ?? "achievement"
    }
}

/// A badge worn beside a name on the board.
struct WornBadge: View {
    let key: String
    var body: some View {
        GameIcon(key: BadgeArt.icon(key))
            .foregroundStyle(Theme.gold)
            .frame(width: 13, height: 13)
    }
}
