import SwiftUI

/// Somebody's log, folded into days. A week of training is thirty entries;
/// a flat list of thirty rows tells you nothing, whereas "Monday · 240 pts"
/// tells you everything at a glance and opens if you actually care.
struct FeedList: View {
    let rows: [WorkoutRow]
    let exercises: [Exercise]
    var onDelete: ((WorkoutRow) -> Void)? = nil

    @State private var openDay: String?

    private struct Day: Identifiable {
        let id: String
        let label: String
        let points: Double
        let rows: [WorkoutRow]
    }

    private var days: [Day] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Config.timeZone

        let stamped = rows.compactMap { row -> (Date, WorkoutRow)? in
            guard let d = row.createdAt else { return nil }
            return (cal.startOfDay(for: d), row)
        }
        let grouped = Dictionary(grouping: stamped, by: \.0)

        return grouped.keys.sorted(by: >).map { day in
            let items = grouped[day]!.map(\.1)
            return Day(id: ISO8601DateFormatter().string(from: day),
                       label: Self.label(for: day, calendar: cal),
                       points: items.reduce(0) { $0 + $1.points },
                       rows: items.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) })
        }
    }

    var body: some View {
        if rows.isEmpty {
            Text("Nothing logged yet this week.")
                .font(.caption).foregroundStyle(Theme.inkFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
        } else {
            VStack(spacing: 6) {
                ForEach(days) { day in
                    dayBlock(day)
                }
            }
        }
    }

    @ViewBuilder
    private func dayBlock(_ day: Day) -> some View {
        let open = openDay == day.id

        VStack(spacing: 0) {
            Button {
                Haptic.tap()
                withAnimation(Motion.tap) { openDay = open ? nil : day.id }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Theme.inkFaint)
                        .rotationEffect(.degrees(open ? 90 : 0))
                    Text(day.label)
                        .font(Theme.display(12, .heavy)).kerning(0.6)
                        .foregroundStyle(Theme.inkMuted)
                    Spacer()
                    Text("\(day.rows.count) · \(Int(day.points)) PTS")
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.inkFaint)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(spacing: 5) {
                    ForEach(day.rows) { row in
                        entry(row)
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.void.opacity(0.35))
        }
    }

    private func entry(_ row: WorkoutRow) -> some View {
        let ex = exercises.first { $0.key == row.exerciseKey }
        return HStack(spacing: 9) {
            Image(systemName: CategoryArt.symbol(ex?.cat ?? ""))
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkFaint)
                .frame(width: 16)
            Text(ex?.name ?? row.exerciseKey)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Text(amountText(row))
                .font(Theme.mono(10))
                .foregroundStyle(Theme.inkFaint)
            Spacer(minLength: 4)
            Text("+\(row.points.formatted(.number.precision(.fractionLength(row.points < 10 ? 1 : 0))))")
                .font(Theme.display(13, .bold))
                .foregroundStyle(Theme.flame)
            if let onDelete {
                Button {
                    Haptic.solid()
                    onDelete(row)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 3)
    }

    private func amountText(_ row: WorkoutRow) -> String {
        let n = row.amount == row.amount.rounded()
            ? String(Int(row.amount))
            : String(format: "%.1f", row.amount)
        switch row.mode {
        case "reps":    return "\(n) reps"
        case "seconds": return "\(n)s"
        case "minutes": return "\(n) min"
        case "km":      return "\(n) km"
        default:        return n
        }
    }

    private static func label(for day: Date, calendar cal: Calendar) -> String {
        let today = cal.startOfDay(for: Date())
        if cal.isDate(day, inSameDayAs: today) { return "TODAY" }
        if let y = cal.date(byAdding: .day, value: -1, to: today),
           cal.isDate(day, inSameDayAs: y) { return "YESTERDAY" }
        let f = DateFormatter()
        f.timeZone = Config.timeZone
        f.dateFormat = "EEEE d MMM"
        return f.string(from: day).uppercased()
    }
}
