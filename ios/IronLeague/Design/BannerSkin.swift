import SwiftUI

/// The banners, rebuilt natively.
///
/// On the web these are CSS gradients because a PWA cannot ship artwork
/// without paying for it in download size. Here they are drawn into a Canvas:
/// same 32 looks, same keys, so a banner someone bought on the web is the
/// banner they see on the phone — but now the motion is real drawing rather
/// than a keyframe fighting the scroll.
struct Skin: Identifiable, Hashable {
    enum Scope: Hashable { case league, player }

    /// A soft pool of colour — the `radial-gradient(...)` layer in the CSS.
    struct Well: Hashable {
        var color: UInt32
        var alpha: Double
        var x: Double           // unit position across the banner
        var y: Double
        var r: Double           // radius as a fraction of the longer side
        var wide: Double = 1    // > 1 stretches it into an ellipse
    }

    /// A woven ground — the `repeating-linear-gradient(...)` layer.
    struct Stripes: Hashable {
        var a: UInt32
        var b: UInt32
        var widthA: Double
        var widthB: Double
        var angle: Double
    }

    /// The extra layer on top: a grid, drifting diagonals, floodlights.
    enum FX: Hashable {
        case none
        case grid(spacing: Double, color: UInt32, alpha: Double)
        case diagonals(spacing: Double, band: Double, angle: Double,
                       color: UInt32, alpha: Double, drift: Double)
        case scanline(UInt32, UInt32)
        case floodlights
        case rasters(spacing: Double, alpha: Double, jitter: Bool)
    }

    let key: String
    let name: String
    let scope: Scope
    var base: [UInt32]
    var vertical: Bool = false
    var well: Well? = nil
    var stripes: Stripes? = nil
    var fx: FX = .none
    var sheen: UInt32 = 0xFFFFFF
    var sheenAlpha: Double = 0
    var speed: Double = 6
    var groundDrift: Double = 0     // seconds for the ground itself to travel
    var light: Bool = false         // a pale banner, so ink must go dark

    var id: String { key }

    var moves: Bool {
        if sheenAlpha > 0 || groundDrift > 0 { return true }
        switch fx {
        case .diagonals(_, _, _, _, _, let drift): return drift > 0
        case .scanline, .floodlights: return true
        case .rasters(_, _, let jitter): return jitter
        default: return false
        }
    }
}

enum SkinCatalog {

