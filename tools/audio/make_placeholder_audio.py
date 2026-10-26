#!/usr/bin/env python3
"""Generates the placeholder flight and combat sounds as WAV files: engine hum, boost whoosh,
dust hiss, the two weapons' shots, hit sounds for shield, armor, hull and rock, the overheat vent,
the missile sounds (launches, explosion, lock beeps, incoming-missile warning, flare launch) and the
loot pickup chime, the low-shield alarm and the kill confirmation.

Everything is synthesised from maths and a seeded random generator, so the files are original
work released as CC0 and a rebuild is byte-identical. Python standard library only.

  python3 tools/audio/make_placeholder_audio.py            # writes game/assets/audio/sfx/*.wav
  python3 tools/audio/make_placeholder_audio.py --check    # fails if the committed files differ

The hum and the hiss are seamless loops (the game switches looping on in code); everything else
is a one-shot. Replace them with real recordings in the audio pass (M8).
"""

from __future__ import annotations

import argparse
import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 22050
ROOT = Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "game" / "assets" / "audio" / "sfx"


def _lowpass(samples: list[float], cutoff_hz: float) -> list[float]:
    """One-pole low-pass; run twice by callers that want a steeper slope."""
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff_hz / RATE)
    out, state = [], 0.0
    for sample in samples:
        state += alpha * (sample - state)
        out.append(state)
    return out


def _highpass(samples: list[float], cutoff_hz: float) -> list[float]:
    low = _lowpass(samples, cutoff_hz)
    return [s - l for s, l in zip(samples, low)]


def _noise(rng: random.Random, count: int) -> list[float]:
    return [rng.uniform(-1.0, 1.0) for _ in range(count)]


def _make_loop(samples: list[float], fade: int) -> list[float]:
    """Cross-fades the tail into the head so the last sample flows into the first."""
    body = samples[: len(samples) - fade]
    for i in range(fade):
        t = i / fade
        body[i] = body[i] * t + samples[len(samples) - fade + i] * (1.0 - t)
    return body


def _normalise(samples: list[float], peak: float) -> list[float]:
    top = max(abs(s) for s in samples) or 1.0
    return [s * peak / top for s in samples]


def engine_hum() -> list[float]:
    """A low, throbbing drone: stacked harmonics of 55 Hz plus a rumble of filtered noise.
    All partials are whole cycles per loop, so the tone loops cleanly by itself."""
    seconds = 2.0
    count = int(RATE * seconds)
    rng = random.Random(1001)
    partials = ((55.0, 1.0), (110.0, 0.7), (165.0, 0.45), (220.0, 0.3), (330.0, 0.16), (440.0, 0.08))
    tone = []
    for i in range(count):
        t = i / RATE
        value = sum(a * math.sin(2.0 * math.pi * f * t) for f, a in partials)
        value *= 0.82 + 0.18 * math.sin(2.0 * math.pi * 7.0 * t)  # slow pulse, 14 cycles per loop
        tone.append(value)
    rumble = _make_loop(_lowpass(_lowpass(_noise(rng, count + 2000), 220.0), 220.0), 2000)
    mixed = [a * 0.6 + b * 4.0 for a, b in zip(tone, rumble)]
    return _normalise(mixed, 0.8)


def dust_hiss() -> list[float]:
    """Wind-like hiss: band-limited noise with a slow swell."""
    seconds = 3.0
    count = int(RATE * seconds)
    rng = random.Random(2002)
    hiss = _noise(rng, count + 4000)
    hiss = _highpass(_lowpass(_lowpass(hiss, 5200.0), 5200.0), 900.0)
    hiss = _make_loop(hiss, 4000)
    for i in range(count):
        hiss[i] *= 0.8 + 0.2 * math.sin(2.0 * math.pi * 2.0 * i / count)
    return _normalise(hiss, 0.8)


def boost_whoosh() -> list[float]:
    """One-shot: noise through a band that sweeps up while the level swells and falls away,
    with a low thump under the start."""
    seconds = 1.6
    count = int(RATE * seconds)
    rng = random.Random(3003)
    raw = _noise(rng, count)
    out = []
    low1 = low2 = 0.0
    for i in range(count):
        t = i / count
        cutoff = 300.0 + 3800.0 * math.sin(math.pi * min(t * 1.4, 1.0) * 0.5) ** 2
        alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
        low1 += alpha * (raw[i] - low1)
        low2 += alpha * (low1 - low2)
        envelope = math.sin(math.pi * min(t / 0.35, 1.0) * 0.5) ** 2 * math.exp(-2.6 * max(t - 0.2, 0.0))
        thump = math.sin(2.0 * math.pi * 48.0 * i / RATE) * math.exp(-9.0 * t) * 0.9
        out.append((low2 - low1 * 0.35) * envelope * 1.6 + thump)
    return _normalise(out, 0.9)


