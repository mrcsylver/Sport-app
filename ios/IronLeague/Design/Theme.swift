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
    /// Below bronze: the people not in the order yet.
    static let stone     = Color(hex: 0x7D8492)
    static let gold      = Color(hex: 0xFFC93C)
    static let silver    = Color(hex: 0xC9D3E2)
    static let bronze    = Color(hex: 0xD08442)
    static let jade      = Color(hex: 0x26D07C)
    /// LEGEND, the division above S. When the ramp has already spent stone,
    /// green, bronze, silver, gold and ice, the only thing left that reads as
    /// higher is no colour at all. Matches --legend in styles.css.
    static let legendWhite = Color(hex: 0xE9EDF5)
    static let azure     = Color(hex: 0x3BA6FF)
    static let violet    = Color(hex: 0xA86BFF)

    /// The gradient that means "energy" — used on the log button, progress
    /// fills, and anything the eye should land on first.
    static let heat = LinearGradient(
        colors: [flame, ember, gold],
        startPoint: .leading, endPoint: .trailing)

    /// Stone, green, bronze, silver, gold, ice — and above ice a white that
    /// is not a colour at all. Must match .t-legend … .t-e in styles.css.
    static func metal(_ tier: Division) -> Color {
        switch tier {
        case .legend: return legendWhite
        case .s:      return diamond
        case .a:      return gold
        case .b:      return silver
        case .c:      return bronze
        case .d:      return jade
        case .e:      return stone
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

/// A division is a letter, because a letter needs no teaching.
///
/// These used to be ROYAL GUARD, APEX, VANGUARD, FORGE and COMMONER — five
/// invented words, each of which had to be learned before any of them meant
/// anything, and nobody could tell from the name whether a VANGUARD outranked
/// a FORGE. Everyone who has touched a game or a report card already knows
/// that D beats E and that S is above A. LEGEND sits where there is no letter
/// left. Must match TIERS in app.js.
///
/// The sizes still narrow sharply at the top, which is the only reason to
/// have divisions at all: two places in LEGEND and three in S means the top
/// of the table is somewhere one good evening can push you out of.
enum Division: String, CaseIterable {
    case legend, s, a, b, c, d, e

    /// How many people it holds in a league of 36, which is the default size
    /// and the number these seven come to — and even on purpose, because the
    /// Monday rivalry pairs the table off two by two.
    var size: Int {
        switch self {
        case .legend: return 2
        case .s:      return 3
        case .a:      return 5
        case .b:      return 7
        case .c:      return 10
        case .d:      return 6
        case .e:      return 3
        }
    }

    /// How many it holds in a table of `n`. Up to 36 this is `size` and
    /// nothing about an existing league moves. Past it — a league can hold
    /// 100 now — the BOTTOM FIVE grow in the proportion they already have
    /// and the top two never do: a LEGEND of six is not a LEGEND, and the
    /// point of those five places is that one good evening can push you out
    /// of them. Without this the overflow all landed in E, so a league of 100
    /// read as six divisions and then a crowd of seventy.
    static func sizes(for n: Int) -> [Division: Int] {
        var out: [Division: Int] = [:]
        if n <= 36 {
            for d in Division.allCases { out[d] = d.size }
            return out
        }
        let rest = n - 5
        let a = Int((Double(rest) *  5.0 / 31.0).rounded())
        let b = Int((Double(rest) *  7.0 / 31.0).rounded())
        let c = Int((Double(rest) * 10.0 / 31.0).rounded())
        let d = Int((Double(rest) *  6.0 / 31.0).rounded())
        out[.legend] = 2
        out[.s] = 3
        out[.a] = a
        out[.b] = b
        out[.c] = c
        out[.d] = d
        out[.e] = rest - a - b - c - d
        return out
    }

    /// Which numbering this division belongs to. The Royal Guard and the Apex
    /// share one, so the top five read 1 to 5 straight through — they are the
    /// top of the league, not two separate races. Everything below counts
    /// from 1 again: your number is your place among the people you are
    /// actually fighting.
    var rankGroup: String {
        switch self {
        case .legend, .s: return "top"
        default:          return rawValue
        }
    }

    var title: String { rawValue.uppercased() }
    var subtitle: String {
        switch self {
        case .legend: return "The two who stand closest to the crown"
        case .s:      return "Three deep, and one push off the front"
        case .a:      return "The line that holds. Chasing the top"
        case .b:      return "Close enough to smell it"
        case .c:      return "Where a fighter is hammered into shape"
        case .d:      return "Out of the bottom, and climbing"
        case .e:      return "Everyone starts here. Nobody stays"
        }
    }
    var symbol: String {
        switch self {
        case .legend: return "crown.fill"
        case .s:      return "figure.fencing"
        case .a:      return "shield.lefthalf.filled"
        case .b:      return "shield.fill"
        case .c:      return "hammer.fill"
        case .d:      return "mountain.2.fill"
        case .e:      return "figure.walk"
        }
    }
}