    // MARK: The sixteen a league can wear — wide, architectural looks.
    static let league: [Skin] = [
        Skin(key: "standard", name: "STANDARD", scope: .league,
             base: [0x1A1D24, 0x0B0D11]),

        Skin(key: "stadium", name: "STADIUM", scope: .league,
             base: [0x04070B, 0x16222A], vertical: true,
             well: .init(color: 0x24493E, alpha: 0.95, x: 0.5, y: 1.25, r: 0.62, wide: 1.7),
             fx: .floodlights, sheen: 0xFFFFFF, sheenAlpha: 0.22, speed: 6),

        Skin(key: "goldrush", name: "GOLD RUSH", scope: .league,
             base: [0x0A0806, 0x33250F, 0x0A0806],
             well: .init(color: 0xFFCD5A, alpha: 0.32, x: 0.75, y: 0.25, r: 0.5),
             sheen: 0xFFF0AA, sheenAlpha: 0.85, speed: 5.5),

        Skin(key: "neon", name: "NEON ARENA", scope: .league,
             base: [0x04070C, 0x0B1120], vertical: true,
             well: .init(color: 0x153A6B, alpha: 1, x: 0.5, y: 1.2, r: 0.7, wide: 1.6),
             fx: .scanline(0x00AAFF, 0xFF174F)),

        Skin(key: "tactical", name: "OVERDRIVE", scope: .league,
             base: [0x0B1118, 0x0B1118],
             fx: .grid(spacing: 20, color: 0xFFFFFF, alpha: 0.06),
             sheen: 0x43AAFF, sheenAlpha: 0.7, speed: 3.5),

        Skin(key: "varsity", name: "VARSITY", scope: .league,
             base: [0x0B2445, 0x071426],
             stripes: .init(a: 0x071426, b: 0x0B2445, widthA: 7, widthB: 7, angle: 45),
             sheen: 0xD71F2A, sheenAlpha: 0.8, speed: 4),

        Skin(key: "holo", name: "PRISM", scope: .league,
             base: [0x2B4F96, 0xC164B4, 0x5BD2D2, 0xECD473, 0x2B4F96],
             sheen: 0xFFFFFF, sheenAlpha: 0.5, speed: 7, groundDrift: 9),

        Skin(key: "luxury", name: "DOMINION", scope: .league,
             base: [0x0A0A0A, 0x050505],
             stripes: .init(a: 0x070707, b: 0x101010, widthA: 15, widthB: 2, angle: 135),
             sheen: 0xFFE18C, sheenAlpha: 0.9, speed: 5),

        Skin(key: "jungle", name: "JUNGLE", scope: .league,
             base: [0x04120B, 0x123522, 0x050F09],
             well: .init(color: 0x288C50, alpha: 0.45, x: 0.3, y: 1.1, r: 0.62, wide: 1.5),
             sheen: 0x96FFBE, sheenAlpha: 0.5, speed: 6.5),

        Skin(key: "sandstorm", name: "SANDSTORM", scope: .league,
             base: [0x2A2014, 0x6B4F2A, 0x1A130C],
             fx: .diagonals(spacing: 22, band: 3, angle: 100,
                            color: 0xFFDC96, alpha: 0.16, drift: 5),
             sheen: 0xFFE1A0, sheenAlpha: 0.6, speed: 6),

        Skin(key: "abyss", name: "ABYSS", scope: .league,
             base: [0x01060D, 0x031725], vertical: true,
             well: .init(color: 0x145A8C, alpha: 0.5, x: 0.5, y: -0.2, r: 0.72, wide: 1.6),
             sheen: 0x5AC8FF, sheenAlpha: 0.4, speed: 8),

        Skin(key: "circuit", name: "CIRCUIT", scope: .league,
             base: [0x04140F, 0x02261B],
             fx: .grid(spacing: 12, color: 0x26D07C, alpha: 0.18),
             sheen: 0x26D07C, sheenAlpha: 0.6, speed: 4),

        Skin(key: "aurora", name: "AURORA", scope: .league,
             base: [0x06121F, 0x1D5C6E, 0x5A2F8F, 0x0A1526],
             sheen: 0xB4FFEB, sheenAlpha: 0.5, speed: 7, groundDrift: 12),

        Skin(key: "magma", name: "MAGMA", scope: .league,
             base: [0x150604, 0x2C0C05],
             well: .init(color: 0xFF5A00, alpha: 0.6, x: 0.3, y: 1.1, r: 0.55),
             stripes: .init(a: 0x150604, b: 0x2C0C05, widthA: 16, widthB: 3, angle: 120),
             fx: .diagonals(spacing: 32, band: 2, angle: 60,
                            color: 0xFF8C28, alpha: 0.25, drift: 4),
             sheen: 0xFFAA50, sheenAlpha: 0.6, speed: 5),

        Skin(key: "steelwork", name: "STEELWORK", scope: .league,
             base: [0x191D24, 0x0A0C10], vertical: true,
             stripes: .init(a: 0x14171C, b: 0x0D1014, widthA: 10, widthB: 2, angle: 90),
             sheen: 0xD2E1FF, sheenAlpha: 0.5, speed: 6),

        Skin(key: "nightops", name: "NIGHT OPS", scope: .league,
             base: [0x070B09, 0x0E1A14],
             well: .init(color: 0x26D07C, alpha: 0.35, x: 0.82, y: 0.26, r: 0.38),
             sheen: 0x26D07C, sheenAlpha: 0.35, speed: 7)
    ]

