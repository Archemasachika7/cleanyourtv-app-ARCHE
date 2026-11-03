"""Synthesise the Arche launcher's startup sound: an original, ominous brass swell with a timpani hit.

Written from scratch (no samples, no film score), so it can live in the repo. Output is a WAV;
encode it to a small Ogg Vorbis with ffmpeg:

    python3 tv/arche/tools/make_sound.py /tmp/s.wav
    ffmpeg -i /tmp/s.wav -c:a libvorbis -q:a 1 tv/arche/launcher/res/raw/arche_startup.ogg
"""
import sys
import wave

import numpy as np

SR = 22050


def brass(freq, dur, swell=0.6):
    t = np.arange(int(SR * dur)) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t)
    phase = 2 * np.pi * freq * np.cumsum(vib) / SR
    # Odd and even harmonics falling off: a horn-like buzz.
    tone = sum(np.sin(k * phase) / k ** 1.3 for k in range(1, 9))
    env = np.minimum(1, t / swell) * np.exp(-np.maximum(0, t - dur + 0.9) * 3.5)
    return tone * env


def timpani(freq, dur):
    t = np.arange(int(SR * dur)) / SR
    f = freq * (1 + 0.15 * np.exp(-t * 18))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.2)
    noise = np.random.default_rng(7).normal(0, 1, t.size) * np.exp(-t * 30) * 0.4
    return body + noise


def place(track, clip, at):
    i = int(at * SR)
    n = min(clip.size, track.size - i)
    track[i:i + n] += clip[:n]


def main(out):
    total = 4.6
    track = np.zeros(int(SR * total))
    # D minor: a low pedal, then the chord rises and resolves on a high D.
    place(track, brass(73.42, 4.4, 0.9) * 0.9, 0.0)            # D2 pedal
    place(track, timpani(73.42, 1.6) * 1.4, 0.0)
    for f, at in ((146.83, 0.5), (174.61, 0.9), (220.0, 1.3)):  # D3 F3 A3
        place(track, brass(f, 4.4 - at, 0.5) * 0.45, at)
    place(track, brass(233.08, 0.7, 0.2) * 0.35, 2.0)           # Bb3, a dark lean
    place(track, brass(293.66, 2.0, 0.15) * 0.5, 2.6)           # D4 arrives
    place(track, timpani(73.42, 1.9) * 1.6, 2.6)
    place(track, timpani(55.0, 1.6) * 1.0, 2.95)
    track /= np.max(np.abs(track)) * 1.12
    pcm = (track * 32767).astype("<i2")
    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "arche_startup.wav")
