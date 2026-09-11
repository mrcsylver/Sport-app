import SwiftUI

struct RootView: View {
    @Environment(Session.self) private var session

    var body: some View {
        ZStack {
            LivingBackground()

            switch session.phase {
            case .booting:
                BootView()
            case .needsProfile:
                OnboardingView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .ready:
                MainTabs()
                    .transition(.opacity)
            case .failed(let why):
                FailureView(reason: why)
            }

            if let toast = session.toast {
                ToastView(text: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(Motion.settle, value: session.toast)
        .animation(Motion.settle, value: phaseKey)
    }

    private var phaseKey: String {
        switch session.phase {
        case .booting: return "booting"
        case .needsProfile: return "profile"
        case .ready: return "ready"
        case .failed: return "failed"
        }
    }
}

private struct BootView: View {
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 44, weight: .black))
                .foregroundStyle(Theme.heat)
                .scaleEffect(pulse ? 1.12 : 0.94)
                .shadow(color: Theme.flame.opacity(0.6), radius: 24)
            Text("IRON LEAGUE")
                .font(Theme.display(15, .black)).kerning(4)
                .foregroundStyle(Theme.inkMuted)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct FailureView: View {
    let reason: String
    @Environment(Session.self) private var session
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34)).foregroundStyle(Theme.ember)
            Text("Could not reach the league")
                .font(Theme.display(20, .bold)).foregroundStyle(Theme.ink)
            Text(reason)
                .font(.callout).foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await session.boot() } }
                .font(Theme.display(15, .bold))
                .foregroundStyle(Theme.flame)
        }
        .padding(32)
    }
}

struct ToastView: View {
    let text: String
    var body: some View {
        VStack {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline))
                .shadow(color: .black.opacity(0.5), radius: 14, y: 6)
                .padding(.top, 8)
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}
