import SwiftUI

/// Logging has to be fast enough to do between sets. One screen: pick, set an
/// amount, watch the points, add. Multiple exercises can go in before the
/// sheet closes, because that is how a real session works.
struct LogSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var picking = false
    @State private var key = "pushups"
    @State private var mode = "reps"
    @State private var amount: Double = 10
    @State private var bodyweight: String = ""
    @State private var load: String = ""
    @State private var added: [Entry] = []
    @FocusState private var focus: Field?

    private enum Field { case bw, load }

    /// What has gone in since the sheet opened — a real session is several
    /// exercises, so the sheet stays put and keeps a running total.
    private struct Entry: Identifiable {
        let id = UUID()
        let name: String
        let points: Double
    }

    /// Whether today is a rest day is asked when the sheet opens, not once at
    /// launch: the league may not have loaded yet at launch, and somebody can
    /// leave the app open across midnight or switch to a league that rests on
    /// a different day.
    private var restOnly: Bool { LeagueClock.isRestDay(session.league) }

    private var restNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.azure)
            VStack(alignment: .leading, spacing: 3) {
                Text("REST DAY")
                    .font(Theme.display(12, .heavy)).kerning(1.4)
                    .foregroundStyle(Theme.ink)
                Text("The league is shut today. One stretching session counts, "
                     + "and only once. It opens again at midnight.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Theme.azure.opacity(0.35), lineWidth: 1))
    }

    private var exercise: Exercise? { session.exercise(key) }
    private var isGym: Bool { exercise?.isGym ?? false }

    private var bwKg: Double? {
        guard let v = Double(bodyweight) else { return nil }
        return session.profile?.usesPounds == true ? v / 2.20462 : v
    }
    private var loadKg: Double? {
        guard let v = Double(load) else { return nil }
        return session.profile?.usesPounds == true ? v / 2.20462 : v
    }
    private var unitLabel: String { session.profile?.usesPounds == true ? "LB" : "KG" }

    /// What the movement is worth, before this week's budget is considered.
    private var rawPreview: Double {
        session.points(key: key, mode: mode, amount: amount,
                       bodyweightKg: bwKg, loadKg: loadKg)
    }
    /// What this set will actually score. The two differ once a week's budget
    /// is full, and the big number has to be the one that lands on the board.
    private var preview: Double {
        session.scoredDelta(key: key, raw: rawPreview)
    }
    private var weekCap: Double { exercise?.weekCap ?? Scoring.defaultCap }
    private var weekUsed: Double { session.weekEx[key] ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if restOnly { restNote }
                    picker
                    if isGym { gymFields }
                    modeRow
                    stepper
                    quickRow
                    previewBar
                    budgetBar
                    HeatButton(title: "ADD", systemImage: "plus.circle.fill") { add() }
                    if !added.isEmpty { sessionList }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.void.opacity(0.6))
            .navigationTitle("Log workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.display(15, .bold))
                        .foregroundStyle(Theme.flame)
                }
            }
            .sheet(isPresented: $picking) {
                ExercisePicker(selected: $key) { chosen in
                    key = chosen
                    mode = session.exercise(chosen)?.firstMode ?? "reps"
                    amount = Defaults.amount(for: mode, key: chosen)
                    if isGym, bodyweight.isEmpty, let bw = session.profile?.bodyweight {
                        let shown = session.profile?.usesPounds == true ? bw * 2.20462 : bw
                        bodyweight = String(format: "%.0f", shown)
                    }
                }
            }
        }
        .onAppear {
            if let bw = session.profile?.bodyweight, bodyweight.isEmpty {
                let shown = session.profile?.usesPounds == true ? bw * 2.20462 : bw
                bodyweight = String(format: "%.0f", shown)
            }
        }
    }

    // MARK: pieces

    private var picker: some View {
        Button {
            Haptic.tap(); picking = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: CategoryArt.symbol(exercise?.cat ?? "PUSH"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise?.name ?? "Pick an exercise")
                        .font(Theme.display(19, .heavy))
                        .foregroundStyle(Theme.ink)
                    if let v = exercise?.variants, !v.isEmpty {
                        Text(v).font(.caption2).foregroundStyle(Theme.inkFaint)
                            .lineLimit(2).multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                Text("CHANGE").font(Theme.display(10, .heavy)).kerning(1)
                    .foregroundStyle(Theme.flame)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.raised)
                    .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                        .strokeBorder(Theme.hairline))
            }
        }
        .buttonStyle(.plain)
        .pressable()
    }

    private var gymFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                field("YOUR BODYWEIGHT (\(unitLabel))", text: $bodyweight, focus: .bw)
                field("WEIGHT LIFTED (\(unitLabel))", text: $load, focus: .load)
            }
            Text("Just the bar and plates — your own weight is counted for you.")
                .font(.caption2).foregroundStyle(Theme.inkFaint)
        }
    }

    private func field(_ label: String, text: Binding<String>, focus f: Field) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(Theme.display(9, .heavy)).kerning(0.8)
                .foregroundStyle(Theme.inkFaint)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .focused($focus, equals: f)
                .font(Theme.display(22, .black))
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 12).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.raised))
        }
    }

    @ViewBuilder private var modeRow: some View {
        if let ex = exercise, ex.modes.count > 1 {
            HStack(spacing: 8) {
                ForEach(ex.modes.keys.sorted(), id: \.self) { m in
                    Button {
                        Haptic.tap()
                        withAnimation(Motion.tap) {
                            mode = m; amount = Defaults.amount(for: m, key: key)
                        }
                    } label: {
                        Text(Defaults.unitName(m))
                            .font(Theme.display(12, .heavy)).kerning(0.8)
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(mode == m ? Theme.flame.opacity(0.18) : Theme.raised)
                                    .overlay(RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(mode == m ? Theme.flame : .clear))
                            }
                            .foregroundStyle(mode == m ? Theme.flame : Theme.inkMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var stepper: some View {
        HStack(spacing: 14) {
            stepButton("minus") { adjust(-1) }
            VStack(spacing: 0) {
                RollingNumber(value: amount, font: Theme.display(44, .black),
                              decimals: amount < 10 && mode == "km" ? 1 : 0)
                Text(Defaults.unitName(mode))
                    .font(Theme.display(10, .heavy)).kerning(1.4)
                    .foregroundStyle(Theme.inkFaint)
            }
            .frame(maxWidth: .infinity)
            stepButton("plus") { adjust(1) }
        }
    }

    private func stepButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptic.tap(); action() } label: {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Theme.ink)
                .frame(width: 58, height: 58)
                .background(Circle().fill(Theme.raised))
                .overlay(Circle().strokeBorder(Theme.hairline))
        }
        .buttonStyle(.plain).pressable(scale: 0.92)
    }

    private var quickRow: some View {
        HStack(spacing: 8) {
            ForEach(Defaults.quick(for: mode, key: key), id: \.self) { q in
                Button {
                    Haptic.tap()
                    withAnimation(Motion.tap) { amount = q }
                } label: {
                    Text(q.formatted(.number.precision(.fractionLength(0))))
                        .font(Theme.display(14, .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.raised))
                        .foregroundStyle(Theme.inkMuted)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var previewBar: some View {
        HStack {
            Text(rateLabel).font(.caption).foregroundStyle(Theme.inkFaint)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                RollingNumber(value: preview, font: Theme.display(28, .black),
                              color: preview > 0 ? Theme.ink : Theme.inkFaint,
                              decimals: preview < 100 ? 1 : 0)
                Text("PTS").font(Theme.display(11, .heavy)).foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.surface)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Theme.heat).frame(width: 3)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
        }
    }

    /// How full this movement's week is, drawn before anything is committed.
    /// Worded as a week filling up rather than as points taken away: a rule
    /// you only meet after the fact is indistinguishable from a bug.
    private var budgetBar: some View {
        let after = weekUsed + rawPreview
        let tier = Scoring.tier(after: after, cap: weekCap)
        let colour: Color = tier == .quarter ? Theme.flame
                          : tier == .half ? Theme.gold : Theme.jade
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline)
                    Capsule().fill(colour)
                        .frame(width: geo.size.width * min(1, after / weekCap))
                }
            }
            .frame(height: 4)
            Text(Scoring.budgetLine(name: exercise?.name ?? key, after: after,
                                    cap: weekCap, movements: session.weekEx.count))
                .font(.caption2.monospaced())
                .foregroundStyle(tier == .full ? Theme.inkFaint : colour)
        }
        .animation(Motion.arrive, value: after)
    }

    private var rateLabel: String {
        guard let m = exercise?.modes[mode] else { return "" }
        if m.isGym { return "from your bodyweight and the bar" }
        let rate = m.rate ?? 0
        switch mode {
        case "minutes": return "\(fmt(rate * 60)) pts / hour"
        case "seconds": return rate >= 1 ? "\(fmt(rate)) pts / sec" : "1 pt / \(fmt(1 / rate)) sec"
        case "km":      return "\(fmt(rate)) pts / km"
        case "flat":    return "\(fmt(rate)) pts / session"
        default:        return rate == 1 ? "1 pt / rep" : "\(fmt(rate)) pts / rep"
        }
    }
    private func fmt(_ v: Double) -> String {
        (v * 100).rounded() / 100 == (v).rounded() ? String(Int(v.rounded()))
                                                   : String(format: "%.2g", v)
    }

    private var sessionList: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("THIS SESSION").font(Theme.display(10, .heavy)).kerning(1.4)
                        .foregroundStyle(Theme.inkFaint)
                    Spacer()
                    Text("\(Int(added.reduce(0) { $0 + $1.points })) PTS")
                        .font(Theme.display(14, .black)).foregroundStyle(Theme.gold)
                }
                ForEach(added) { row in
                    HStack {
                        Text(row.name).font(.subheadline).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("+\(Int(row.points))").font(Theme.display(14, .bold))
                            .foregroundStyle(Theme.flame)
                    }
                }
            }
        }
        .transition(.scale(scale: 0.97).combined(with: .opacity))
    }

    // MARK: actions

    private func adjust(_ direction: Double) {
        let step = Defaults.step(for: mode)
        amount = max(step, amount + direction * step)
    }

    private func add() {
        guard preview > 0 else {
            session.show(isGym ? "A gym lift needs your bodyweight and the weight lifted."
                               : "Set an amount first.")
            Haptic.refuse()
            return
        }
        let name = exercise?.name ?? key
        let gained = preview                  // what it scores, not what it is worth
        let spent = weekUsed + rawPreview     // where the budget stands afterwards
        Task {
            let ok = await session.log(key: key, mode: mode, amount: amount,
                                       bodyweightKg: bwKg, loadKg: loadKg)
            if ok {
                /* refresh() has already re-read the week, but the sheet stays
                   open and the next set has to be priced against a budget that
                   includes this one. */
                session.weekEx[key, default: 0] = max(session.weekEx[key] ?? 0, spent)
                withAnimation(Motion.arrive) {
                    added.append(Entry(name: name, points: gained))
                }
            }
        }
    }
}

