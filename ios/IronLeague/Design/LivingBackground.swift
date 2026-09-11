import SwiftUI

/// The "living" part. Three slow-moving colour wells drifting behind the
/// content, drawn once per frame into a Canvas rather than animated as views,
/// so it costs almost nothing and never fights the scroll.
///
/// MeshGradient would be tidier but is iOS 18; this runs on 17 and looks the
/// same. The motion is deliberately slow — it should be felt, not watched.
struct LivingBackground: View {
    var tint: Color = Theme.flame
    var intensity: Double = 1

    var body: some View {
        ZStack {
            wells
            // The grain is drawn once and cached. Leaving it inside the
            // timeline meant a per-pixel loop over the whole screen on every
            // frame, which is a lot of work to make an OLED not band.
            Grain()
                .opacity(0.035)
                .ignoresSafeArea()
        }
    }

    private var wells: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Theme.void))

                well(&ctx, size: size,
                     at: CGPoint(x: 0.22 + 0.10 * sin(t / 11),
                                 y: 0.14 + 0.06 * cos(t / 13)),
                     radius: 0.78, color: tint.opacity(0.30 * intensity))

                well(&ctx, size: size,
                     at: CGPoint(x: 0.86 + 0.08 * cos(t / 9),
                                 y: 0.30 + 0.09 * sin(t / 15)),
                     radius: 0.62, color: Theme.violet.opacity(0.16 * intensity))

                well(&ctx, size: size,
                     at: CGPoint(x: 0.50 + 0.14 * sin(t / 17),
                                 y: 0.92 + 0.05 * cos(t / 12)),
                     radius: 0.85, color: Theme.azure.opacity(0.13 * intensity))
            }
            .blur(radius: 40)
            .ignoresSafeArea()
        }
    }

    private func well(_ ctx: inout GraphicsContext, size: CGSize,
                      at unit: CGPoint, radius: CGFloat, color: Color) {
        let r = radius * max(size.width, size.height) * 0.5
        let c = CGPoint(x: unit.x * size.width, y: unit.y * size.height)
        let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [color, color.opacity(0)]),
            center: c, startRadius: 0, endRadius: r))
    }
}

/// A whisper of noise so large flat areas do not band on OLED.
private struct Grain: View {
    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func rand() -> Double {
                seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
                return Double(seed % 1000) / 1000
            }
            let step: CGFloat = 3
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    if rand() > 0.86 {
                        ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)),
                                 with: .color(.white))
                    }
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
        .drawingGroup()
    }
}
