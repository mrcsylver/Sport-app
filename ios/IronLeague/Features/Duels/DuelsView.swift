import SwiftUI

/// Two kinds of fight. The weekly rivalry is handed to you — the table is
/// paired off top-down every Monday, so there is always somebody your size to
/// beat. A duel is one you pick: 24 hours, a code, whoever scores most.
struct DuelsView: View {
    @Environment(Session.self) private var session
    @State private var joinCode = ""
    @State private var showJoin = false

    private var mine: Rivalry? { session.rivalries.first { $0.mine } }
    private var others: [Rivalry] { session.rivalries.filter { !$0.mine } }
    private var live: [Challenge] { session.challenges.filter { $0.isLive } }
    private var pending: [Challenge] { session.challenges.filter { $0.isPending } }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                SectionHead(title: "THIS WEEK'S RIVALRY",
                            trailing: session.rivalries.isEmpty ? nil : "PAIRED MONDAY")

                if let m = mine {
                    RivalryCard(rivalry: m, big: true, myId: session.profile?.id)
                } else if session.rivalries.isEmpty {
                    EmptyHint(text: "Pairings appear once the league has a full week behind it.")
                } else {
                    EmptyHint(text: "You are the odd one out this week — no pairing, so beat your own numbers.")
                }

                if let d = session.duel, d.played > 0 { record(d) }

                SectionHead(title: "DUELS", trailing: "24 HOURS")
                duelBox

                ForEach(live) { c in ChallengeCard(challenge: c) }
                ForEach(pending) { c in
                    ChallengeCard(challenge: c) {
                        Task { await session.cancelDuel(c.id) }
                    }
                }

                if !others.isEmpty {
                    SectionHead(title: "EVERY PAIRING", trailing: "\(others.count)")
                        .padding(.top, 6)
                    ForEach(others) { r in
                        RivalryCard(rivalry: r, big: false, myId: session.profile?.id)
                    }
                }

                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .animation(Motion.settle, value: session.rivalries.count)
        }
        .scrollIndicators(.hidden)
        .refreshable { await session.loadDuelsTab() }
    }

    private func record(_ d: DuelRecord) -> some View {
        Panel(padding: 14) {
            HStack(spacing: 0) {
                stat("PLAYED", d.played, Theme.inkMuted)
                stat("WON", d.won, Theme.jade)
                stat("LOST", d.lost, Theme.flame)
                stat("DRAWN", d.drawn, Theme.inkFaint)
                stat("BEST RUN", d.bestStreak, Theme.gold)
            }
        }
    }

    private func stat(_ label: String, _ value: Int, _ colour: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(Theme.display(20, .black))
                .foregroundStyle(colour)
            Text(label)
                .font(Theme.display(8, .heavy)).kerning(0.8)
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity)
    }

    private var duelBox: some View {
        Panel(padding: 14) {
            VStack(spacing: 12) {
                Text("Open a duel and send the code to anyone in the league. It starts the moment they accept and runs for 24 hours.")
                    .font(.caption).foregroundStyle(Theme.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Button {
                        Haptic.solid()
                        Task { await session.openDuel() }
                    } label: {
                        Text("OPEN A DUEL")
                            .font(Theme.display(13, .black)).kerning(1)
                            .foregroundStyle(Theme.void)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.heat))
                    }
                    .buttonStyle(.plain).pressable()

                    Button {
                        Haptic.tap()
                        withAnimation(Motion.tap) { showJoin.toggle() }
                    } label: {
                        Text("HAVE A CODE")
                            .font(Theme.display(13, .black)).kerning(1)
                            .foregroundStyle(Theme.inkMuted)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.raised))
                    }
                    .buttonStyle(.plain).pressable()
                }

                if showJoin {
                    HStack(spacing: 10) {
                        TextField("CODE", text: $joinCode)
                            .font(Theme.mono(17, .bold))
                            .foregroundStyle(Theme.ink)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(.vertical, 10).padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.raised))
                        Button("ACCEPT") {
                            Task {
                                if await session.acceptDuel(code: joinCode) {
                                    joinCode = ""
                                    withAnimation(Motion.tap) { showJoin = false }
                                }
                            }
                        }
                        .font(Theme.display(13, .black))
                        .foregroundStyle(Theme.flame)
                        .disabled(joinCode.count < 4)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

/// A pairing. Big for yours, dense for everyone else's — same component, so
/// the two never drift apart visually.
struct RivalryCard: View {
    let rivalry: Rivalry
    let big: Bool
    let myId: UUID?

