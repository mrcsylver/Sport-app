import SwiftUI

/// One icon from the vendored game-icons set, as a vector asset.
///
/// `tools/build_ios_icons.py` converts each icon to a template PDF in the
/// asset catalog, so this tints with `foregroundStyle` exactly the way the
/// web app's `currentColor` SVG does — and an emblem someone picked on the
/// web is the same drawing here, not a lookalike SF Symbol.
struct GameIcon: View {
    let key: String

    var body: some View {
        Image("gi-\(key)")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

/// The palette an emblem can be tinted with. Same keys and same hexes as the
/// web app, because the choice travels in the avatar string itself.
enum Tint {
    struct Swatch: Identifiable, Hashable {
        let key: String
        let name: String
        let hex: UInt32?        // nil = "clear", meaning take the ink colour

        var id: String { key }
        var color: Color { hex.map { Color(hex: $0) } ?? Theme.ink }
    }

    static let emblem: [Swatch] = [
        .init(key: "clear",   name: "CLEAR",   hex: nil),
        .init(key: "crimson", name: "CRIMSON", hex: 0xFF2E2E),
        .init(key: "ember",   name: "EMBER",   hex: 0xFF6A1F),
        .init(key: "gold",    name: "GOLD",    hex: 0xFFC93C),
        .init(key: "jade",    name: "JADE",    hex: 0x26D07C),
        .init(key: "azure",   name: "AZURE",   hex: 0x3BA6FF),
        .init(key: "violet",  name: "VIOLET",  hex: 0xA86BFF),
        .init(key: "steel",   name: "STEEL",   hex: 0xC9D3E2),
        .init(key: "bone",    name: "BONE",    hex: 0xE8E2D4),
        .init(key: "toxic",   name: "TOXIC",   hex: 0xB6FF2E),
        .init(key: "rose",    name: "ROSE",    hex: 0xFF5C9D),
        .init(key: "cyan",    name: "CYAN",    hex: 0x22E0E0),
        .init(key: "copper",  name: "COPPER",  hex: 0xD08442),
        .init(key: "ink",     name: "INK",     hex: 0x8792A8)
    ]

    /// The short, high-contrast list for a name. It exists so a banner can
    /// never swallow the name — not as a paint box.
    static let name: [Swatch] = [
        .init(key: "",        name: "DEFAULT", hex: nil),
        .init(key: "white",   name: "WHITE",   hex: 0xFFFFFF),
        .init(key: "black",   name: "BLACK",   hex: 0x101216),
        .init(key: "gold",    name: "GOLD",    hex: 0xFFC93C),
        .init(key: "crimson", name: "CRIMSON", hex: 0xFF5555),
        .init(key: "jade",    name: "JADE",    hex: 0x3CE68F),
        .init(key: "azure",   name: "AZURE",   hex: 0x5CB8FF),
        .init(key: "violet",  name: "VIOLET",  hex: 0xC08CFF),
        .init(key: "toxic",   name: "TOXIC",   hex: 0xC8FF4A)
    ]

    static func emblemColor(_ key: String?) -> Color {
        emblem.first { $0.key == key }?.color ?? Theme.ink
    }
    static func nameColor(_ key: String?) -> Color? {
        guard let key, !key.isEmpty else { return nil }
        return name.first { $0.key == key }?.color
    }
}

/// An avatar is one mark, never two: an emblem with a tint, or an emoji.
///
///     "gi:wolf-head|c=crimson"   an emblem, tinted
///     "🦍"                        an animal
///
/// The older "|p=" pinned-emoji form still parses so nothing breaks; the pin
/// is not offered and not drawn, matching the web app.
struct AvatarSpec {
    var icon: String?
    var colorKey: String?
    var emoji: String?

    static let prefix = "gi:"

    init(_ spec: String?) {
        guard let spec, !spec.isEmpty else { return }
        guard spec.hasPrefix(Self.prefix) else { emoji = spec; return }
        let parts = spec.dropFirst(Self.prefix.count).split(separator: "|")
        icon = parts.first.map(String.init)
        for part in parts.dropFirst() {
            if part.hasPrefix("c=") { colorKey = String(part.dropFirst(2)) }
        }
    }

    static func string(icon: String, colorKey: String?) -> String {
        guard let colorKey, !colorKey.isEmpty, colorKey != "clear" else {
            return prefix + icon
        }
        return "\(prefix)\(icon)|c=\(colorKey)"
    }
}
