import SwiftUI
import UIKit

/// Everything about you, in sections that fold — the web app's settings tab
/// grew long enough that people had to scroll past things they never touch,
/// and the fix there works here too.
struct ProfileSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var open: Section? = .look
    @State private var name = ""
    @State private var weight = ""
    @State private var showCode = false

    private enum Section: String, Identifiable {
        case look, banner, colour, measures, account
        var id: String { rawValue }

        var title: String {
            switch self {
            case .look:    return "YOUR MARK"
            case .banner:  return "YOUR BANNER"
            case .colour:  return "YOUR NAME COLOUR"
            case .measures: return "BODYWEIGHT AND UNITS"
            case .account: return "NAME AND RESTORE CODE"
            }
        }
        var icon: String {
            switch self {
            case .look:    return "seal.fill"
            case .banner:  return "rectangle.fill.on.rectangle.fill"
            case .colour:  return "paintpalette.fill"
            case .measures: return "scalemass.fill"
            case .account: return "person.text.rectangle"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    preview
                    ForEach([Section.look, .banner, .colour, .measures, .account]) { section in
                        folder(section)
                    }
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.void.opacity(0.6))
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.display(15, .bold))
                        .foregroundStyle(Theme.flame)
                }
            }
        }
        .onAppear {
            name = session.profile?.displayName ?? ""
            if let bw = session.profile?.bodyweight {
                let shown = session.profile?.usesPounds == true ? bw * 2.20462 : bw
                weight = String(format: "%.0f", shown)
            }
        }
    }

    /// Your own row, exactly as the league sees it. Every control below
    /// changes this, so the effect of a choice is never a surprise.
    private var preview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HOW THE TABLE SEES YOU")
                .font(Theme.display(9, .heavy)).kerning(1.6)
                .foregroundStyle(Theme.inkFaint)
            HStack(spacing: 12) {
                Mark(spec: session.profile?.avatar, name: name.isEmpty ? "?" : name)
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(name.isEmpty ? "You" : name)
                            .font(Theme.display(16, .heavy))
                            .foregroundStyle(previewInk)
                            .lineLimit(1)
                        ForEach(session.profile?.pinnedBadges ?? [], id: \.self) { key in
                            WornBadge(key: key)
                        }
                    }
                    Text("\(Int(session.me?.points ?? 0)) pts this week")
                        .font(.caption2).foregroundStyle(Theme.inkFaint)
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background {
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.surface)
                    .overlay {
                        if let skin = session.profile?.banner {
                            BannerSkin(key: skin)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.corner,
                                                            style: .continuous))
                        }
                    }
                    .overlay {
                        LinearGradient(colors: [previewScrim, previewScrim.opacity(0)],
                                       startPoint: .leading, endPoint: .trailing)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.corner,
                                                        style: .continuous))
                    }
                    .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                        .strokeBorder(Theme.flame.opacity(0.5)))
            }
        }
        .padding(.bottom, 6)
    }

    private var previewInk: Color {
        if let chosen = Tint.nameColor(session.profile?.nameColor) { return chosen }
        return SkinCatalog.prefersDarkInk(session.profile?.banner)
            ? Color(hex: 0x14161B) : Theme.ink
    }
    private var previewScrim: Color {
        guard session.profile?.banner != nil else { return .clear }
        return SkinCatalog.prefersDarkInk(session.profile?.banner)
            ? .white.opacity(0.55) : .black.opacity(0.62)
    }

    // MARK: sections

    @ViewBuilder
    private func folder(_ section: Section) -> some View {
        let isOpen = open == section

        VStack(spacing: 0) {
            Button {
                Haptic.tap()
                withAnimation(Motion.settle) { open = isOpen ? nil : section }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: section.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isOpen ? Theme.flame : Theme.inkMuted)
                        .frame(width: 22)
                    Text(section.title)
                        .font(Theme.display(13, .black)).kerning(1)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(.horizontal, 14).padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                content(section)
                    .padding(.horizontal, 14).padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .strokeBorder(Theme.hairline))
        }
    }

    @ViewBuilder
    private func content(_ section: Section) -> some View {
        switch section {
        case .look:
            EmblemPicker(current: session.profile?.avatar) { spec in
                Task { await session.setAvatar(spec) }
            }

        case .banner:
            VStack(spacing: 8) {
                Text("Sixteen looks, and none of them a player's crest — a league wears the other set.")
                    .font(.caption2).foregroundStyle(Theme.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(SkinCatalog.player) { skin in
                        SkinSwatch(skin: skin, selected: session.profile?.banner == skin.key) {
                            Task { await session.setBanner(skin.key) }
                        }
                    }
                }
            }

        case .colour:
            VStack(spacing: 8) {
                Text("So a banner can never swallow your name.")
                    .font(.caption2).foregroundStyle(Theme.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 6)], spacing: 6) {
                    ForEach(Tint.name) { swatch in
                        SwatchChip(swatch: swatch,
                                   selected: (session.profile?.nameColor ?? "") == swatch.key) {
                            Task { await session.setNameColor(swatch.key) }
                        }
                    }
                }
            }

        case .measures:
            VStack(alignment: .leading, spacing: 12) {
                Text("Only used to score gym lifts. Nobody else ever sees it.")
                    .font(.caption2).foregroundStyle(Theme.inkFaint)

                HStack(spacing: 8) {
                    unitTab("KG", "kg")
                    unitTab("LB", "lb")
                }

                HStack(spacing: 10) {
                    TextField("0", text: $weight)
                        .keyboardType(.decimalPad)
                        .font(Theme.display(24, .black))
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 11).padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.raised))
                    Text(session.profile?.usesPounds == true ? "LB" : "KG")
                        .font(Theme.display(13, .heavy))
                        .foregroundStyle(Theme.inkFaint)
                    Button("SAVE") {
                        let typed = Double(weight)
                        let kg = typed.map { session.profile?.usesPounds == true ? $0 / 2.20462 : $0 }
                        Task { await session.setBodyweight(kg) }
                    }
                    .font(Theme.display(13, .black))
                    .foregroundStyle(Theme.flame)
                }
            }

        case .account:
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TextField("Your name", text: $name)
                        .font(Theme.display(18, .heavy))
                        .foregroundStyle(Theme.ink)
                        .textInputAutocapitalization(.words)
                        .padding(.vertical, 11).padding(.horizontal, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.raised))
                    Button("SAVE") {
                        Task { await session.rename(name) }
                    }
                    .font(Theme.display(13, .black))
                    .foregroundStyle(Theme.flame)
                    .disabled(name.trimmingCharacters(in: .whitespaces).count < 2)
                }

                Divider().overlay(Theme.hairline)

                Text("RESTORE CODE")
                    .font(Theme.display(9, .heavy)).kerning(1.6)
                    .foregroundStyle(Theme.inkFaint)
                Text("This is the only thing that moves your profile to another phone. There are no accounts yet, so keep it somewhere safe.")
                    .font(.caption2).foregroundStyle(Theme.inkFaint)
                HStack(spacing: 10) {
                    Text(showCode ? (session.profile?.restoreCode ?? "—") : "••••••••")
                        .font(Theme.mono(20, .bold))
                        .foregroundStyle(Theme.gold)
                    Spacer()
                    Button(showCode ? "HIDE" : "SHOW") {
                        withAnimation(Motion.tap) { showCode.toggle() }
                    }
                    .font(Theme.display(11, .black))
                    .foregroundStyle(Theme.inkMuted)
                    if showCode, let code = session.profile?.restoreCode {
                        Button {
                            UIPasteboard.general.string = code
                            Haptic.tap()
                            session.show("Restore code copied.")
                        } label: {
                            Image(systemName: "doc.on.doc").foregroundStyle(Theme.flame)
                        }
                    }
                }
            }
        }
    }

    private func unitTab(_ title: String, _ key: String) -> some View {
        let on = (session.profile?.units ?? "kg") == key
        return Button {
            Haptic.tap()
            // the number on screen must keep meaning the same weight
            if !on, let shown = Double(weight) {
                let converted = key == "lb" ? shown * 2.20462 : shown / 2.20462
                weight = String(format: "%.0f", converted)
            }
            Task { await session.setUnits(key) }
        } label: {
            Text(title)
                .font(Theme.display(12, .black)).kerning(1)
                .foregroundStyle(on ? Theme.void : Theme.inkMuted)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(on ? AnyShapeStyle(Theme.heat) : AnyShapeStyle(Theme.raised))
                }
        }
        .buttonStyle(.plain)
    }
}

