import SwiftUI
import UIKit

/// Motion is a language too. Three springs, used consistently, read as one
/// app; a different animation on every view reads as noise.
enum Motion {
    /// Anything a finger caused: taps, toggles, sheet content.
    static let tap = Animation.spring(response: 0.32, dampingFraction: 0.72)
    /// Layout settling — rows reordering, sections opening.
    static let settle = Animation.spring(response: 0.5, dampingFraction: 0.82)
    /// Something arriving on its own: a rank change, a raid ticking up.
    static let arrive = Animation.spring(response: 0.7, dampingFraction: 0.65)
    /// Ambient, never-ending background movement.
    static let drift = Animation.easeInOut(duration: 7).repeatForever(autoreverses: true)
}

/// A number that rolls to its new value instead of snapping. Used everywhere
/// points appear, because watching a total climb is most of the reward.
struct RollingNumber: View, Animatable {
    var value: Double
    var font: Font
    var color: Color = Theme.ink
    var decimals: Int = 0

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(value, format: .number.precision(.fractionLength(decimals)))
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .contentTransition(.numericText(value: value))
    }
}

extension View {
    /// Press feedback that feels physical rather than like a web hover.
    func pressable(scale: CGFloat = 0.97) -> some View {
        buttonStyle(PressStyle(scale: scale))
    }
}

struct PressStyle: ButtonStyle {
    var scale: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}

/// Haptics, wrapped so call sites stay readable.
enum Haptic {
    static func tap()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func solid()   { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func win()     { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func refuse()  { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

/// Pairs a row with its position.
///
/// `ForEach(Array(x.enumerated()), id: \.element.id)` reads a key path through
/// a tuple, which is exactly the sort of thing that is legal in one Swift
/// version and not another. This says the same thing with a real type.
struct Ranked<T: Identifiable>: Identifiable {
    let index: Int
    let value: T
    var id: T.ID { value.id }
}

extension Array where Element: Identifiable {
    /// 1-based rank alongside each element.
    var ranked: [Ranked<Element>] {
        enumerated().map { Ranked(index: $0.offset + 1, value: $0.element) }
    }
}