def _decay(i: int, seconds: float, rate: float) -> float:
    """Exponential decay envelope at sample `i`, falling by `rate` e-folds per second."""
    return math.exp(-rate * i / RATE) if i / RATE <= seconds else 0.0


def laser_fire() -> list[float]:
    """A zapping pulse: a tone that falls from 2.4 kHz to 260 Hz in a tenth of a second, with a
    bright second harmonic and a tiny noise click at the start."""
    count = int(RATE * 0.22)
    rng = random.Random(4004)
    out, phase = [], 0.0
    for i in range(count):
        t = i / RATE
        freq = 260.0 + 2140.0 * math.exp(-t * 26.0)
        phase += 2.0 * math.pi * freq / RATE
        tone = math.sin(phase) + 0.45 * math.sin(2.0 * phase + 0.6)
        attack = min(i / 60.0, 1.0)
        click = rng.uniform(-1.0, 1.0) * math.exp(-t * 400.0) * 0.5
        out.append((tone * attack * math.exp(-t * 15.0)) + click)
    return _normalise(out, 0.85)


def autocannon_fire() -> list[float]:
    """A short percussive bang: a burst of mid noise, a thump at 85 Hz and a ringing crack."""
    count = int(RATE * 0.14)
    rng = random.Random(5005)
    noise = _lowpass(_noise(rng, count), 3200.0)
    out = []
    for i in range(count):
        t = i / RATE
        thump = math.sin(2.0 * math.pi * (85.0 - 30.0 * t * 6.0) * t) * math.exp(-t * 38.0)
        crack = noise[i] * math.exp(-t * 55.0) * 1.6
        out.append(thump * 0.9 + crack)
    return _normalise(out, 0.9)


def hit_shield() -> list[float]:
    """A bright energy shimmer: three high partials with a fast tremolo, falling away."""
    count = int(RATE * 0.38)
    out = []
    for i in range(count):
        t = i / RATE
        value = 0.0
        for freq, amp in ((820.0, 1.0), (1230.0, 0.7), (1970.0, 0.5), (3100.0, 0.25)):
            value += amp * math.sin(2.0 * math.pi * freq * t * (1.0 + 0.04 * math.sin(30.0 * t)))
        tremolo = 0.65 + 0.35 * math.sin(2.0 * math.pi * 38.0 * t)
        out.append(value * tremolo * min(i / 40.0, 1.0) * math.exp(-t * 9.0))
    return _normalise(out, 0.8)


def hit_armor() -> list[float]:
    """A metal clank: inharmonic partials that die quickly, over a noise click."""
    count = int(RATE * 0.26)
    rng = random.Random(6006)
    out = []
    for i in range(count):
        t = i / RATE
        value = 0.0
        for freq, amp, rate in ((520.0, 1.0, 22.0), (1130.0, 0.8, 30.0), (1790.0, 0.6, 38.0), (2430.0, 0.4, 50.0)):
            value += amp * math.sin(2.0 * math.pi * freq * t) * math.exp(-t * rate)
        value += rng.uniform(-1.0, 1.0) * math.exp(-t * 220.0) * 1.2
        out.append(value)
    return _normalise(out, 0.85)


def hit_hull() -> list[float]:
    """A heavy thud: a sine that drops from 140 to 50 Hz and a crunch of low-passed noise."""
    count = int(RATE * 0.3)
    rng = random.Random(7007)
    noise = _lowpass(_noise(rng, count), 1400.0)
    out, phase = [], 0.0
    for i in range(count):
        t = i / RATE
        phase += 2.0 * math.pi * (50.0 + 90.0 * math.exp(-t * 28.0)) / RATE
        out.append(math.sin(phase) * math.exp(-t * 14.0) + noise[i] * math.exp(-t * 30.0) * 1.3)
    return _normalise(out, 0.9)


def hit_rock() -> list[float]:
    """A dull crumbling tap: noise through a low band, and a short low tone."""
    count = int(RATE * 0.2)
    rng = random.Random(8008)
    noise = _lowpass(_lowpass(_noise(rng, count), 900.0), 900.0)
    out = []
    for i in range(count):
        t = i / RATE
        out.append(noise[i] * math.exp(-t * 26.0) * 3.0 + math.sin(2.0 * math.pi * 150.0 * t) * math.exp(-t * 40.0))
    return _normalise(out, 0.8)