/// Pick one mark: an emblem with a tint, or an animal. Never both — that was
/// asked for explicitly, and the picker enforces it rather than trusting the
/// person to only touch one control.
struct EmblemPicker: View {
    let current: String?
    let onPick: (String) -> Void

    @State private var mode: Mode = .emblem
    @State private var tintKey: String

    private enum Mode: String, CaseIterable { case emblem, animal }

    private static let animals = ["🦍", "🐺", "🦁", "🐅", "🐻", "🦅", "🦈", "🐗",
                                  "🐍", "🦂", "🐉", "🦏", "🐃", "🦌", "🐎", "🦉",
                                  "🐊", "🦇", "🐆", "🦖", "🐘", "🦬", "🐫", "🦡"]

    init(current: String?, onPick: @escaping (String) -> Void) {
        self.current = current
        self.onPick = onPick
        let parsed = AvatarSpec(current)
        _tintKey = State(initialValue: parsed.colorKey ?? "clear")
        _mode = State(initialValue: parsed.emoji != nil ? .animal : .emblem)
    }

    private var parsed: AvatarSpec { AvatarSpec(current) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Button {
                        Haptic.tap()
                        withAnimation(Motion.tap) { mode = m }
                    } label: {
                        Text(m == .emblem ? "EMBLEM" : "ANIMAL")
                            .font(Theme.display(12, .black)).kerning(1)
                            .foregroundStyle(mode == m ? Theme.void : Theme.inkMuted)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(mode == m ? AnyShapeStyle(Theme.heat)
                                                    : AnyShapeStyle(Theme.raised))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("One or the other, never both.")
                .font(.caption2).foregroundStyle(Theme.inkFaint)
                .frame(maxWidth: .infinity, alignment: .leading)

            if mode == .emblem {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 7)], spacing: 7) {
                    ForEach(Tint.emblem) { swatch in
                        Button {
                            Haptic.tap()
                            tintKey = swatch.key
                            if let icon = parsed.icon {
                                onPick(AvatarSpec.string(icon: icon, colorKey: swatch.key))
                            }
                        } label: {
                            Circle()
                                .fill(swatch.color)
                                .frame(height: 26)
                                .overlay(Circle().strokeBorder(
                                    tintKey == swatch.key ? Theme.ink : Theme.hairline,
                                    lineWidth: tintKey == swatch.key ? 2 : 1))
                                .overlay {
                                    if swatch.hex == nil {
                                        Image(systemName: "circle.dotted")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Theme.void)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 7)], spacing: 7) {
                    ForEach(IconSet.avatars, id: \.self) { key in
                        let chosen = parsed.icon == key
                        Button {
                            Haptic.solid()
                            onPick(AvatarSpec.string(icon: key, colorKey: tintKey))
                        } label: {
                            GameIcon(key: key)
                                .foregroundStyle(Tint.emblem.first { $0.key == tintKey }?.color
                                                 ?? Theme.ink)
                                .padding(9)
                                .frame(height: 52)
                                .frame(maxWidth: .infinity)
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(chosen ? Theme.flame.opacity(0.16) : Theme.raised)
                                        .overlay(RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(chosen ? Theme.flame : .clear,
                                                          lineWidth: 1.5))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 7)], spacing: 7) {
                    ForEach(Self.animals, id: \.self) { emoji in
                        let chosen = parsed.emoji == emoji
                        Button {
                            Haptic.solid()
                            onPick(emoji)
                        } label: {
                            Text(emoji)
                                .font(.system(size: 26))
                                .frame(height: 48)
                                .frame(maxWidth: .infinity)
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(chosen ? Theme.flame.opacity(0.16) : Theme.raised)
                                        .overlay(RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(chosen ? Theme.flame : .clear,
                                                          lineWidth: 1.5))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct SwatchChip: View {
    let swatch: Tint.Swatch
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            Text(swatch.name)
                .font(Theme.display(9, .heavy)).kerning(0.6)
                .foregroundStyle(swatch.color)
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.raised)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(selected ? swatch.color : .clear, lineWidth: 1.5))
                }
        }
        .buttonStyle(.plain)
    }
}
