import SwiftUI

/// The two faces of the global cap.
///
/// `CapacityView` is the door: somebody new arrives and every seat is taken.
/// `ParkedView` is the waiting room: their own account is still here, its seat
/// simply on hold until one frees up. Neither is an error screen, and neither
/// of them is allowed to read like one — nothing has been lost in either case.

/// A small "ask for a seat" link that disappears rather than going dead when
/// no contact URL is configured.
private struct ContactButton: View {
    var body: some View {
        if let url = URL(string: Config.contactURL), !Config.contactURL.isEmpty {
            Link(destination: url) {
                Text("ASK FOR A SEAT")
                    .font(Theme.display(14, .black)).kerning(1)
                    .foregroundStyle(Theme.flame)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                            .strokeBorder(Theme.flame.opacity(0.4), lineWidth: 1)
                    }
            }
        }
    }
}

/// The brand mark both screens wear, with whatever the state of the door is
/// written underneath it.
private struct DoorMark: View {
    let tag: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(Theme.heat)
                .shadow(color: Theme.flame.opacity(0.6), radius: 22)
            Text("IRON LEAGUE")
                .font(Theme.display(28, .black)).italic().kerning(2)
                .foregroundStyle(Theme.ink)
            Chip(text: tag, color: Theme.ember)
        }
        .padding(.top, 30)
    }
}

private struct Head: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.display(15, .black)).kerning(1.2)
            .foregroundStyle(Theme.ink)
    }
}

// MARK: - The door

struct CapacityView: View {
    @Environment(Session.self) private var session

    @State private var restoreCode = ""
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                DoorMark(tag: "FULL FOR NOW")

                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        Head(text: "THE LEAGUE IS AT CAPACITY")
                        Text("We keep the app to a size it can carry properly. "
                             + "Every seat is taken right now.")
                            .font(.footnote).foregroundStyle(Theme.inkMuted)
                        Text("Seats come free regularly. Send a message and you go "
                             + "on the list — or come back in a few days and try again.")
                            .font(.footnote).foregroundStyle(Theme.inkMuted)
                        ContactButton()
                    }
                }

                // Somebody coming back to an account they already have is not
                // a new sign-up, and telling them the door is shut would be a
                // lie — the server lets a restore through while it has a row.
                Panel {
                    VStack(alignment: .leading, spacing: 10) {
                        Head(text: "ALREADY HAVE A PROFILE?")
                        Text("Coming back is not a new sign-up. If your account is "
                             + "still here, your code brings it straight back.")
                            .font(.footnote).foregroundStyle(Theme.inkMuted)
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
                            Text(busy ? "…" : "RESTORE PROFILE")
                                .font(Theme.display(14, .black)).kerning(1)
                                .foregroundStyle(Theme.flame)
                        }
                        .buttonStyle(.plain)
                        .disabled(restoreCode.count < 4 || busy)
                    }
                }

                Button {
                    Task { await session.boot() }
                } label: {
                    Text("Check again")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.inkMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }
}

// MARK: - The waiting room

struct ParkedView: View {
    @Environment(Session.self) private var session

    @State private var busy = false
    @State private var stillFull = false

    private var whoYouAre: String { session.profile?.displayName ?? "Your account" }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                DoorMark(tag: "SEAT ON HOLD")

                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        Head(text: "YOUR ACCOUNT IS WAITING")
                        Text(whoYouAre + " — nothing has been deleted. Your rank, "
                             + "your badges, every week you won and everything you "
                             + "ever logged are exactly where you left them.")
                            .font(.footnote).foregroundStyle(Theme.inkMuted)
                        Text("The app is at capacity, so your seat is on hold until "
                             + "one frees up. Try again any time.")
                            .font(.footnote).foregroundStyle(Theme.inkMuted)

                        HeatButton(title: busy ? "…" : "TRY AGAIN",
                                   systemImage: "arrow.clockwise") {
                            busy = true
                            stillFull = false
                            Task {
                                let inside = await session.tryWaking()
                                stillFull = !inside
                                busy = false
                            }
                        }
                        .disabled(busy)

                        if stillFull {
                            Text("Still full. Nothing of yours has moved — try again later.")
                                .font(.footnote).foregroundStyle(Theme.ember)
                                .transition(.opacity)
                        }

                        ContactButton()
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .animation(Motion.settle, value: stillFull)
        }
        .scrollIndicators(.hidden)
    }
}