    // MARK: The sixteen a person can wear — tighter, personal looks.
    static let player: [Skin] = [
        Skin(key: "carbon", name: "CARBON", scope: .player,
             base: [0x15171A, 0x0D0F11],
             stripes: .init(a: 0x15171A, b: 0x0D0F11, widthA: 5, widthB: 5, angle: 45),
             sheen: 0xFF2E2E, sheenAlpha: 0.55, speed: 4.5),

        Skin(key: "ember", name: "INFERNO", scope: .player,
             base: [0x160604, 0x3C1207, 0x0B0706],
             well: .init(color: 0xFF500A, alpha: 0.5, x: 0.7, y: 0.45, r: 0.5),
             fx: .diagonals(spacing: 27, band: 2, angle: 125,
                            color: 0xFF5A0A, alpha: 0.3, drift: 3),
             sheen: 0xFF963C, sheenAlpha: 0.5, speed: 4),

        Skin(key: "frost", name: "FROSTBITE", scope: .player,
             base: [0x06121C, 0x0C3047, 0x07111B],
             well: .init(color: 0x78D2FF, alpha: 0.4, x: 0.7, y: 0.35, r: 0.5),
             sheen: 0xDCFAFF, sheenAlpha: 0.75, speed: 6),

        Skin(key: "velocity", name: "VELOCITY", scope: .player,
             base: [0x08090B, 0x23070A],
             fx: .diagonals(spacing: 26, band: 3, angle: 115,
                            color: 0xED1821, alpha: 0.55, drift: 1.2),
             sheen: 0xFF5A5A, sheenAlpha: 0.4, speed: 3),

        Skin(key: "blueprint", name: "BLUEPRINT", scope: .player,
             base: [0x08243F, 0x050B13],
             fx: .grid(spacing: 16, color: 0x5AAAFF, alpha: 0.16),
             sheen: 0x78BEFF, sheenAlpha: 0.35, speed: 6),

        Skin(key: "grunge", name: "GLITCH", scope: .player,
             base: [0x1A1A1A, 0x0A0A0A],
             fx: .diagonals(spacing: 28, band: 3, angle: 125,
                            color: 0xFF2E2E, alpha: 0.22, drift: 6),
             sheen: 0xFF3C3C, sheenAlpha: 0.5, speed: 2.5),

        Skin(key: "obsidian", name: "OBSIDIAN", scope: .player,
             base: [0x0A0A0C, 0x131318],
             well: .init(color: 0xBE963C, alpha: 0.22, x: 0.78, y: 0.22, r: 0.46),
             stripes: .init(a: 0x0A0A0C, b: 0x131318, widthA: 14, widthB: 2, angle: 115),
             sheen: 0xFFD78C, sheenAlpha: 0.7, speed: 5.5),

        Skin(key: "inverted", name: "CLEAN SLATE", scope: .player,
             base: [0xECEEF2, 0xC9CCD4],
             sheen: 0x000000, sheenAlpha: 0.14, speed: 6, light: true),

        Skin(key: "venom", name: "VENOM", scope: .player,
             base: [0x0A1204, 0x1D3305, 0x070D03],
             well: .init(color: 0x96FF28, alpha: 0.32, x: 0.7, y: 0.4, r: 0.5),
             sheen: 0xC8FF5A, sheenAlpha: 0.7, speed: 6),

        Skin(key: "bloodline", name: "BLOODLINE", scope: .player,
             base: [0x120305, 0x3A070D, 0x0A0204],
             well: .init(color: 0xBE141E, alpha: 0.5, x: 0.25, y: 0.3, r: 0.5),
             sheen: 0xFF5A64, sheenAlpha: 0.6, speed: 5.5),

        Skin(key: "glacier", name: "GLACIER", scope: .player,
             base: [0x0A1A26, 0x2C6D8C, 0x0B1C28],
             fx: .diagonals(spacing: 24, band: 3, angle: 115,
                            color: 0xDCFAFF, alpha: 0.14, drift: 0),
             sheen: 0xEBFCFF, sheenAlpha: 0.8, speed: 6),

        Skin(key: "brass", name: "BRASS", scope: .player,
             base: [0x151008, 0x241A0B],
             stripes: .init(a: 0x151008, b: 0x241A0B, widthA: 12, widthB: 2, angle: 135),
             sheen: 0xFFCD78, sheenAlpha: 0.75, speed: 5),

        Skin(key: "static", name: "STATIC", scope: .player,
             base: [0x0B0B0E, 0x0B0B0E],
             fx: .rasters(spacing: 3, alpha: 0.09, jitter: true),
             sheen: 0xFFFFFF, sheenAlpha: 0.35, speed: 3),

        Skin(key: "orchid", name: "ORCHID", scope: .player,
             base: [0x12061A, 0x3A1049, 0x0B0410],
             well: .init(color: 0xC85ADC, alpha: 0.4, x: 0.7, y: 0.35, r: 0.5),
             sheen: 0xF0AAFF, sheenAlpha: 0.6, speed: 6),

        Skin(key: "moss", name: "MOSS", scope: .player,
             base: [0x0C1408, 0x243A15, 0x0A1006],
             sheen: 0xBEE68C, sheenAlpha: 0.45, speed: 7),

        Skin(key: "ash", name: "ASH", scope: .player,
             base: [0x1B1B1D, 0x37373B, 0x141416],
             sheen: 0xFFFFFF, sheenAlpha: 0.3, speed: 7)
    ]

