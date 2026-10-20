#!/usr/bin/env python3
"""Generates the placeholder flight sounds (engine hum, boost whoosh, dust hiss) as WAV files.

Everything is synthesised from maths and a seeded random generator, so the files are original
work released as CC0 and a rebuild is byte-identical. Python standard library only.

  python3 tools/audio/make_placeholder_audio.py            # writes game/assets/audio/sfx/*.wav
  python3 tools/audio/make_placeholder_audio.py --check    # fails if the committed files differ

The hum and the hiss are seamless loops (the game switches looping on in code); the whoosh is a
one-shot. Replace them with real recordings in the audio pass (M8).
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


FILES = {
    "engine_hum.wav": engine_hum,
    "dust_hiss.wav": dust_hiss,
    "boost_whoosh.wav": boost_whoosh,
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
