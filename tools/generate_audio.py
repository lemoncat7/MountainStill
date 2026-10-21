#!/usr/bin/env python3
"""Original quiet procedural score and soft UI cues. No external recordings."""
from pathlib import Path
import math
import wave
import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets/audio"
OUT.mkdir(parents=True, exist_ok=True)

def write(name, samples, peak=0.22):
    samples = np.asarray(samples, dtype=np.float64)
    maximum = np.max(np.abs(samples))
    if maximum:
        samples *= peak / maximum
    pcm = np.round(np.clip(samples, -1, 1) * 32767).astype('<i2')
    with wave.open(str(OUT / name), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    print(f'{name}: {len(samples)/RATE:.2f}s, peak {20*np.log10(peak):.1f} dBFS')

def note(freq, duration, gain=1.0):
    t = np.arange(round(duration * RATE)) / RATE
    attack = 1 - np.exp(-t * 35)
    decay = np.exp(-t * 2.7 / duration)
    release = np.clip((duration - t) / 0.35, 0, 1) ** 2
    # A round, felt-like tone: no harsh square/saw waveform.
    return gain * attack * decay * release * (np.sin(2*np.pi*freq*t) + 0.19*np.sin(4*np.pi*freq*t) + 0.045*np.sin(6*np.pi*freq*t))

def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)

length = 32.0
music = np.zeros(round(length * RATE))
# Four eight-second phrases, slow D/A/Bm/G colors with a pentatonic melody.
chords = [[50,57,62,66], [45,52,57,64], [47,54,59,62], [43,50,55,62]]
for phrase, chord in enumerate(chords):
    for step in range(8):
        midi = chord[[0,2,1,3,2,1,3,2][step]] + (12 if step % 3 == 1 else 0)
        tone = note(hz(midi), 2.4, 0.55 if step % 2 else 0.7)
        start = round((phrase * 8 + step) * RATE)
        idx = (np.arange(len(tone)) + start) % len(music)
        music[idx] += tone
    bass = note(hz(chord[0]-12), 7.7, 0.36)
    start = round(phrase*8*RATE)
    music[start:start+len(bass)] += bass
# Periodic three-tap ambience stays seamless across the loop boundary.
music = music + np.roll(music, round(0.37*RATE))*0.13 + np.roll(music, round(0.71*RATE))*0.06
write('music.wav', music, 0.24)

def cue(name, melody, spacing, duration, peak):
    result = np.zeros(math.ceil((spacing*(len(melody)-1)+duration)*RATE)+2)
    for i, midi in enumerate(melody):
        tone = note(hz(midi), duration, 0.9**i)
        start = round(i*spacing*RATE)
        result[start:start+len(tone)] += tone
    write(name+'.wav', result, peak)

cue('loot', [74,78,81], 0.11, 0.8, 0.18)
cue('level', [62,66,69,74], 0.16, 0.9, 0.20)
cue('equip', [57,69], 0.065, 0.36, 0.14)