    static let all: [Skin] = league + player

    private static let index: [String: Skin] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })

    static func find(_ key: String?) -> Skin? {
        guard let key, !key.isEmpty else { return nil }
        return index[key]
    }

    /// CLEAN SLATE is a pale banner, so a row wearing it needs dark ink unless
    /// the person has chosen a colour of their own.
    static func prefersDarkInk(_ key: String?) -> Bool { find(key)?.light ?? false }
}

// MARK: - The view

struct BannerSkin: View {
    let key: String
    var animated: Bool = true
    var intensity: Double = 1

    var body: some View {
        if let skin = SkinCatalog.find(key) {
            if animated && skin.moves {
                TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { tl in
                    surface(skin, t: tl.date.timeIntervalSinceReferenceDate)
                }
            } else {
                surface(skin, t: 0)
            }
        }
    }

    private func surface(_ skin: Skin, t: Double) -> some View {
        Canvas(opaque: false, rendersAsynchronously: false) { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            ctx.clip(to: Path(rect))

            ground(&ctx, skin, rect, t)
            if let w = skin.well { pool(&ctx, w, rect) }
            if let s = skin.stripes { weave(&ctx, s, rect) }
            effect(&ctx, skin, rect, t)
            if skin.sheenAlpha > 0 { sheen(&ctx, skin, rect, t) }
        }
        .allowsHitTesting(false)
    }

    // MARK: layers