    private var aLeads: Bool { rivalry.aPoints > rivalry.bPoints }
    private var level: Bool { rivalry.aPoints == rivalry.bPoints }

    var body: some View {
        Panel(padding: big ? 16 : 12, tint: rivalry.mine ? Theme.flame : nil) {
            if big {
                VStack(spacing: 12) {
                    side(name: rivalry.aName, avatar: rivalry.aAvatar,
                         points: rivalry.aPoints, id: rivalry.aId, leads: aLeads && !level)
                    HStack(spacing: 10) {
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                        Text(level ? "LEVEL" : "VS")
                            .font(Theme.display(15, .black)).italic().kerning(1.6)
                            .foregroundStyle(Theme.flame)
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                    }
                    side(name: rivalry.bName, avatar: rivalry.bAvatar,
                         points: rivalry.bPoints, id: rivalry.bId, leads: !aLeads && !level)
                    Text(margin)
                        .font(.caption).foregroundStyle(Theme.inkMuted)
                }
            } else {
                HStack(spacing: 10) {
                    compact(rivalry.aName, rivalry.aPoints, aLeads && !level)
                    Text("VS")
                        .font(Theme.display(9, .heavy)).kerning(1)
                        .foregroundStyle(Theme.inkFaint)
                    compact(rivalry.bName, rivalry.bPoints, !aLeads && !level)
                }
            }
        }
    }

    private var margin: String {
        let gap = abs(rivalry.aPoints - rivalry.bPoints)
        if gap == 0 { return "Dead level. Whoever trains tonight is ahead." }
        let leader = aLeads ? rivalry.aName : rivalry.bName
        return "\(leader) leads by \(Int(gap)) points."
    }

    private func side(name: String, avatar: String?, points: Double,
                      id: UUID, leads: Bool) -> some View {
        HStack(spacing: 11) {
            Mark(spec: avatar, name: name, tint: leads ? Theme.jade : nil)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(Theme.display(17, .heavy))
                    .foregroundStyle(leads ? Theme.jade : Theme.ink)
                    .lineLimit(1)
                if id == myId {
                    Text("YOU").font(Theme.display(8, .heavy))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            Spacer()
            RollingNumber(value: points, font: Theme.display(20, .black),
                          color: leads ? Theme.jade : Theme.ink)
        }
    }

    private func compact(_ name: String, _ points: Double, _ leads: Bool) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(Theme.display(13, .heavy))
                .foregroundStyle(leads ? Theme.jade : Theme.ink)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text("\(Int(points))")
                .font(Theme.mono(11, .bold))
                .foregroundStyle(leads ? Theme.jade : Theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ChallengeCard: View {
    let challenge: Challenge
    var onCancel: (() -> Void)? = nil

    var body: some View {
        Panel(padding: 14, tint: challenge.isLive ? (challenge.winning ? Theme.jade : Theme.flame) : nil) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Chip(text: challenge.status,
                         color: challenge.isLive ? Theme.jade : Theme.gold,
                         filled: challenge.isLive)
                    Text(challenge.leagueName)
                        .font(.caption).foregroundStyle(Theme.inkFaint)
                    Spacer()
                    if challenge.isPending {
                        Text(challenge.code)
                            .font(Theme.mono(15, .bold))
                            .foregroundStyle(Theme.gold)
                    } else if let ends = challenge.endsAt {
                        Text(ends, style: .relative)
                            .font(Theme.mono(11))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }

                if challenge.isPending {
                    Text(challenge.iStarted
                         ? "Send that code to whoever you want to fight."
                         : "Waiting to start.")
                        .font(.caption).foregroundStyle(Theme.inkMuted)
                    if let onCancel, challenge.iStarted {
                        Button("Cancel this duel", action: onCancel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.flame)
                    }
                } else {
                    HStack(spacing: 12) {
                        duelSide(challenge.meName, challenge.mePoints, challenge.winning)
                        Text("VS").font(Theme.display(10, .heavy)).foregroundStyle(Theme.inkFaint)
                        duelSide(challenge.foeName ?? "—", challenge.foePoints ?? 0, !challenge.winning)
                    }
                }
            }
        }
    }

    private func duelSide(_ name: String, _ points: Double, _ ahead: Bool) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(Theme.display(13, .heavy))
                .foregroundStyle(ahead ? Theme.jade : Theme.ink)
                .lineLimit(1)
            RollingNumber(value: points, font: Theme.display(19, .black),
                          color: ahead ? Theme.jade : Theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }
}
