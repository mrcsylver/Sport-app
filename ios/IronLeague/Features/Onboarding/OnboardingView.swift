import SwiftUI

/// Two questions, in order: who are you, and which league. Nothing else —
/// no email, no password, no permissions dialog. A person should be logging
/// push-ups within twenty seconds of opening this.
struct OnboardingView: View {
    @Environment(Session.self) private var session

    @State private var name = ""
    @State private var code = ""
    @State private var leagueName = ""
    @State private var restoreCode = ""
    @State private var mode: Mode = .join
    @State private var preview: LeaguePreviewRow?
    @State private var busy = false
    @State private var showRestore = false
    @FocusState private var focused: Bool

    private enum Mode { case join, create }

    private var needsName: Bool { session.profile == nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                mark

                if needsName {
                    nameStep
                } else {
                    leagueStep
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .animation(Motion.settle, value: needsName)
            .animation(Motion.settle, value: mode)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    // MARK: header

    private var mark: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(Theme.heat)
                .shadow(color: Theme.flame.opacity(0.6), radius: 22)
            Text("IRON LEAGUE")
                .font(Theme.display(28, .black)).italic().kerning(2)
                .foregroundStyle(Theme.ink)
            Text(needsName ? "Pick the name the table will show."
                           : "Now get into a league.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 30)
        .padding(.bottom, 6)
    }

    // MARK: step one — who

    private var nameStep: some View {
        VStack(spacing: 14) {
            Panel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("YOUR NAME")
                        .font(Theme.display(10, .heavy)).kerning(1.6)
                        .foregroundStyle(Theme.inkFaint)
                    TextField("Two to eighteen characters", text: $name)
                        .focused($focused)
                        .font(Theme.display(22, .heavy))
                        .foregroundStyle(Theme.ink)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit { start() }
                }
            }

            HeatButton(title: busy ? "…" : "START", systemImage: "arrow.right") { start() }
                .disabled(busy || name.trimmingCharacters(in: .whitespaces).count < 2)
                .opacity(name.trimmingCharacters(in: .whitespaces).count < 2 ? 0.5 : 1)

            Button {
                withAnimation(Motion.tap) { showRestore.toggle() }
            } label: {
                Text(showRestore ? "Never mind, I'm new"
                                 : "I already have a profile on another phone")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkMuted)
            }
            .buttonStyle(.plain)

            if showRestore {
                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RESTORE CODE")
                            .font(Theme.display(10, .heavy)).kerning(1.6)
                            .foregroundStyle(Theme.inkFaint)
                        TextField("8 characters", text: $restoreCode)
                            .font(Theme.mono(20, .bold))
                            .foregroundStyle(Theme.ink)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        Button {
                            busy = true
                            Task {
                                _ = await session.restore(code: restoreCode)
                                busy = false
                            }
                        } label: {
                            Text("RESTORE")
                                .font(Theme.display(14, .black)).kerning(1)
                                .foregroundStyle(Theme.flame)
                        }
                        .buttonStyle(.plain)
                        .disabled(restoreCode.count < 4 || busy)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: step two — where

    private var leagueStep: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                modeTab("JOIN", .join)
                modeTab("CREATE", .create)
            }

            if mode == .join {
                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LEAGUE CODE")
                            .font(Theme.display(10, .heavy)).kerning(1.6)
                            .foregroundStyle(Theme.inkFaint)
                        TextField("6 characters", text: $code)
                            .font(Theme.mono(24, .bold))
                            .foregroundStyle(Theme.ink)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: code) { _, new in
                                preview = nil
                                guard new.count >= 6 else { return }
                                Task { preview = try? await API.shared.leaguePreview(code: new) }
                            }

                        if let p = preview {
                            Divider().overlay(Theme.hairline)
                            HStack(spacing: 10) {
                                Image(systemName: "person.3.fill")
                                    .foregroundStyle(Theme.jade)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(p.name)
                                        .font(Theme.display(17, .heavy))
                                        .foregroundStyle(Theme.ink)
                                    Text("\(p.members)/\(p.maxMembers) members")
                                        .font(.caption).foregroundStyle(Theme.inkMuted)
                                }
                                Spacer()
                                if p.isFull { Chip(text: "FULL", color: Theme.ember) }
                            }
                            .transition(.opacity)
                        }
                    }
                }

                HeatButton(title: busy ? "…" : "JOIN LEAGUE", systemImage: "arrow.right") {
                    busy = true
                    Task { _ = await session.joinLeague(code: code); busy = false }
                }
                .disabled(busy || code.count < 6)
                .opacity(code.count < 6 ? 0.5 : 1)
            } else {
                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("NEW LEAGUE NAME")
                            .font(Theme.display(10, .heavy)).kerning(1.6)
                            .foregroundStyle(Theme.inkFaint)
                        TextField("e.g. Monday Crew", text: $leagueName)
                            .font(Theme.display(22, .heavy))
                            .foregroundStyle(Theme.ink)
                            .textInputAutocapitalization(.words)
                        Text("You get a code to send to whoever you want in it. Up to thirty people.")
                            .font(.caption2).foregroundStyle(Theme.inkFaint)
                    }
                }

                HeatButton(title: busy ? "…" : "CREATE LEAGUE", systemImage: "flag.fill") {
                    busy = true
                    Task { _ = await session.createLeague(name: leagueName); busy = false }
                }
                .disabled(busy || leagueName.trimmingCharacters(in: .whitespaces).count < 2)
                .opacity(leagueName.trimmingCharacters(in: .whitespaces).count < 2 ? 0.5 : 1)
            }

            if let p = session.profile {
                Text("Signed in as \(p.displayName) · keep this code safe to move phones: \(p.restoreCode)")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }

    private func modeTab(_ title: String, _ m: Mode) -> some View {
        Button {
            Haptic.tap()
            withAnimation(Motion.tap) { mode = m }
        } label: {
            Text(title)
                .font(Theme.display(13, .black)).kerning(1.2)
                .foregroundStyle(mode == m ? Theme.void : Theme.inkMuted)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(mode == m ? AnyShapeStyle(Theme.heat) : AnyShapeStyle(Theme.raised))
                }
        }
        .buttonStyle(.plain)
    }

    private func start() {
        guard !busy else { return }
        busy = true
        Task {
            _ = await session.createProfile(name: name)
            busy = false
        }
    }
}
