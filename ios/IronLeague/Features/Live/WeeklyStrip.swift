import SwiftUI

/// Raid, bounty and combo folded into one strip. Shut, it still says what
/// matters; it opens itself only when a live bounty is still undone.
struct WeeklyStrip: View {
    @Environment(Session.self) private var session
    @Binding var open: Bool
    @State private var touched = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                Haptic.tap()
                touched = true
                withAnimation(Motion.settle) { open.toggle() }
            } label: {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.text) { c in
                        Chip(text: c.text, color: c.color, filled: c.filled)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(spacing: 10) {
                    if let raid = session.raid { RaidCard(raid: raid) }
                    if let bounty = session.bounty { BountyCard(bounty: bounty) }
                    ComboCard(slices: session.combo)
                }
                .padding(.horizontal, 12).padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(Theme.surface.opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .strokeBorder(Theme.hairline))
        }
        .onChange(of: session.bounty?.mine) { _, _ in
            guard !touched, let b = session.bounty, !b.mine else { return }
            withAnimation(Motion.settle) { open = true }
        }
    }

    private struct ChipSpec { let text: String; let color: Color; let filled: Bool }

    private var chips: [ChipSpec] {
        var out: [ChipSpec] = []
        if let r = session.raid {
            out.append(.init(text: "RAID \(Int(r.fraction * 100))%",
                             color: r.done ? Theme.jade : Theme.inkMuted, filled: false))
        }
        if let b = session.bounty {
            out.append(.init(text: b.mine ? "BOUNTY DONE" : "BOUNTY \(b.points.formatted(.number.precision(.fractionLength(0))))",
                             color: b.mine ? Theme.jade : Theme.gold, filled: false))
        }
        let hit = Tuning.comboGroups.filter { g in
            (session.combo.first { $0.category == g }?.points ?? 0) >= Tuning.comboMinimum
        }.count
        out.append(.init(text: "COMBO \(hit)/5",
                         color: hit >= 3 ? Theme.jade : Theme.inkMuted, filled: false))
        return out
    }
}

/// The raid: the one job the whole league carries. The bar is the point.
struct RaidCard: View {
    let raid: Raid

    var body: some View {
        Panel(padding: 14, tint: raid.done ? Theme.jade : Theme.flame) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("LEAGUE RAID")
                        .font(Theme.display(9, .heavy)).kerning(1.6)
                        .foregroundStyle(raid.done ? Theme.jade : Theme.flame)
                    Text(raid.name)
                        .font(Theme.display(17, .black)).italic()
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    if raid.done { Chip(text: "CLEARED", color: Theme.jade, filled: true) }
                }
                Text("\(raid.descr) — together, before Sunday.")
                    .font(.caption).foregroundStyle(Theme.inkMuted)

                HeatBar(progress: raid.fraction, height: 9, done: raid.done)
                    .animation(Motion.arrive, value: raid.progress)

                HStack {
                    HStack(spacing: 4) {
                        RollingNumber(value: raid.progress, font: Theme.display(15, .black))
                        Text("/ \(Int(raid.target)) \(raid.unit)")
                            .font(.caption).foregroundStyle(Theme.inkMuted)
                    }
                    Spacer()
                    Text(raid.done ? "The whole league scores"
                                   : "\(Int(max(0, raid.target - raid.progress))) to go · \(raid.members) of you")
                        .font(.caption2).foregroundStyle(Theme.inkFaint)
                }
                if let top = raid.topName {
                    Text("Carrying it: **\(top)** with \(Int(raid.topAmount ?? 0))")
                        .font(.caption2).foregroundStyle(Theme.inkFaint)
                }
            }
        }
    }
}

struct BountyCard: View {
    let bounty: Bounty
    var body: some View {
        Panel(padding: 14, tint: bounty.mine ? Theme.jade : Theme.gold) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("WEEKLY BOUNTY")
                        .font(Theme.display(9, .heavy)).kerning(1.6)
                        .foregroundStyle(bounty.mine ? Theme.jade : Theme.gold)
                    Spacer()
                    Text("+\(Int(bounty.points))")
                        .font(Theme.display(16, .black))
                        .foregroundStyle(bounty.mine ? Theme.jade : Theme.gold)
                }
                Text(bounty.name)
                    .font(Theme.display(17, .black)).italic().foregroundStyle(Theme.ink)
                Text(bounty.descr).font(.caption).foregroundStyle(Theme.inkMuted)
                Text(bounty.mine ? "Claimed."
                     : bounty.winners > 0 ? "\(bounty.winners) already have it"
                     : "Nobody has claimed it yet")
                    .font(.caption2).foregroundStyle(Theme.inkFaint)
            }
        }
    }
}

struct ComboCard: View {
    let slices: [ComboSlice]

    private var hit: [String] {
        Tuning.comboGroups.filter { g in
            (slices.first { $0.category == g }?.points ?? 0) >= Tuning.comboMinimum
        }
    }
    private var reward: Int {
        switch hit.count { case 5: return 12; case 4: return 8; case 3: return 5; default: return 0 }
    }

    var body: some View {
        Panel(padding: 14, tint: reward > 0 ? Theme.gold : nil) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("DAILY COMBO")
                        .font(Theme.display(9, .heavy)).kerning(1.6)
                        .foregroundStyle(Theme.inkMuted)
                    Spacer()
                    Text(reward > 0 ? "+\(reward) TODAY" : "NO BONUS YET")
                        .font(Theme.display(11, .heavy))
                        .foregroundStyle(reward > 0 ? Theme.gold : Theme.inkFaint)
                }
                HStack(spacing: 6) {
                    ForEach(Tuning.comboGroups, id: \.self) { g in
                        let v = slices.first { $0.category == g }?.points ?? 0
                        let done = v >= Tuning.comboMinimum
                        VStack(spacing: 3) {
                            Text(g).font(Theme.display(9, .heavy)).kerning(0.4)
                            Text("\(Int(min(v, Tuning.comboMinimum)))/\(Int(Tuning.comboMinimum))")
                                .font(Theme.mono(9))
                        }
                        .foregroundStyle(done ? Theme.gold : Theme.inkFaint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(done ? Theme.gold.opacity(0.14) : Theme.raised)
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(done ? Theme.gold.opacity(0.5) : .clear))
                        }
                        .animation(Motion.tap, value: done)
                    }
                }
            }
        }
    }
}
