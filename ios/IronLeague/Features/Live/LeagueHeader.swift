import SwiftUI

/// Crest, league, and the countdown in one bar — the web app learned the hard
/// way that a separate countdown band pushes the table below the fold.
struct LeagueHeader: View {
    @Environment(Session.self) private var session
    @State private var now = Date()

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            Crest(league: session.league, size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.league?.name ?? "—")
                    .font(Theme.display(19, .black)).kerning(0.4)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("\(session.league?.members ?? 0)/\(session.league?.maxMembers ?? 30) · \(session.league?.code ?? "")")
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.inkFaint)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text("ENDS IN")
                    .font(Theme.display(8, .heavy)).kerning(1.2)
                    .foregroundStyle(Theme.inkFaint)
                Text(remaining)
                    .font(Theme.mono(15, .bold))
                    .foregroundStyle(Theme.flame)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background {
            Rectangle().fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
                .ignoresSafeArea(edges: .top)
        }
        .onReceive(tick) { now = $0 }
    }

    /// Monday 00:00 to Sunday 23:59 in the league's timezone — the same window
    /// the server scores against, so the two never disagree.
    private var remaining: String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = Config.timeZone
        guard let interval = cal.dateInterval(of: .weekOfYear, for: now) else { return "--:--" }
        let secs = max(0, Int(interval.end.timeIntervalSince(now)))
        let d = secs / 86400, h = (secs % 86400) / 3600
        let m = (secs % 3600) / 60, s = secs % 60
        return d > 0 ? String(format: "%dd %02d:%02d", d, h, m)
                     : String(format: "%02d:%02d:%02d", h, m, s)
    }
}

/// The league crest: a shape, a metal, and a mark from the heraldry set —
/// never a face, so a crest can never be mistaken for a player's emblem. The
/// three parts compose into hundreds of distinct crests without a single
/// image file, and a league that has never been decorated still gets a
/// distinct one derived from its id.
struct Crest: View {
    let league: League?
    var size: CGFloat = 38

    private var badge: League.Badge? { league?.badge }

    private var seed: Int {
        // FNV-1a over the id: stable across launches, unlike hashValue
        var h: UInt32 = 0x811C9DC5
        for byte in (league?.id.uuidString ?? "iron").utf8 {
            h = (h ^ UInt32(byte)) &* 0x0100_0193
        }
        return Int(h & 0x7FFF_FFFF)
    }

    private var tint: Color {
        if let key = badge?.color, let c = Tint.emblem.first(where: { $0.key == key }) {
            return c.color
        }
        let palette = [Theme.flame, Theme.gold, Theme.silver, Theme.jade,
                       Theme.azure, Theme.violet, Theme.ember, Theme.bronze]
        return palette[seed % palette.count]
    }

    private var emblem: String {
        badge?.emblem ?? IconSet.crests[(seed / 7) % IconSet.crests.count]
    }

    private var shape: CrestShape {
        if let key = badge?.shape, let s = CrestShape(rawValue: key) { return s }
        return CrestShape.allCases[(seed / 31) % CrestShape.allCases.count]
    }

    var body: some View {
        ZStack {
            shape.silhouette
                .fill(LinearGradient(colors: [tint, tint.opacity(0.42)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(shape.silhouette.strokeBorder(.white.opacity(0.28), lineWidth: 1))
                .shadow(color: tint.opacity(0.5), radius: 8, y: 3)
            GameIcon(key: emblem)
                .foregroundStyle(Theme.void.opacity(0.78))
                .padding(size * 0.24)
        }
        .frame(width: size, height: size)
    }
}

/// Four silhouettes, so two leagues in the same colour still look different.
enum CrestShape: String, CaseIterable {
    case shield, kite, banner, roundel

    var silhouette: AnyInsettableShape {
        switch self {
        case .shield:  return AnyInsettableShape(ShieldShape())
        case .kite:    return AnyInsettableShape(KiteShape())
        case .banner:  return AnyInsettableShape(BannerShape())
        case .roundel: return AnyInsettableShape(Circle())
        }
    }

    var title: String {
        switch self {
        case .shield: return "SHIELD"; case .kite: return "KITE"
        case .banner: return "BANNER"; case .roundel: return "ROUNDEL"
        }
    }
}

/// A shape box, so a crest can pick its silhouette at runtime and still be
/// used for both the fill and the stroke.
struct AnyInsettableShape: InsettableShape {
    private let make: (CGRect) -> Path
    private let inseter: (CGFloat) -> AnyInsettableShape

    init<S: InsettableShape>(_ shape: S) {
        make = { shape.path(in: $0) }
        inseter = { AnyInsettableShape(shape.inset(by: $0)) }
    }
    func path(in rect: CGRect) -> Path { make(rect) }
    func inset(by amount: CGFloat) -> AnyInsettableShape { inseter(amount) }
}

struct ShieldShape: InsettableShape {
    var inset: CGFloat = 0
    func inset(by amount: CGFloat) -> ShieldShape {
        var s = self; s.inset += amount; return s
    }
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.06))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.06))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.48))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY),
                       control: CGPoint(x: r.maxX, y: r.maxY * 0.86))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.48),
                       control: CGPoint(x: r.minX, y: r.maxY * 0.86))
        p.closeSubpath()
        return p
    }
}

/// A long kite shield — the narrow, aggressive one.
struct KiteShape: InsettableShape {
    var inset: CGFloat = 0
    func inset(by amount: CGFloat) -> KiteShape {
        var s = self; s.inset += amount; return s
    }
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.34),
                       control: CGPoint(x: r.maxX, y: r.minY + r.height * 0.08))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY),
                       control: CGPoint(x: r.maxX, y: r.minY + r.height * 0.78))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.34),
                       control: CGPoint(x: r.minX, y: r.minY + r.height * 0.78))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY),
                       control: CGPoint(x: r.minX, y: r.minY + r.height * 0.08))
        p.closeSubpath()
        return p
    }
}

/// A hanging banner with a swallowtail — the one that reads as a club.
struct BannerShape: InsettableShape {
    var inset: CGFloat = 0
    func inset(by amount: CGFloat) -> BannerShape {
        var s = self; s.inset += amount; return s
    }
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.08, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.22))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.08, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
