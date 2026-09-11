import SwiftUI

/// The visual language. One place, so a change is a change everywhere.
///
/// The web app is flat and static by design — it had to work on any phone
/// from a single HTML file. Native has no such excuse, so this palette is
/// built for depth: layered surfaces, real materials, and colour that carries
/// meaning (a division metal, a rank grade) rather than just decorating.
enum Theme {

    // MARK: Surfaces — four depths, so cards can sit *on* something
    static let void      = Color(hex: 0x07080B)   // behind everything
    static let base      = Color(hex: 0x0B0D12)
    static let surface   = Color(hex: 0x14171F)
    static let raised    = Color(hex: 0x1C2029)
    static let hairline  = Color.white.opacity(0.07)

    // MARK: Ink
    static let ink       = Color(hex: 0xF2F5FA)
    static let inkMuted  = Color(hex: 0x8A93A6)
    static let inkFaint  = Color(hex: 0x5A6273)

    // MARK: Signal
    static let flame     = Color(hex: 0xFF2E2E)   // the brand red
    static let ember     = Color(hex: 0xFF6A1F)
    /// Above gold. A pale ice blue, because the board is already red and gold
    /// and the very top of it should be the one thing on screen that is cold.
    static let diamond   = Color(hex: 0x8CE9FF)
    static let gold      = Color(hex: 0xFFC93C)
    static let silver    = Color(hex: 0xC9D3E2)
    static let bronze    = Color(hex: 0xD08442)
    static let jade      = Color(hex: 0x26D07C)
    static let azure     = Color(hex: 0x3BA6FF)
    static let violet    = Color(hex: 0xA86BFF)

    /// The gradient that means "energy" — used on the log button, progress
    /// fills, and anything the eye should land on first.
    static let heat = LinearGradient(
        colors: [flame, ember, gold],
        startPoint: .leading, endPoint: .trailing)

    static func metal(_ tier: Division) -> Color {
        switch tier {
        case .throne:   return diamond
        case .apex:     return gold
        case .vanguard: return silver
        case .forge:    return bronze
        }
    }

    // MARK: Type — one condensed display face for numbers and headings,
    // the system face for anything a person actually reads.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: Shape
    static let corner: CGFloat = 18
    static let cornerSmall: CGFloat = 12
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >>  8) & 0xFF) / 255,
                  blue:  Double( hex        & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// A division is a place with a name, not a colour with a number.
///
/// The sizes narrow sharply at the top on purpose. Two seats on the throne and
/// three in the apex means the top of the table is somewhere you can be pushed
/// out of by one good evening — which is the only reason to have divisions.
enum Division: String, CaseIterable {
    case throne, apex, vanguard, forge

    /// How many people it holds. Whoever spills past the last one joins it.
    var size: Int {
        switch self {
        case .throne:   return 2
        case .apex:     return 3
        case .vanguard: return 10
        case .forge:    return 15
        }
    }

    var title: String {
        switch self {
        case .throne:   return "THRONE"
        case .apex:     return "APEX"
        case .vanguard: return "VANGUARD"
        case .forge:    return "FORGE"
        }
    }
    var subtitle: String {
        switch self {
        case .throne:   return "Two seats. One of them is yours to lose"
        case .apex:     return "Three deep, and one push from the throne"
        case .vanguard: return "Chasing the Apex"
        case .forge:    return "Where everyone starts"
        }
    }
    var symbol: String {
        switch self {
        case .throne:   return "crown.fill"
        case .apex:     return "shield.fill"
        case .vanguard: return "shield.lefthalf.filled"
        case .forge:    return "hammer.fill"
        }
    }
}
