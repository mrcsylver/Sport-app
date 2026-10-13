#!/usr/bin/env python3
"""The 25 seconds of music under the clip, synthesised from nothing.

    /usr/bin/python3 tools/promo/make_music.py out.wav 28.76

The duration is an argument because the clip's length is decided by the
clip, not here — build_video.py reads DUR straight out of promo.html and
passes it, so a scene added at midnight cannot leave the music three seconds
short of the picture.

WHY NOT A REAL SONG. Because a real song is somebody's, and putting one in a
file you upload is how a reel gets its audio muted or pulled. Instagram's own
music library is fine when you add a track THERE; a track baked into an mp4
is not the same thing and is not covered. Everything below is generated from
sine waves and filtered noise, so it belongs to this project and can go
anywhere -- a poster QR, a reel, a WhatsApp forward -- without a question.

WHAT IT IS. 128 BPM in A minor, four-on-the-floor, arranged so the drop lands
exactly where the clip stops talking about the app and starts showing the
leaderboard move. It is a bed, not a composition: its job is to make 25
silent seconds feel deliberate rather than broken, and to stop somebody
scrolling past.

  bar 1-2    just kick and a filtered pad      the logo
  bar 3-6    hats in, bass in                  logging a set
  bar 7-10   full, lead arpeggio               the board climbing
  bar 11-15  thins out, resolves               leagues, the card, the code

Swap it freely: build_video.py takes --music PATH and will mux anything.
"""
import math
import struct
import sys
import wave

import numpy as np

SR = 44100
BPM = 128.0
BEAT = 60.0 / BPM            # 0.46875 s
BAR = BEAT * 4
DUR = float(sys.argv[2]) if len(sys.argv) > 2 else 25.0

A_MINOR = {"A2": 110.00, "C3": 130.81, "D3": 146.83, "E3": 164.81,
           "F3": 174.61, "G3": 196.00, "A3": 220.00, "C4": 261.63,
           "E4": 329.63, "A4": 440.00, "G4": 392.00, "F4": 349.23}


def t_at(n):
    return int(n * SR)


def env(n, attack, decay, power=2.0):
    """A percussive envelope: near-instant on, exponential off. The curve
    matters more than the sound -- a linear decay reads as a beep, an
    exponential one reads as something hit."""
    e = np.ones(n)
    a = max(int(attack * SR), 1)
    e[:a] = np.linspace(0, 1, a)
    d = np.linspace(0, 1, n - a) if n > a else np.zeros(0)
    e[a:] = (1 - d) ** power
    return e


def kick(dur=0.30):
    """A pitch sweep from 150 Hz down to 45, which is what a kick drum
    actually is -- the thump is the fall, not the tone."""
    n = t_at(dur)
    tt = np.arange(n) / SR
    f = 45 + 105 * np.exp(-tt * 28)
    phase = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(phase) * env(n, 0.001, dur, 2.2)
    click = (np.random.RandomState(1).randn(n) * np.exp(-tt * 420)) * 0.25
    return (body + click) * 0.95


def snare(dur=0.18, seed=2):
    n = t_at(dur)
    tt = np.arange(n) / SR
    rng = np.random.RandomState(seed)
    noise = rng.randn(n)
    # one-pole high-pass, so it cracks instead of thuds
    hp = np.copy(noise)
    for i in range(1, n):
        hp[i] = 0.82 * (hp[i - 1] + noise[i] - noise[i - 1])
    tone = np.sin(2 * np.pi * 185 * tt) * 0.4
    return (hp * 0.9 + tone) * env(n, 0.001, dur, 2.6) * 0.55


def hat(dur=0.055, seed=3, gain=0.3):
    n = t_at(dur)
    rng = np.random.RandomState(seed)
    noise = rng.randn(n)
    hp = np.copy(noise)
    for i in range(1, n):
        hp[i] = 0.93 * (hp[i - 1] + noise[i] - noise[i - 1])
    return hp * env(n, 0.0005, dur, 3.4) * gain


def saw(freq, dur, gain=0.3, power=1.4):
    """A band-limited-ish saw: a few harmonics summed. Cheaper than a real
    saw and it does not alias into a whistle at these frequencies."""
    n = t_at(dur)
    tt = np.arange(n) / SR
    out = np.zeros(n)
    for h in range(1, 9):
        out += np.sin(2 * np.pi * freq * h * tt) / h
    return out * env(n, 0.006, dur, power) * gain


def tri(freq, dur, gain=0.22):
    n = t_at(dur)
    tt = np.arange(n) / SR
    out = (np.sin(2 * np.pi * freq * tt)
           + np.sin(2 * np.pi * freq * 3 * tt) / 9
           + np.sin(2 * np.pi * freq * 5 * tt) / 25)
    return out * env(n, 0.004, dur, 1.8) * gain


def pad(freq, dur, gain=0.10):
    """Two detuned voices, slow in and out. It is what stops the first two
    bars sounding like a drum machine on its own in a room."""
    n = t_at(dur)
    tt = np.arange(n) / SR
    v = (np.sin(2 * np.pi * freq * tt)
         + np.sin(2 * np.pi * freq * 1.004 * tt)
         + np.sin(2 * np.pi * freq * 2 * tt) * 0.3)
    e = np.minimum(np.linspace(0, 3, n), 1.0) * np.minimum(np.linspace(3, 0, n), 1.0)
    return v * e * gain


def place(buf, sig, at):
    i = t_at(at)
    j = min(i + len(sig), len(buf))
    if i < len(buf):
        buf[i:j] += sig[:j - i]