def weapon_overheat() -> list[float]:
    """Steam venting: a hissing noise that swells and fades over about 0.6 s."""
    count = int(RATE * 0.6)
    rng = random.Random(9009)
    hiss = _highpass(_lowpass(_noise(rng, count), 6000.0), 1500.0)
    out = []
    for i in range(count):
        t = i / count
        out.append(hiss[i] * math.sin(math.pi * min(t / 0.25, 1.0) * 0.5) ** 2 * math.exp(-3.0 * t))
    return _normalise(out, 0.7)


def missile_launch() -> list[float]:
    """A missile leaving the rail: a thump, then a rushing roar that swells and thins out."""
    count = int(RATE * 0.9)
    rng = random.Random(10010)
    raw = _noise(rng, count)
    out = []
    low1 = low2 = 0.0
    for i in range(count):
        t = i / RATE
        cutoff = 400.0 + 2600.0 * min(t / 0.5, 1.0)
        alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
        low1 += alpha * (raw[i] - low1)
        low2 += alpha * (low1 - low2)
        swell = min(t / 0.12, 1.0) * math.exp(-2.2 * max(t - 0.15, 0.0))
        thump = math.sin(2.0 * math.pi * (70.0 - 25.0 * min(t * 5.0, 1.0)) * t) * math.exp(-t * 11.0)
        out.append(low2 * swell * 2.4 + thump * 0.9)
    return _normalise(out, 0.9)


def rocket_launch() -> list[float]:
    """A rocket's sharp whoosh: shorter and brighter than the missile's."""
    count = int(RATE * 0.35)
    rng = random.Random(11011)
    raw = _highpass(_lowpass(_noise(rng, count), 5000.0), 600.0)
    out = []
    for i in range(count):
        t = i / RATE
        thump = math.sin(2.0 * math.pi * 95.0 * t) * math.exp(-t * 30.0)
        out.append(raw[i] * min(t / 0.03, 1.0) * math.exp(-t * 9.0) * 1.8 + thump * 0.7)
    return _normalise(out, 0.8)


def explosion() -> list[float]:
    """A big blast: a crack of noise, a deep boom that drops from 90 to 38 Hz and a rumbling tail."""
    count = int(RATE * 1.4)
    rng = random.Random(12012)
    noise = _noise(rng, count)
    rumble = _lowpass(_lowpass(noise, 380.0), 380.0)
    crack = _lowpass(noise, 4200.0)
    out, phase = [], 0.0
    for i in range(count):
        t = i / RATE
        phase += 2.0 * math.pi * (38.0 + 52.0 * math.exp(-t * 7.0)) / RATE
        boom = math.sin(phase) * math.exp(-t * 3.2)
        out.append(
            boom * 1.0 + rumble[i] * math.exp(-t * 2.6) * 5.0 + crack[i] * math.exp(-t * 28.0) * 1.7
        )
    return _normalise(out, 0.95)


def lock_beep() -> list[float]:
    """A short clean blip (1 kHz); the game plays it higher as the lock closes."""
    count = int(RATE * 0.07)
    out = []
    for i in range(count):
        t = i / RATE
        envelope = min(i / 90.0, 1.0) * min((count - i) / 250.0, 1.0)
        out.append((math.sin(2.0 * math.pi * 1000.0 * t) + 0.25 * math.sin(2.0 * math.pi * 2000.0 * t)) * envelope)
    return _normalise(out, 0.7)


def lock_ready() -> list[float]:
    """The lock-acquired tone: two rising notes that finish on a held one."""
    count = int(RATE * 0.38)
    out = []
    for i in range(count):
        t = i / RATE
        freq = 1200.0 if t < 0.09 else (1600.0 if t < 0.18 else 2000.0)
        envelope = min(i / 80.0, 1.0) * (1.0 if t < 0.28 else max(0.0, 1.0 - (t - 0.28) / 0.1))
        out.append(math.sin(2.0 * math.pi * freq * t) * envelope)
    return _normalise(out, 0.7)


def missile_warning() -> list[float]:
    """The incoming-missile alarm: two alternating square-ish tones, harsh on purpose."""
    count = int(RATE * 0.32)
    out = []
    for i in range(count):
        t = i / RATE
        freq = 880.0 if t < 0.16 else 660.0
        wave_value = math.sin(2.0 * math.pi * freq * t)
        wave_value = max(-0.6, min(0.6, wave_value * 1.8)) + 0.2 * math.sin(2.0 * math.pi * freq * 3.0 * t)
        local = t % 0.16
        envelope = min(local / 0.006, 1.0) * min((0.16 - local) / 0.01, 1.0)
        out.append(wave_value * envelope)
    return _normalise(out, 0.7)


