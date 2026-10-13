import AVKit
import SwiftUI

/// The twenty-five second explainer, once per person per cut.
///
/// STREAMED, NOT BUNDLED. It plays the same file the web app serves rather
/// than a copy inside the binary. That keeps 1.7 MB out of the download, and
/// — the part that actually matters — means a new cut reaches iOS the day it
/// is rendered instead of whenever an App Store review clears.
///
/// MUTED, THEN A TAP. iOS will play audio here if asked, but a clip that
/// starts talking out loud in a lecture theatre is worse than a quiet one, so
/// it opens silent and says so. The same choice the web app makes, for a
/// different reason: there it is the browser refusing, here it is manners.
enum Promo {
    /// Bump when the clip CHANGES ENOUGH TO BE WORTH SHOWING AGAIN, not when
    /// the app version moves. Must match PROMO_CUT in app.js. Cut 2 is the
    /// one with music; cut 1 was silent.
    static let cut = "2"
    static let url = URL(string: "https://mrcsylver.github.io/Sport-app/promo.mp4")!
    private static let key = "ironleague.promo.seen"

    static var seen: Bool { UserDefaults.standard.string(forKey: key) == cut }
    static func markSeen() { UserDefaults.standard.set(cut, forKey: key) }
}

struct PromoView: View {
    var onClose: () -> Void

    @State private var player = AVPlayer(url: Promo.url)
    @State private var muted = true
    @State private var ended = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PromoPlayer(player: player)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                HStack {
                    Spacer()
                    Button(action: close) {
                        Text("SKIP")
                            .font(Theme.display(12, .heavy)).kerning(1.6)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.3)))
                    }
                }
                Spacer()
                HStack(alignment: .bottom) {
                    Button {
                        muted.toggle()
                        player.isMuted = muted
                    } label: {
                        Label(muted ? "TAP FOR SOUND" : "SOUND ON",
                              systemImage: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(Theme.display(12, .heavy)).kerning(1.4)
                            .foregroundStyle(muted ? Theme.ink : Theme.flame)
                            .padding(.horizontal, 15).padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(
                                (muted ? Theme.ink : Theme.flame).opacity(0.35)))
                    }
                    Spacer()
                }
                if ended {
                    Button(action: close) {
                        Text("START")
                            .font(Theme.display(17, .heavy)).kerning(1.4)
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Theme.flame, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .onAppear {
            Promo.markSeen()
            player.isMuted = true
            player.play()
        }
        .onDisappear { player.pause() }
        /// At the end SKIP would be the wrong word for the only button left.
        .onReceive(NotificationCenter.default.publisher(
            for: AVPlayerItem.didPlayToEndTimeNotification)) { _ in
            ended = true
        }
    }

    private func close() {
        player.pause()
        onClose()
    }
}

/// AVKit's own VideoPlayer draws transport controls over the picture, which
/// is wrong for a 25-second clip that already has SKIP on it. This is the
/// layer and nothing else.
private struct PromoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerBox {
        let v = PlayerBox()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspect
        v.backgroundColor = .black
        return v
    }

    func updateUIView(_ uiView: PlayerBox, context: Context) {}
}

final class PlayerBox: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