    private func ground(_ ctx: inout GraphicsContext, _ skin: Skin,
                        _ rect: CGRect, _ t: Double) {
        let stops = skin.base.map { Color(hex: $0) }
        var start = skin.vertical ? CGPoint(x: rect.midX, y: rect.minY)
                                  : CGPoint(x: rect.minX, y: rect.minY)
        var end   = skin.vertical ? CGPoint(x: rect.midX, y: rect.maxY)
                                  : CGPoint(x: rect.maxX, y: rect.maxY)

        // holo and aurora are the two whose ground itself travels
        if skin.groundDrift > 0 {
            let phase = sin(t * 2 * .pi / skin.groundDrift)
            let shift = rect.width * 0.9 * phase
            start.x -= shift
            end.x   -= shift
        }

        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(colors: stops), startPoint: start, endPoint: end))
    }

    private func pool(_ ctx: inout GraphicsContext, _ w: Skin.Well, _ rect: CGRect) {
        let r = w.r * max(rect.width, rect.height)
        let c = CGPoint(x: w.x * rect.width, y: w.y * rect.height)
        let colour = Color(hex: w.color, alpha: w.alpha * intensity)
        ctx.drawLayer { layer in
            layer.translateBy(x: c.x, y: c.y)
            layer.scaleBy(x: w.wide, y: 1)
            layer.translateBy(x: -c.x, y: -c.y)
            layer.fill(
                Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                with: .radialGradient(Gradient(colors: [colour, colour.opacity(0)]),
                                      center: c, startRadius: 0, endRadius: r))
        }
    }

    private func weave(_ ctx: inout GraphicsContext, _ s: Skin.Stripes, _ rect: CGRect) {
        let period = s.widthA + s.widthB
        guard period > 0 else { return }
        let span = hypot(rect.width, rect.height)
        ctx.drawLayer { layer in
            layer.translateBy(x: rect.midX, y: rect.midY)
            layer.rotate(by: .degrees(s.angle))
            var x = -span
            while x < span {
                layer.fill(Path(CGRect(x: x, y: -span, width: s.widthB, height: span * 2)),
                           with: .color(Color(hex: s.b)))
                x += period
            }
        }
    }

    private func effect(_ ctx: inout GraphicsContext, _ skin: Skin,
                        _ rect: CGRect, _ t: Double) {
        switch skin.fx {
        case .none:
            break

        case let .grid(spacing, colour, alpha):
            let c = Color(hex: colour, alpha: alpha * intensity)
            var x = spacing
            while x < rect.width {
                ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: rect.height)), with: .color(c))
                x += spacing
            }
            var y = spacing
            while y < rect.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: rect.width, height: 1)), with: .color(c))
                y += spacing
            }

        case let .diagonals(spacing, band, angle, colour, alpha, drift):
            let c = Color(hex: colour, alpha: alpha * intensity)
            let span = hypot(rect.width, rect.height)
            let offset = drift > 0 ? (t / drift).truncatingRemainder(dividingBy: 1) * spacing : 0
            ctx.drawLayer { layer in
                layer.translateBy(x: rect.midX, y: rect.midY)
                layer.rotate(by: .degrees(angle))
                var x = -span + offset
                while x < span {
                    layer.fill(Path(CGRect(x: x, y: -span, width: band, height: span * 2)),
                               with: .color(c))
                    x += spacing
                }
            }

        case let .scanline(a, b):
            // a thin bar of light crossing the row, breathing in and out
            let pulse = 0.45 + 0.35 * (0.5 + 0.5 * sin(t * 2 * .pi / 2.4))
            let y = rect.height * 0.62
            ctx.fill(Path(CGRect(x: 0, y: y, width: rect.width, height: 2)),
                     with: .linearGradient(
                        Gradient(colors: [.clear, Color(hex: a, alpha: pulse),
                                          Color(hex: b, alpha: pulse), .clear]),
                        startPoint: CGPoint(x: 0, y: y),
                        endPoint: CGPoint(x: rect.width, y: y)))

        case .floodlights:
            let cycle = 0.5 + 0.5 * sin(t * 2 * .pi / 6)
            let spacing = rect.width / 7
            var x = spacing * 0.5
            while x < rect.width {
                let c = Color.white.opacity(0.30 * cycle * intensity)
                ctx.fill(Path(CGRect(x: x, y: 0, width: 3, height: rect.height * 0.34)),
                         with: .linearGradient(Gradient(colors: [c, .clear]),
                                               startPoint: CGPoint(x: x, y: 0),
                                               endPoint: CGPoint(x: x, y: rect.height * 0.34)))
                x += spacing
            }

        case let .rasters(spacing, alpha, jitter):
            let wobble = jitter ? sin(t * 18).rounded() : 0
            let c = Color.white.opacity(alpha * intensity)
            var y = wobble
            while y < rect.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: rect.width, height: 1)), with: .color(c))
                y += spacing
            }
        }
    }

    /// The travelling highlight every skin shares — the thing that makes a
    /// row look lit rather than printed.
    private func sheen(_ ctx: inout GraphicsContext, _ skin: Skin,
                       _ rect: CGRect, _ t: Double) {
        let phase = (t / skin.speed).truncatingRemainder(dividingBy: 1)
        let travel = rect.width + rect.height
        let x = -rect.height + travel * 1.4 * phase - rect.width * 0.2
        let band = max(26, rect.width * 0.16)
        let c = Color(hex: skin.sheen, alpha: skin.sheenAlpha * 0.55 * intensity)
        ctx.drawLayer { layer in
            layer.translateBy(x: x, y: 0)
            layer.rotate(by: .degrees(18))
            layer.fill(
                Path(CGRect(x: 0, y: -rect.height, width: band, height: rect.height * 3)),
                with: .linearGradient(
                    Gradient(colors: [.clear, c, .clear]),
                    startPoint: .zero, endPoint: CGPoint(x: band, y: 0)))
        }
    }
}

/// A banner shown as something you can pick, with its name on it.
struct SkinSwatch: View {
    let skin: Skin
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            ZStack(alignment: .bottomLeading) {
                BannerSkin(key: skin.key)
                    .frame(height: 56)
                LinearGradient(colors: [.black.opacity(skin.light ? 0 : 0.5), .clear],
                               startPoint: .bottom, endPoint: .top)
                Text(skin.name)
                    .font(Theme.display(10, .heavy)).kerning(0.8)
                    .foregroundStyle(skin.light ? Color(hex: 0x14161B) : Theme.ink)
                    .padding(8)
            }
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .strokeBorder(selected ? Theme.flame : Theme.hairline,
                                  lineWidth: selected ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.flame)
                        .padding(5)
                }
            }
        }
        .buttonStyle(.plain)
        .pressable()
    }
}
