"""Bake the supplied SFXR oldParams sine preset into a mono 16-bit WAV.

Only this preset's active features are implemented. Refuse unsupported settings
rather than silently rendering a different sound. Run from any directory.
"""
import json
import math
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parents[3] / "assets/audio/sfx/dialogue"
p = json.loads((ROOT / "voice.json").read_text(encoding="utf-8"))
assert p["oldParams"] and p["wave_type"] == 2
assert p["sample_rate"] == 44100 and p["sample_size"] == 16
assert p["p_lpf_freq"] == 1
for key in ["p_env_attack", "p_env_punch", "p_freq_limit", "p_freq_ramp",
            "p_freq_dramp", "p_vib_strength", "p_vib_speed", "p_arp_mod",
            "p_arp_speed", "p_duty_ramp", "p_repeat_speed", "p_pha_offset",
            "p_pha_ramp", "p_lpf_ramp", "p_lpf_resonance", "p_hpf_ramp"]:
    assert p[key] == 0, f"Unsupported active parameter: {key}"
sustain = int(p["p_env_sustain"] ** 2 * 100000)
decay = int(p["p_env_decay"] ** 2 * 100000)
period = int(100 / (p["p_base_freq"] ** 2 + 0.001))
cutoff = p["p_hpf_freq"] ** 2 * 0.1
phase = 0
previous = highpass = 0.0
samples = bytearray()
for i in range(sustain + decay):
    envelope = 1.0 if i < sustain else 1.0 - (i - sustain) / decay
    total = 0.0
    for _ in range(8):
        phase = (phase + 1) % period
        sample = math.sin(phase / period * math.tau)
        highpass = (highpass + sample - previous) * (1.0 - cutoff)
        previous = sample
        total += highpass * envelope
    value = max(-1.0, min(1.0, total / 8 * p["sound_vol"] ** 2))
    samples.extend(struct.pack("<h", round(value * 32767)))
with wave.open(str(ROOT / "voice.wav"), "wb") as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(p["sample_rate"])
    wav.writeframes(samples)
