import SwiftUI

/// The whole bank — 118 exercises — without ever feeling like 118 exercises.
/// Type and it filters; don't type and you get the handful you actually use,
/// then eight folded groups. Same discipline as the web app's picker.
struct ExercisePicker: View {
    @Binding var selected: String
    var onPick: (String) -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var openCat: String?
    @FocusState private var searching: Bool

    private static let order = ["PUSH", "PULL", "LEGS", "CORE",
                                "CARDIO", "SPORT", "GYM", "RECOVERY"]

    private var matches: [Exercise] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        return session.exercises
            .filter { $0.matches(q) }
            .sorted { a, b in
                // a name that starts with what you typed always wins
                let sa = a.name.lowercased().hasPrefix(q), sb = b.name.lowercased().hasPrefix(q)
                if sa != sb { return sa }
                return a.sort < b.sort
            }
            .prefix(40)
            .map { $0 }
    }

    private var recents: [Exercise] {
        Recents.keys.compactMap { key in session.exercises.first { $0.key == key } }
    }

    private func group(_ cat: String) -> [Exercise] {
        session.exercises.filter { $0.cat == cat }.sorted { $0.sort < $1.sort }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8, pinnedViews: []) {
                    search

                    if !query.isEmpty {
                        if matches.isEmpty {
                            Text("Nothing matches “\(query)”.")
                                .font(.subheadline).foregroundStyle(Theme.inkFaint)
                                .frame(maxWidth: .infinity).padding(.vertical, 40)
                        } else {
                            ForEach(matches) { ex in row(ex) }
                        }
                    } else {
                        if !recents.isEmpty {
                            label("RECENT")
                            ForEach(recents) { ex in row(ex) }
                        }
                        label("EVERYTHING")
                        ForEach(Self.order, id: \.self) { cat in
                            let items = group(cat)
                            if !items.isEmpty { folder(cat, items) }
                        }
                    }
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Theme.void.opacity(0.6))
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(Theme.display(15, .bold))
                        .foregroundStyle(Theme.flame)
                }
            }
        }
    }

    // MARK: pieces

    private var search: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            TextField("Search 118 exercises", text: $query)
                .focused($searching)
                .font(.body)
                .foregroundStyle(Theme.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.inkFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(Theme.raised)
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .strokeBorder(searching ? Theme.flame.opacity(0.6) : Theme.hairline))
        }
        .animation(Motion.tap, value: searching)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Theme.display(10, .heavy)).kerning(1.6)
            .foregroundStyle(Theme.inkFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
    }

    @ViewBuilder
    private func folder(_ cat: String, _ items: [Exercise]) -> some View {
        let open = openCat == cat

        VStack(spacing: 6) {
            Button {
                Haptic.tap()
                withAnimation(Motion.settle) { openCat = open ? nil : cat }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: CategoryArt.symbol(cat))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(open ? Theme.flame : Theme.inkMuted)
                        .frame(width: 22)
                    Text(cat)
                        .font(Theme.display(15, .black)).kerning(1)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(items.count)")
                        .font(Theme.mono(11)).foregroundStyle(Theme.inkFaint)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(.horizontal, 14).padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(spacing: 6) {
                    ForEach(items) { ex in row(ex) }
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(Theme.surface.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .strokeBorder(Theme.hairline))
        }
    }

    private func row(_ ex: Exercise) -> some View {
        Button {
            Haptic.solid()
            Recents.remember(ex.key)
            selected = ex.key
            onPick(ex.key)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: CategoryArt.symbol(ex.cat))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ex.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(rateHint(ex))
                        .font(.caption2).foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if ex.key == selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.flame)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(ex.key == selected ? Theme.flame.opacity(0.12) : Theme.raised)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    /// What a person actually wants to know: what does one of these pay?
    private func rateHint(_ ex: Exercise) -> String {
        if ex.isGym { return "scored from the bar and your bodyweight" }
        let mode = ex.firstMode
        guard let m = ex.modes[mode], let rate = m.rate else { return ex.cat.lowercased() }
        func n(_ v: Double) -> String {
            v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v)
        }
        switch mode {
        case "reps":    return rate == 1 ? "1 pt per rep" : "\(n(rate)) pts per rep"
        case "seconds": return rate >= 1 ? "\(n(rate)) pts per second" : "1 pt per \(n(1 / rate)) seconds"
        case "minutes": return "\(n(rate * 60)) pts per hour"
        case "km":      return "\(n(rate)) pts per km"
        default:        return "\(n(rate)) pts per session"
        }
    }
}

/// The last eight things you logged, kept on the device. Not worth a table on
/// the server — it is a convenience, not data.
enum Recents {
    private static let store = "recentExercises"

    static var keys: [String] {
        UserDefaults.standard.stringArray(forKey: store) ?? []
    }

    static func remember(_ key: String) {
        var list = keys.filter { $0 != key }
        list.insert(key, at: 0)
        UserDefaults.standard.set(Array(list.prefix(8)), forKey: store)
    }
}