def build():
    total = t_at(DUR + 0.6)
    L = np.zeros(total)
    R = np.zeros(total)

    def add(sig, at, pan=0.0):
        place(L, sig * (1 - max(pan, 0)), at)
        place(R, sig * (1 + min(pan, 0)), at)

    bars = int(DUR / BAR) + 1

    def sect(b):
        """How loud this bar is, which is the whole difference between an
        arrangement and a loop. The first version had every element at full
        gain from bar one: it measured almost perfectly flat across all 25
        seconds, which is exactly what "not dynamic enough" sounds like.
        Quiet open, lift, drop where the leaderboard starts moving, ease
        out."""
        if b < 2:
            return 0.45
        if b < 6:
            return 0.72
        if b < 10:
            return 1.0
        return 0.80

    # --- pad: the harmonic floor, one chord per two bars ------------------
    chords = [("A2", "C3", "E3"), ("A2", "C3", "E3"), ("F3", "A3", "C4"),
              ("G3", "C4", "E4"), ("A2", "C3", "E3"), ("F3", "A3", "C4"),
              ("G3", "C4", "E4")]
    for i, ch in enumerate(chords):
        at = i * BAR * 2
        if at > DUR:
            break
        for note in ch:
            add(pad(A_MINOR[note], BAR * 2, 0.085 * (0.6 if i < 1 else 1.0)), at)

    for b in range(bars):
        at = b * BAR
        if at > DUR:
            break

        g = sect(b)

        # --- kick: four on the floor from the first bar ------------------
        # It is there from the start so the clip has a pulse immediately, but
        # at under half gain until the hats arrive.
        for beat in range(4):
            k = at + beat * BEAT
            if k < DUR:
                add(kick() * g, k)

        # --- hats: in from bar 3, doubling from bar 7 --------------------
        if b >= 2:
            step = BEAT / 2 if b < 6 else BEAT / 4
            n = int(BAR / step)
            for i in range(n):
                h = at + i * step
                if h < DUR:
                    # the offbeat is quieter, which is what makes it groove
                    hg = 0.30 if (i % 2 == 0) else 0.17
                    add(hat(seed=3 + (i % 4), gain=hg * g), h,
                        pan=0.25 if i % 2 else -0.25)

        # --- snare on 2 and 4, from bar 3 --------------------------------
        if b >= 2:
            for beat in (1, 3):
                sxx = at + beat * BEAT
                if sxx < DUR:
                    add(snare(seed=2 + beat) * g, sxx)

        # --- bass: in from bar 3, root of the chord ----------------------
        if b >= 2:
            root = chords[min(b // 2, len(chords) - 1)][0]
            f = A_MINOR[root] / 2
            for beat in range(4):
                bt = at + beat * BEAT
                if bt < DUR:
                    add(saw(f, BEAT * 0.88, gain=0.26 * g), bt)

        # --- lead arpeggio: bars 7-10, the part that carries the board ---
        if 6 <= b <= 9:
            seq = ["A3", "C4", "E4", "C4", "A3", "E4", "G4", "E4"]
            for i, note in enumerate(seq):
                nt = at + i * (BEAT / 2)
                if nt < DUR:
                    add(tri(A_MINOR[note], BEAT * 0.45, 0.20 * g),
                        nt, pan=-0.2 if i % 2 else 0.2)

    # --- a riser across the bar before the drop --------------------------
    # Nothing says "something is about to happen" as cheaply as noise that
    # climbs. Two bars of it, under everything, resolving on the crash.
    drop = 6 * BAR
    rn = t_at(BAR * 2)
    rng2 = np.random.RandomState(11)
    riser = rng2.randn(rn)
    cut = np.linspace(0.70, 0.985, rn)      # sweeping the filter upward
    hp2 = np.copy(riser)
    for i in range(1, rn):
        hp2[i] = cut[i] * (hp2[i - 1] + riser[i] - riser[i - 1])
    add(hp2 * np.linspace(0, 1, rn) ** 2.2 * 0.17, drop - BAR * 2)

    # --- a crash where the board starts moving ---------------------------
    n = t_at(1.4)
    rng = np.random.RandomState(7)
    crash = rng.randn(n)
    hp = np.copy(crash)
    for i in range(1, n):
        hp[i] = 0.96 * (hp[i - 1] + crash[i] - crash[i - 1])
    add(hp * env(n, 0.002, 1.4, 1.5) * 0.22, drop)

    # --- tail: let the last chord ring rather than cutting ---------------
    for note in ("A2", "C3", "E3", "A3"):
        add(pad(A_MINOR[note], 3.0, 0.10), DUR - 2.6)

    st = np.vstack([L, R]).T
    # Soft-clip rather than hard-limit: a tanh knee keeps the kick punchy
    # where a brickwall would make it click.
    st = np.tanh(st * 1.05) * 0.86
    st = st[:t_at(DUR)]
    # 12 ms fade at each end, so there is no thump on loop or on stop.
    f = t_at(0.012)
    st[:f] *= np.linspace(0, 1, f)[:, None]
    st[-f:] *= np.linspace(1, 0, f)[:, None]
    return st


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "music.wav"
    st = build()
    pcm = np.clip(st, -1, 1)
    data = (pcm * 32767).astype("<i2").tobytes()
    with wave.open(out, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print("wrote %s  (%.1fs, %.2f MB)" % (out, len(st) / SR, len(data) / 1e6))


if __name__ == "__main__":
    main()
