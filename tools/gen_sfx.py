"""Synthesises HARDSPAWN's placeholder sound effects as WAV files (no dependencies).

Usage: python3 tools/gen_sfx.py assets/sfx
"""
import math
import os
import random
import struct
import sys
import wave

SR = 22050
random.seed(7)


def n(sec):
    return int(SR * sec)


def write(out_dir, name, samples, gain):
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = gain / peak
    # short fade-out to avoid clicks
    fade = min(200, len(samples))
    for i in range(fade):
        samples[-1 - i] *= i / fade
    with wave.open(os.path.join(out_dir, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples))


def noise(sec):
    return [random.uniform(-1, 1) for _ in range(n(sec))]


def lowpass(x, a):
    y, out = 0.0, []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out


def lowpass_sweep(x, a0, a1):
    y, out, total = 0.0, [], len(x)
    for i, s in enumerate(x):
        a = a0 + (a1 - a0) * (i / total)
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, a):
    lp = lowpass(x, a)
    return [s - l for s, l in zip(x, lp)]


def sweep(sec, f0, f1, wave_fn=math.sin):
    out, phase = [], 0.0
    total = n(sec)
    for i in range(total):
        f = f0 + (f1 - f0) * (i / total)
        phase += 2 * math.pi * f / SR
        out.append(wave_fn(phase))
    return out


def env_exp(x, k):
    return [s * math.exp(-k * i / SR) for i, s in enumerate(x)]


def mix(*tracks):
    length = max(len(t) for t, _ in tracks)
    out = [0.0] * length
    for t, g in tracks:
        for i, s in enumerate(t):
            out[i] += s * g
    return out


def pad(x, offset_sec):
    return [0.0] * n(offset_sec) + x


def tone(sec, f, k=8.0, harmonics=((1, 1.0),)):
    out = []
    for i in range(n(sec)):
        t = i / SR
        s = sum(a * math.sin(2 * math.pi * f * h * t) for h, a in harmonics)
        out.append(s * math.exp(-k * t))
    return out


def square(phase):
    return 1.0 if math.sin(phase) >= 0 else -1.0


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)

    write(out_dir, "mg", mix(
        (env_exp(lowpass(noise(0.14), 0.35), 38), 1.0),
        (env_exp(sweep(0.14, 160, 70), 40), 0.9),
        (env_exp(highpass(noise(0.02), 0.2), 200), 0.6)), 0.7)

    write(out_dir, "shotgun", mix(
        (env_exp(lowpass(noise(0.6), 0.25), 9), 1.0),
        (env_exp(sweep(0.6, 110, 40), 11), 1.1),
        (env_exp(highpass(noise(0.05), 0.2), 90), 0.7),
        (pad(env_exp(lowpass(noise(0.12), 0.3), 40), 0.38), 0.25)), 0.95)

    rf = lowpass(noise(0.7), 0.15)
    rf = [s * (i / SR) * math.exp(-7 * i / SR) * 8 for i, s in enumerate(rf)]
    write(out_dir, "rocket_fire", mix((rf, 1.0), (env_exp(sweep(0.7, 90, 60), 6), 0.5)), 0.75)

    write(out_dir, "explosion", mix(
        (env_exp(lowpass_sweep(noise(1.5), 0.35, 0.02), 3.2), 1.0),
        (env_exp(sweep(1.5, 60, 28), 3.5), 1.2),
        (env_exp(highpass(noise(0.08), 0.3), 60), 0.5)), 1.0)

    zap = sweep(1.0, 2200, 250)
    zap = [s * math.sin(2 * math.pi * 55 * i / SR) for i, s in enumerate(zap)]
    write(out_dir, "rail", mix(
        (env_exp(zap, 4.5), 0.8),
        (env_exp(sweep(1.0, 140, 70, square), 3.0), 0.25),
        (env_exp(highpass(noise(0.1), 0.4), 35), 0.5),
        (env_exp(tone(1.0, 880, 0.0, ((1, 1.0), (1.5, 0.4))), 6), 0.25)), 0.85)

    j = lowpass(noise(0.12), 0.08)
    j = [s * math.sin(math.pi * i / len(j)) for i, s in enumerate(j)]
    write(out_dir, "jump", j, 0.3)

    write(out_dir, "land", mix((env_exp(sweep(0.16, 110, 50), 30), 1.0),
                               (env_exp(lowpass(noise(0.16), 0.1), 35), 0.8)), 0.5)

    jp = sweep(0.6, 120, 760)
    jp = [s * (1 - i / len(jp)) * (1 + 0.3 * math.sin(2 * math.pi * 18 * i / SR)) for i, s in enumerate(jp)]
    write(out_dir, "jumppad", mix((jp, 1.0), (env_exp(lowpass(noise(0.6), 0.2), 6), 0.3)), 0.6)

    write(out_dir, "hit", tone(0.09, 1500, 35, ((1, 1.0), (2, 0.3))), 0.45)
    write(out_dir, "kill", mix((tone(0.12, 880, 20, ((1, 1.0), (2, 0.2))), 1.0),
                               (pad(tone(0.3, 1320, 9, ((1, 1.0), (2, 0.2))), 0.09), 1.0)), 0.55)

    def arp(freqs, step, k, wave_mix=((1, 1.0),)):
        tracks = [(pad(tone(0.25, f, k, wave_mix), i * step), 1.0) for i, f in enumerate(freqs)]
        return mix(*tracks)

    write(out_dir, "pickup_health", arp([523, 659, 784], 0.06, 14), 0.45)
    write(out_dir, "pickup_armor", arp([330, 440, 660], 0.06, 12, ((1, 1.0), (3, 0.3), (5, 0.15))), 0.45)
    write(out_dir, "pickup_mega", arp([523, 784, 1046, 1568], 0.07, 7, ((1, 1.0), (2, 0.3))), 0.55)

    write(out_dir, "hurt", mix((env_exp(lowpass(noise(0.25), 0.08), 12), 1.0),
                               (env_exp(sweep(0.25, 160, 90), 12), 0.7)), 0.5)
    write(out_dir, "death", mix((env_exp(lowpass(noise(0.8), 0.2), 5), 1.0),
                                (env_exp(sweep(0.8, 220, 50), 5), 0.9)), 0.7)
    write(out_dir, "switch", mix((env_exp(highpass(noise(0.06), 0.3), 80), 1.0),
                                 (tone(0.06, 900, 60), 0.6)), 0.3)

    shimmer = mix(*[(pad(tone(0.5, f, 6), random.uniform(0, 0.1)), 1.0)
                    for f in (800, 1000, 1200, 1500, 1800)])
    write(out_dir, "respawn", shimmer, 0.35)

    horn = []
    for i in range(n(1.6)):
        t = i / SR
        a = min(1.0, t * 8) * math.exp(-1.2 * t)
        s = sum(((2 * ((f * t) % 1.0)) - 1) for f in (220, 277, 330))
        horn.append(s * a)
    write(out_dir, "match_end", lowpass(horn, 0.2), 0.6)

    write(out_dir, "minute", mix((tone(0.15, 1000, 10), 1.0), (pad(tone(0.15, 1000, 10), 0.25), 1.0)), 0.5)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "assets/sfx")
