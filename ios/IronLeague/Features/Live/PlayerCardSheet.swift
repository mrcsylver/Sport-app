import SwiftUI

/// Who somebody is, when you tap their face on the board.
///
/// Tapping a NAME opens that person's week, which is what you want when you
/// are reading a board. Tapping their FACE opens who they are, which is what
/// you want when somebody you do not recognise is above you — and on a
/// campus, that is most of them.
///
/// Not a tab. A tab shows your own profile, and the app already has two
/// places that do. The thing worth seeing is somebody else's, and the only
/// way to ask for that is to point at them.
struct PlayerCardSheet: View {
    let profileId: UUID
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var card: PlayerCard?
    @State private var missing = false
    @State private var draft = ""
    @State private var saving = false

    private var isMine: Bool { card?.profileId == session.profile?.id }

    private var grade: Grade? { card.map { Grade.reached($0.lifetime) } ?? nil }

    var body: some View {
        VStack(spacing: 0) {
            if let c = card {
                content(c)
            } else if missing {
                Text("That profile is not in any of your leagues.")
                    .font(.callout).foregroundStyle(Theme.inkFaint)
                    .multilineTextAlignment(.center)
                    .padding(30)
            } else {
                /// No spinner view type needed: a card is one round trip on
                /// a tap, and a line of text that disappears reads calmer
                /// than something that spins for 200ms.
                Text("…")
                    .font(Theme.display(22, .heavy))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(40)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Theme.void)
        .task {
            do {
                card = try await API.shared.playerCard(profileId)
                missing = card == nil
                draft = card?.bio ?? ""
            } catch {
                missing = true
            }
        }
    }

    @ViewBuilder
    private func content(_ c: PlayerCard) -> some View {
        VStack(spacing: 10) {
            Mark(spec: c.avatar, name: c.displayName,
                 tint: grade.map { Grade.color(tier: $0.tier) },
                 ring: session.frameArt(c.frame))
                .frame(width: 96, height: 96)
                .padding(.top, 28)

            Text(c.displayName)
                .font(Theme.display(26, .heavy))
                .foregroundStyle(Tint.nameColor(c.nameColor) ?? Theme.ink)

            Text(grade?.name ?? "UNRANKED")
                .font(Theme.display(11, .heavy)).kerning(1.6)
                .foregroundStyle(Theme.inkFaint)

            VStack(spacing: 2) {
                Text(c.lifetime.formatted(.number.precision(.fractionLength(0))))
                    .font(Theme.mono(30, .bold))
                    .foregroundStyle(Theme.ink)
                Text("LIFETIME POINTS")
                    .font(Theme.display(9, .heavy)).kerning(1.8)
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) { Divider().background(Theme.hairline) }
            .overlay(alignment: .bottom) { Divider().background(Theme.hairline) }
            .padding(.top, 8)

            if isMine {
                /// The line is about you, so the place to write it is the
                /// place you see it — not a sheet three taps away whose
                /// result you then have to come back here to look at.
                VStack(spacing: 8) {
                    TextField("Say something. Third year, chasing a one-arm…",
                              text: $draft, axis: .vertical)
                        .font(.callout)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1...3)
                        .padding(.vertical, 9).padding(.horizontal, 11)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.raised))
                        .onChange(of: draft) { _, new in
                            if new.count > 140 { draft = String(new.prefix(140)) }
                        }
                    HStack {
                        Text("\(140 - draft.count) left")
                            .font(Theme.mono(11, .bold))
                            .foregroundStyle(Theme.inkFaint)
                        Spacer()
                        Button(saving ? "…" : "SAVE") {
                            saving = true
                            Task {
                                await session.saveBio(draft)
                                card = try? await API.shared.playerCard(profileId)
                                saving = false
                            }
                        }
                        .font(Theme.display(13, .black))
                        .foregroundStyle(Theme.flame)
                        .disabled(saving)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 6)
            } else if let bio = c.bio, !bio.isEmpty {
                Text(bio)
                    .font(.callout)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)
                    .padding(.top, 4)
            }

            if !c.pinnedBadges.isEmpty {
                HStack(spacing: 10) {
                    ForEach(c.pinnedBadges, id: \.self) { key in
                        WornBadge(key: key)
                    }
                }
                .padding(.top, 2)
            }

            if let since = c.joinedAt {
                Text("Training here since "
                     + since.formatted(.dateTime.month(.wide).year()))
                    .font(.caption2).foregroundStyle(Theme.inkFaint)
                    .padding(.top, 6)
            }

            Color.clear.frame(height: 24)
        }
    }
}
