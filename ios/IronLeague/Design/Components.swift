import SwiftUI

/// A card that reads as a physical surface: a real material, a hairline edge
/// catching light at the top, and a soft shadow beneath.
struct Panel<Content: View>: View {
    var padding: CGFloat = 16
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.surface)
                    .overlay {
                        if let tint {
                            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [tint.opacity(0.18), .clear],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                            .strokeBorder(LinearGradient(
                                colors: [.white.opacity(0.14), .white.opacity(0.03)],
                                startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
            }
    }
}

/// The primary action. Deliberately the loudest thing on any screen it is on.
struct HeatButton: View {
    var title: String
    var systemImage: String? = nil
    var action: () -> Void

    @State private var shine = false

    var body: some View {
        Button {
            Haptic.solid()
            action()
        } label: {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 17, weight: .bold))
                }
                Text(title)
                    .font(Theme.display(19, .black))
                    .kerning(1.2)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                        .fill(Theme.heat)
                    // a slow sheen crossing the button, so it never looks dead
                    RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                        .fill(LinearGradient(
                            colors: [.clear, .white.opacity(0.35), .clear],
                            startPoint: .leading, endPoint: .trailing))
                        .rotationEffect(.degrees(18))
                        .offset(x: shine ? 240 : -240)
                        .mask(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
                }
                .shadow(color: Theme.flame.opacity(0.45), radius: 20, y: 8)
            }
        }
        .pressable(scale: 0.975)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: false)) {
                shine = true
            }
        }
    }
}

/// A small status pill. Used for grades, divisions, combo state.
struct Chip: View {
    var text: String
    var color: Color = Theme.inkMuted
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(Theme.display(10, .heavy))
            .kerning(0.8)
            .foregroundStyle(filled ? Theme.void : color)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background {
                Capsule().fill(filled ? color : color.opacity(0.14))
            }
    }
}

/// A progress track with the heat gradient and a soft glow at the head.
struct HeatBar: View {
    var progress: Double            // 0…1
    var height: CGFloat = 8
    var done: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.raised)
                Capsule()
                    .fill(done ? AnyShapeStyle(Theme.jade) : AnyShapeStyle(Theme.heat))
                    .frame(width: max(height, geo.size.width * min(max(progress, 0), 1)))
                    .shadow(color: (done ? Theme.jade : Theme.ember).opacity(0.7),
                            radius: 8, y: 0)
            }
        }
        .frame(height: height)
    }
}

/// Section heading used across every tab.
struct SectionHead: View {
    var title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.display(24, .black))
                .italic()
                .foregroundStyle(Theme.ink)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }
}