enum Defaults {
    static func unitName(_ mode: String) -> String {
        switch mode {
        case "reps": return "REPS"; case "seconds": return "SECONDS"
        case "minutes": return "MINUTES"; case "km": return "KM"
        default: return "SESSIONS"
        }
    }
    static func step(for mode: String) -> Double {
        switch mode { case "seconds": return 5; case "km": return 0.5; default: return 1 }
    }
    static func amount(for mode: String, key: String) -> Double {
        switch mode {
        case "seconds": return 30; case "minutes": return 30
        case "km": return 5; case "flat": return 1; default: return 10
        }
    }
    static func quick(for mode: String, key: String) -> [Double] {
        switch mode {
        case "seconds": return [15, 30, 60, 120]
        case "minutes": return [20, 30, 45, 60]
        case "km":      return [1, 3, 5, 10]
        case "flat":    return [1, 2]
        default:        return [5, 10, 20, 50]
        }
    }
}

enum CategoryArt {
    static func symbol(_ cat: String) -> String {
        switch cat {
        case "PUSH": return "figure.strengthtraining.traditional"
        case "PULL": return "figure.climbing"
        case "LEGS": return "figure.run"
        case "CORE": return "figure.core.training"
        case "CARDIO": return "heart.fill"
        case "SPORT": return "sportscourt.fill"
        case "GYM": return "dumbbell.fill"
        default: return "figure.flexibility"
        }
    }
}
