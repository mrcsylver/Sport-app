import SwiftUI
import UIKit

/// Where you manage the things around the training: which leagues you are in,
/// who you are, and what you wear. Deliberately the last tab — nobody opens a
/// training app to visit settings.
struct LeaguesView: View {
    @Environment(Session.self) private var session

    @State private var sheet: Sheet?
    @State private var confirmLeave: League?
    @State private var confirmDelete: League?

    private enum Sheet: String, Identifiable {
        case add, profile, settings, shop
        var id: String { rawValue }
    }

    private var isOwner: Bool {
        session.league?.ownerId == session.profile?.id
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                SectionHead(title: "YOUR LEAGUES", trailing: "\(session.leagues.count)")

                ForEach(session.leagues) { league in
                    LeagueCard(league: league,
                               active: league.id == session.leagueId,
                               owned: league.ownerId == session.profile?.id,
                               onOpen: { Task { await session.switchLeague(league.id) } },
                               onLeave: { confirmLeave = league },
                               onDelete: { confirmDelete = league })
                }

                Button {
                    Haptic.tap()
                    sheet = .add
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("JOIN OR CREATE ANOTHER")
                            .font(Theme.display(13, .black)).kerning(1)
                    }
                    .foregroundStyle(Theme.flame)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                            .strokeBorder(Theme.flame.opacity(0.45),
                                          style: StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
                    }
                }
                .buttonStyle(.plain).pressable()

                Panel(padding: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BEING IN SEVERAL LEAGUES")
                            .font(Theme.display(9, .heavy)).kerning(1.6)
                            .foregroundStyle(Theme.inkFaint)
                        Text("Log a workout once and it counts in every league you were already in. Join a league later and it starts from that moment — nothing is backdated, so nobody arrives already winning.")
                            .font(.caption).foregroundStyle(Theme.inkMuted)
                    }
                }

                SectionHead(title: "YOU").padding(.top, 8)

                RowButton(icon: "person.crop.circle",
                          title: session.profile?.displayName ?? "Profile",
                          detail: "Name, emblem, banner, colour, bodyweight") {
                    sheet = .profile
                }

                RowButton(icon: "bag", title: "Shop",
                          detail: "Emblems, banners and crests you already own") {
                    sheet = .shop
                }

                if isOwner {
                    SectionHead(title: "LEAGUE SETTINGS", trailing: "CREATOR")
                        .padding(.top, 8)
                    RowButton(icon: "slider.horizontal.3",
                              title: session.league?.name ?? "League",
                              detail: "Rest days, season length, crest") {
                        sheet = .settings
                    }
                }

                Text("IRON LEAGUE · \(Config.appVersion)")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)

                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .animation(Motion.settle, value: session.leagues.count)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $sheet) { which in
            Group {
                switch which {
                case .add:      AddLeagueSheet()
                case .profile:  ProfileSheet()
                case .settings: LeagueSettingsSheet()
                case .shop:     ShopSheet()
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .alert("Leave this league?", isPresented: Binding(
            get: { confirmLeave != nil },
            set: { if !$0 { confirmLeave = nil } })) {
            Button("Leave", role: .destructive) {
                if let l = confirmLeave { Task { await session.leaveLeague(l.id) } }
                confirmLeave = nil
            }
            Button("Stay", role: .cancel) { confirmLeave = nil }
        } message: {
            Text("Your points stay in the league's history, but you drop off the board.")
        }
        .alert("Delete this league?", isPresented: Binding(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let l = confirmDelete { Task { await session.deleteLeague(l.id) } }
                confirmDelete = nil
            }
            Button("Keep", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("Everything in it goes: the board, every log, the history. This cannot be undone.")
        }
    }
}

struct LeagueCard: View {
    let league: League
    let active: Bool
    let owned: Bool
    let onOpen: () -> Void
    let onLeave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    Crest(league: league, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(league.name)
                                .font(Theme.display(17, .black))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            if owned { Chip(text: "YOURS", color: Theme.gold) }
                            if active { Chip(text: "OPEN", color: Theme.jade, filled: true) }
                        }
                        Text("\(league.members)/\(league.maxMembers) · code \(league.code)")
                            .font(Theme.mono(10))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    UIPasteboard.general.string = league.code
                    Haptic.tap()
                } label: {
                    Label("Copy the code", systemImage: "doc.on.doc")
                }
                ShareLink(item: "Join my Iron League: code \(league.code)") {
                    Label("Send an invite", systemImage: "square.and.arrow.up")
                }
                Divider()
                if owned {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete the league", systemImage: "trash")
                    }
                } else {
                    Button(role: .destructive, action: onLeave) {
                        Label("Leave the league", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 32, height: 40)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.surface)
                .overlay {
                    if let skin = league.badge?.skin {
                        BannerSkin(key: skin)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.corner,
                                                        style: .continuous))
                            .opacity(0.85)
                    }
                }
                .overlay {
                    LinearGradient(colors: [.black.opacity(league.badge?.skin == nil ? 0 : 0.6), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner,
                                                    style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                        .strokeBorder(active ? Theme.jade.opacity(0.6) : Theme.hairline,
                                      lineWidth: active ? 1.5 : 1)
                }
        }
    }
}

struct RowButton: View {
    let icon: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.display(16, .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(.caption2).foregroundStyle(Theme.inkFaint)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                        .strokeBorder(Theme.hairline))
            }
        }
        .buttonStyle(.plain)
        .pressable()
    }
}

/// Joining or starting a second league, without going through onboarding.
struct AddLeagueSheet: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var name = ""
    @State private var preview: LeaguePreviewRow?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("JOIN WITH A CODE")
                                .font(Theme.display(10, .heavy)).kerning(1.6)
                                .foregroundStyle(Theme.inkFaint)
                            TextField("6 characters", text: $code)
                                .font(Theme.mono(22, .bold))
                                .foregroundStyle(Theme.ink)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .onChange(of: code) { _, new in
                                    preview = nil
                                    guard new.count >= 6 else { return }
                                    Task { preview = try? await API.shared.leaguePreview(code: new) }
                                }
                            if let p = preview {
                                Text("\(p.name) · \(p.members)/\(p.maxMembers)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(p.isFull ? Theme.ember : Theme.jade)
                            }
                            Button("JOIN") {
                                busy = true
                                Task {
                                    if await session.joinLeague(code: code) { dismiss() }
                                    busy = false
                                }
                            }
                            .font(Theme.display(14, .black))
                            .foregroundStyle(Theme.flame)
                            .disabled(busy || code.count < 6)
                        }
                    }

                    Panel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("START A NEW ONE")
                                .font(Theme.display(10, .heavy)).kerning(1.6)
                                .foregroundStyle(Theme.inkFaint)
                            TextField("League name", text: $name)
                                .font(Theme.display(20, .heavy))
                                .foregroundStyle(Theme.ink)
                                .textInputAutocapitalization(.words)
                            Button("CREATE") {
                                busy = true
                                Task {
                                    if await session.createLeague(name: name) { dismiss() }
                                    busy = false
                                }
                            }
                            .font(Theme.display(14, .black))
                            .foregroundStyle(Theme.flame)
                            .disabled(busy || name.trimmingCharacters(in: .whitespaces).count < 2)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.void.opacity(0.6))
            .navigationTitle("Another league")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.flame)
                }
            }
        }
    }
}
