"""Original MODUS Black Start ambience; no recordings, samples or third-party assets.

Offline authoring only, Python standard library. Seeded noise, multiband filtering,
resonant partials, gust envelopes, rain impacts and machinery load cycles produce
six eight-second PCM16 mono loops. Native AudioStreamWAV text resources need no
importer in extracted MDSL packages. Run from any directory to regenerate.
"""
from array import array
from pathlib import Path
import math
import random
import sys

RATE = 16000
DURATION = 8
COUNT = RATE * DURATION
TAU = math.tau


def periodic_noise(seed, cutoff):
    # Crossfade the head against a continuation of the tail for a click-free seam.
    rng = random.Random(seed)
    alpha = 1.0 - math.exp(-TAU * cutoff / RATE)
    values = []
    low = 0.0
    for _ in range(COUNT + RATE):
        low += alpha * (rng.uniform(-1.0, 1.0) - low)
        values.append(low)
    for i in range(RATE):
        w = 0.5 - 0.5 * math.cos(math.pi * i / RATE)
        values[i] = values[COUNT + i] * (1 - w) + values[i] * w
    return values[:COUNT]


def synth(kind, seed):
    rumble = periodic_noise(seed, 85)
    body = periodic_noise(seed + 1, 750)
    air = periodic_noise(seed + 2, 5000)
    values = []
    for i in range(COUNT):
        t = i / RATE
        gust = 0.64 + 0.22 * math.sin(TAU * t / 8) + 0.10 * math.sin(TAU * 3 * t / 8 + 0.7)
        turbine = math.sin(TAU * 62.5 * t) + 0.33 * math.sin(TAU * 125 * t + 0.4)
        load = 0.72 + 0.16 * math.sin(TAU * 5 * t / 8)
        if kind == "exterior":
            surf = (0.5 + 0.5 * math.sin(TAU * 2 * t / 8 - 1.2)) ** 3
            value = gust * (1.1 * rumble[i] + 0.33 * body[i]) + (0.09 + 0.16 * surf) * air[i]
        elif kind == "shelter":
            # Attenuated wind through structure, metallic rain scatter on roofing.
            impact = max(0.0, math.sin(TAU * 37.125 * t) * math.sin(TAU * 19.625 * t)) ** 18
            ring = math.sin(TAU * 873.0 * t) + 0.3 * math.sin(TAU * 1291.0 * t)
            value = 0.8 * rumble[i] * gust + 0.065 * body[i] + 0.10 * impact * ring + 0.025 * air[i]
        elif kind == "pump":
            piston = (0.5 + 0.5 * math.sin(TAU * 11 * t / 8)) ** 14
            clatter = math.sin(TAU * 213 * t) + 0.35 * math.sin(TAU * 491 * t)
            value = 0.08 * turbine * load + 0.20 * rumble[i] + 0.1 * body[i] + 0.065 * piston * clatter
        elif kind == "coolant":
            wash = 0.8 + 0.15 * math.sin(TAU * 3 * t / 8)
            value = 0.046 * turbine + 0.35 * body[i] * wash + 0.13 * air[i] + 0.24 * rumble[i]
        elif kind == "station":
            value = 0.055 * math.sin(TAU * 50 * t) + 0.028 * math.sin(TAU * 100 * t + 0.2)
            value += 0.012 * math.sin(TAU * 200 * t) + 0.28 * rumble[i] + 0.11 * body[i] * load + 0.026 * air[i]
        else:
            # Cave drips are decaying, inharmonic water resonances over low seepage.
            value = 0.21 * rumble[i] + 0.075 * body[i]
            for start, frequency in [(0.7, 937), (2.1, 1201), (4.8, 829), (6.3, 1057)]:
                elapsed = (t - start) % DURATION
                if elapsed < 0.35:
                    envelope = math.exp(-elapsed * 22) * min(elapsed * 600, 1)
                    value += 0.22 * envelope * (math.sin(TAU * frequency * elapsed) + 0.25 * math.sin(TAU * frequency * 1.43 * elapsed))
        values.append(value)
    dc = sum(values) / COUNT
    values = [v - dc for v in values]
    peak = max(abs(v) for v in values)
    scale = min(0.68 / peak, 0.20 / math.sqrt(sum(v * v for v in values) / COUNT))
    pcm = array("h", (round(v * scale * 32767) for v in values))
    if sys.byteorder != "little":
        pcm.byteswap()
    return pcm.tobytes()


def main():
    folder = Path(__file__).resolve().parent
    for number, kind in enumerate(("exterior", "shelter", "pump", "coolant", "station", "cavern")):
        data = synth(kind, 7301 + number * 101)
        resource = '[gd_resource type="AudioStreamWAV" format=3]\n\n[resource]\n'
        resource += f'resource_name = "Black Start / {kind.title()} / MODUS original"\n'
        resource += f'format = 1\nloop_mode = 1\nloop_begin = 0\nloop_end = {COUNT}\nmix_rate = {RATE}\nstereo = false\n'
        resource += 'data = PackedByteArray(' + ', '.join(map(str, data)) + ')\n'
        destination = folder / f"black_start_{kind}.tres"
        destination.write_text(resource)
        print(f"Authored {destination.name}: {DURATION}s PCM16 mono, {len(data)} sample bytes")


if __name__ == "__main__":
    main()
