"""Procedural SFX for Gundiced. Regenerate with:  python3 tools/synth_sfx.py
Writes 16-bit mono 44.1 kHz WAVs into assets/sfx/."""
import wave
from pathlib import Path
import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, attack=0.002, decay=0.2, curve=1.0):
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x / decay) ** curve


def lowpass(x, cutoff):
    """One-pole lowpass; cutoff may be an array (sweeps)."""
    cutoff = np.broadcast_to(cutoff, x.shape)
    k = 1 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += k[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def reverb(x, amount=0.3, length=0.4):
    ir = noise(length) * np.exp(-t(length) / (length / 5))
    wet = np.convolve(x, ir)[: len(x) + int(SR * length)] * amount / np.sqrt(len(ir))
    dry = np.concatenate([x, np.zeros(len(wet) - len(x))])
    return dry + wet


def save(name, x, gain=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    pcm = (x * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(name, f"{len(x) / SR:.2f}s")


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


# Sniper: hard supersonic crack, chesty body, long canyon tail.
d = 0.9
crack = highpass(noise(d), 2500) * env(int(SR * d), 0.0005, 0.012)
body = lowpass(noise(d), 900) * env(int(SR * d), 0.001, 0.08)
thump = np.sin(2 * np.pi * (90 - 40 * t(d)) * t(d)) * env(int(SR * d), 0.001, 0.06)
save("sniper", reverb(mix(crack * 1.2, body, thump * 0.8), 0.6, 0.8))

# RPG launch: pop + rising rocket whoosh.
d = 0.7
pop = lowpass(noise(d), 1500) * env(int(SR * d), 0.001, 0.03)
sweep = lowpass(noise(d), 300 + 3500 * (t(d) / d) ** 0.7) * np.sin(np.pi * t(d) / d) ** 0.8
save("rpg_launch", mix(pop, sweep * 0.8))

# Explosion: sub thump, crunchy mid, rumbling lowpassed tail.
d = 1.6
sub = np.sin(2 * np.pi * (70 * np.exp(-t(d) * 3) + 30) * t(d)) * env(int(SR * d), 0.002, 0.35)
crunch = lowpass(noise(d), 2500) * env(int(SR * d), 0.001, 0.09)
rumble = lowpass(noise(d), 400 * np.exp(-t(d) * 1.2) + 80) * env(int(SR * d), 0.01, 0.6)
save("explosion", reverb(mix(sub * 1.0, crunch * 0.7, rumble * 1.4), 0.3, 0.6))

# Throw: short airy whoosh.
d = 0.32
save("throw", lowpass(noise(d), 600 + 2500 * np.sin(np.pi * t(d) / d)) * np.sin(np.pi * t(d) / d) ** 2, 0.6)

# Molotov: glass shatter into a whoompf of fire.
d = 1.0
glass = np.zeros(int(SR * d))
for _ in range(40):
    s = int(rng.uniform(0, 0.12) * SR)
    f = rng.uniform(2500, 7000)
    g = np.sin(2 * np.pi * f * t(0.05)) * env(int(SR * 0.05), 0.0003, 0.01)
    glass[s:s + len(g)] += g * rng.uniform(0.3, 1.0)
whoomp = lowpass(noise(d), 200 + 1800 * (t(d) / d) ** 0.4) * np.clip(t(d) / 0.15, 0, 1) * np.exp(-t(d) * 2.5)
save("molotov", mix(glass * 0.6, whoomp * 1.3))

# Shield block: metallic clang with inharmonic partials.
d = 1.0
clang = sum(np.sin(2 * np.pi * f * t(d)) * np.exp(-t(d) * (3 + i * 1.5)) * a
            for i, (f, a) in enumerate([(523, 1.0), (1187, 0.6), (1832, 0.45), (2671, 0.3), (3470, 0.2)]))
hit = highpass(noise(d), 3000) * env(int(SR * d), 0.0005, 0.01)
save("shield_block", mix(clang, hit * 0.8), 0.8)

# Crate break: a few woody cracks.
d = 0.55
wood = np.zeros(int(SR * d))
for s in (0.0, 0.04, 0.09, 0.15):
    n = int(SR * 0.18)
    burst = lowpass(noise(0.18), rng.uniform(900, 1800)) * env(n, 0.0005, 0.03)
    tone = np.sin(2 * np.pi * rng.uniform(180, 320) * t(0.18)) * env(n, 0.0005, 0.04)
    i = int(s * SR)
    wood[i:i + n] += burst + tone * 0.5
save("crate_break", wood, 0.85)

# Door swing: short wooden creak (glided buzz) + soft thud.
d = 0.42
f = 220 + 140 * np.sin(np.pi * t(d) / d)
phase = 2 * np.pi * np.cumsum(f) / SR
creak = lowpass(np.sign(np.sin(phase)) * (0.6 + 0.4 * rng.uniform(-1, 1, len(phase))), 1400)
creak *= np.sin(np.pi * t(d) / d) ** 2 * 0.5
thud = lowpass(noise(d), 300) * env(int(SR * d), 0.001, 0.04)
thud = np.concatenate([np.zeros(int(SR * 0.3)), thud])[: int(SR * d)]
save("door", mix(creak, thud), 0.6)

# Dice: tick on each tumble, solid land.
d = 0.05
save("dice_tick", highpass(noise(d), 1500) * env(int(SR * d), 0.0003, 0.006) + np.sin(2 * np.pi * 1900 * t(d)) * env(int(SR * d), 0.0003, 0.008) * 0.5, 0.5)
d = 0.3
save("dice_land", mix(lowpass(noise(d), 1200) * env(int(SR * d), 0.0005, 0.03),
                      np.sin(2 * np.pi * 330 * t(d)) * env(int(SR * d), 0.001, 0.06) * 0.7), 0.8)

# Turn chime: two-note bell.
d = 0.7
bell = lambda f: sum(np.sin(2 * np.pi * f * m * t(d)) * np.exp(-t(d) * (4 + m * 2)) / m for m in (1, 2.01, 3.03))
c = bell(880)
c2 = np.concatenate([np.zeros(int(SR * 0.11)), bell(1318)])[: len(c)]
save("turn", mix(c * 0.6, c2 * 0.6), 0.5)

# Bump (blocked move): dull knock.
d = 0.12
save("bump", lowpass(noise(d), 500) * env(int(SR * d), 0.0005, 0.02) + np.sin(2 * np.pi * 140 * t(d)) * env(int(SR * d), 0.0005, 0.03), 0.5)
