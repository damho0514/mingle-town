"""Synthesises every sound in assets/audio/ from scratch (no samples used).

    python3 tool/gen_sounds.py

Pure standard library so it runs anywhere. Re-run after tweaking a sound.
"""
import array
import math
import os
import random
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def osc(kind, phase, duty=0.5):
    p = phase % 1.0
    if kind == 'sine':
        return math.sin(2 * math.pi * p)
    if kind == 'square':
        return 1.0 if p < duty else -1.0
    if kind == 'tri':
        return 4 * abs(p - 0.5) - 1
    raise ValueError(kind)


def env(t, length, attack=0.005, release=0.03, sustain=1.0, decay=0.0):
    if t < attack:
        return t / attack
    level = sustain + (1 - sustain) * math.exp(-(t - attack) / decay) if decay else sustain
    if t > length - release:
        level *= max(0.0, (length - t) / release)
    return level


def tone(buf, start, length, freq, kind='square', vol=0.3, duty=0.5,
         freq_end=None, vibrato=0.0, **env_args):
    """Adds a note into buf (a list of floats) starting at `start` seconds."""
    i0 = int(start * RATE)
    n = int(length * RATE)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq if freq_end is None else freq + (freq_end - freq) * (t / length)
        if vibrato:
            f *= 1 + vibrato * math.sin(2 * math.pi * 6 * t)
        phase += f / RATE
        j = i0 + i
        if j >= len(buf):
            break
        buf[j] += vol * env(t, length, **env_args) * osc(kind, phase, duty)


def noise(buf, start, length, vol=0.2, smooth=0.5, seed=1, **env_args):
    rng = random.Random(seed)
    i0 = int(start * RATE)
    prev = 0.0
    for i in range(int(length * RATE)):
        t = i / RATE
        prev = prev * smooth + (rng.random() * 2 - 1) * (1 - smooth)
        j = i0 + i
        if j >= len(buf):
            break
        buf[j] += vol * env(t, length, **env_args) * prev


def soften(buf, amount=0.35):
    """One-pole low-pass: takes the edge off square waves."""
    prev = 0.0
    for i, v in enumerate(buf):
        prev = prev + (v - prev) * (1 - amount)
        buf[i] = prev


def save(name, buf, gain=1.0):
    peak = max(1e-9, max(abs(v) for v in buf))
    scale = min(1.0, 0.9 / peak) * gain
    data = array.array('h', (int(max(-1, min(1, v * scale)) * 32767) for v in buf))
    path = os.path.join(OUT, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(f'{name}: {len(buf) / RATE:.2f}s')


def blank(seconds):
    return [0.0] * int(seconds * RATE)


def sfx():
    b = blank(0.07)  # soft footstep tap
    noise(b, 0, 0.07, vol=0.6, smooth=0.85, attack=0.002, release=0.05)
    save('step.wav', b, gain=0.6)

    b = blank(0.1)  # chat pop
    tone(b, 0, 0.1, 500, 'sine', 0.6, freq_end=1100, attack=0.003, release=0.06)
    save('pop.wav', b)

    b = blank(0.32)  # emote sparkle
    for k, n in enumerate([84, 88, 91]):
        tone(b, k * 0.07, 0.18, midi(n), 'tri', 0.4, attack=0.003, release=0.15)
    save('emote.wav', b)

    b = blank(0.7)  # someone joined: bell arpeggio
    for k, n in enumerate([72, 76, 79, 84]):
        tone(b, k * 0.09, 0.4, midi(n), 'sine', 0.35, attack=0.003,
             release=0.35, sustain=0.0, decay=0.15)
    save('join.wav', b)

    b = blank(0.55)  # tag start: referee whistle
    tone(b, 0, 0.14, 1900, 'square', 0.25, duty=0.3, vibrato=0.03, release=0.02)
    tone(b, 0.2, 0.33, 1900, 'square', 0.25, duty=0.3, vibrato=0.03, release=0.05)
    soften(b, 0.5)
    save('tag_start.wav', b)

    b = blank(0.3)  # tagged: boing
    tone(b, 0, 0.3, 700, 'square', 0.35, duty=0.25, freq_end=220, release=0.08)
    soften(b)
    save('tagged.wav', b)

    b = blank(1.0)  # round over: fanfare
    for k, n in enumerate([67, 72, 76]):
        tone(b, k * 0.12, 0.12, midi(n), 'square', 0.25, duty=0.25, release=0.02)
    tone(b, 0.36, 0.6, midi(79), 'square', 0.25, duty=0.25, vibrato=0.01, release=0.3)
    soften(b)
    save('tag_end.wav', b)


def bgm():
    bpm = 112
    beat = 60 / bpm
    bars = 8
    b = blank(bars * 4 * beat)

    # Lead melody: (midi note or None, beats).
    melody = [
        (76, 1), (79, 1), (84, 1.5), (83, 0.5),
        (81, 1), (79, 1), (76, 2),
        (77, 1), (81, 1), (84, 1), (81, 1),
        (79, 1.5), (77, 0.5), (76, 1), (74, 1),
        (76, 1), (79, 1), (84, 1), (88, 1),
        (86, 1), (84, 1), (81, 2),
        (81, 1), (84, 1), (83, 1), (86, 1),
        (84, 3), (None, 1),
    ]
    t = 0.0
    for note, beats in melody:
        if note is not None:
            tone(b, t, beats * beat * 0.95, midi(note), 'square', 0.14,
                 duty=0.25, attack=0.004, release=0.04, sustain=0.6, decay=0.12)
        t += beats * beat

    # Bass: root/fifth eighth notes per bar (C Am F G C Am F/G C).
    roots = [48, 45, 41, 43, 48, 45, (41, 43), 48]
    for bar, root in enumerate(roots):
        for e in range(8):
            r = root if isinstance(root, int) else root[e // 4]
            n = r if e % 2 == 0 else r + 7
            tone(b, (bar * 4 + e / 2) * beat, beat / 2 * 0.9, midi(n), 'tri',
                 0.2, attack=0.004, release=0.03)

    # Soft off-beat hi-hat.
    for k in range(bars * 4):
        noise(b, (k + 0.5) * beat, 0.04, vol=0.05, smooth=0.1, seed=k,
              attack=0.001, release=0.035)

    soften(b, 0.3)
    save('bgm.wav', b, gain=0.8)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    sfx()
    bgm()