def flare_launch() -> list[float]:
    """Flares popping out: a handful of quick crackles over a bright hiss."""
    count = int(RATE * 0.7)
    rng = random.Random(13013)
    hiss = _highpass(_lowpass(_noise(rng, count), 7000.0), 2200.0)
    pops = [0.0, 0.05, 0.11, 0.17]
    out = []
    for i in range(count):
        t = i / RATE
        value = hiss[i] * min(t / 0.04, 1.0) * math.exp(-t * 4.5) * 1.4
        for start in pops:
            if t >= start:
                value += rng.uniform(-1.0, 1.0) * math.exp(-(t - start) * 180.0) * 1.1
        out.append(value)
    return _normalise(out, 0.8)


def loot_pickup() -> list[float]:
    """The tractor beam collecting a container: a quick bright two-note chime."""
    count = int(RATE * 0.3)
    out = []
    for i in range(count):
        t = i / RATE
        freq = 880.0 if t < 0.08 else 1320.0
        local = t if t < 0.08 else t - 0.08
        envelope = min(local / 0.004, 1.0) * math.exp(-local * 14.0)
        out.append(
            (math.sin(2.0 * math.pi * freq * t) + 0.3 * math.sin(2.0 * math.pi * freq * 2.0 * t)) * envelope
        )
    return _normalise(out, 0.6)


def low_shield_alarm() -> list[float]:
    """The low-shield alarm: one falling two-tone beep, softer and slower than the missile warning."""
    count = int(RATE * 0.36)
    out = []
    for i in range(count):
        t = i / RATE
        freq = 740.0 if t < 0.18 else 520.0
        local = t % 0.18
        envelope = min(local / 0.01, 1.0) * min((0.18 - local) / 0.03, 1.0)
        out.append(math.sin(2.0 * math.pi * freq * t) * envelope * (0.9 + 0.1 * math.sin(2.0 * math.pi * 30.0 * t)))
    return _normalise(out, 0.6)


def kill_confirm() -> list[float]:
    """The kill confirmation: a low thud under a sharp rising two-note ping."""
    count = int(RATE * 0.5)
    out = []
    for i in range(count):
        t = i / RATE
        thud = math.sin(2.0 * math.pi * 70.0 * t) * math.exp(-t * 16.0)
        freq = 1568.0 if t < 0.07 else 2093.0
        local = t if t < 0.07 else t - 0.07
        ping = math.sin(2.0 * math.pi * freq * t) * min(local / 0.003, 1.0) * math.exp(-local * 11.0)
        out.append(thud * 0.9 + ping * 0.7)
    return _normalise(out, 0.7)


FILES = {
    "engine_hum.wav": engine_hum,
    "dust_hiss.wav": dust_hiss,
    "boost_whoosh.wav": boost_whoosh,
    "laser_fire.wav": laser_fire,
    "autocannon_fire.wav": autocannon_fire,
    "hit_shield.wav": hit_shield,
    "hit_armor.wav": hit_armor,
    "hit_hull.wav": hit_hull,
    "hit_rock.wav": hit_rock,
    "weapon_overheat.wav": weapon_overheat,
    "missile_launch.wav": missile_launch,
    "rocket_launch.wav": rocket_launch,
    "explosion.wav": explosion,
    "lock_beep.wav": lock_beep,
    "lock_ready.wav": lock_ready,
    "missile_warning.wav": missile_warning,
    "flare_launch.wav": flare_launch,
    "loot_pickup.wav": loot_pickup,
    "low_shield_alarm.wav": low_shield_alarm,
    "kill_confirm.wav": kill_confirm,
}


def to_wav_bytes(samples: list[float]) -> bytes:
    import io

    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(
            b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767.0)) for s in samples)
        )
    return buffer.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--check", action="store_true", help="compare with the committed files")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    failed = False
    for name, make in FILES.items():
        data = to_wav_bytes(make())
        path = OUT / name
        if args.check:
            if not path.exists() or path.read_bytes() != data:
                print(f"DIFFERS: {path.relative_to(ROOT)}")
                failed = True
        else:
            path.write_bytes(data)
            print(f"wrote {path.relative_to(ROOT)} ({len(data) // 1024} KiB)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
