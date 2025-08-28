import numpy as np
import sounddevice as sd

Fs = 44100
amp = 0.2     # volume melodia
noise_amp = 0.05  # livello rumore HF (prova 0.02–0.10)

def tone(f, dur, amp=0.2):
    t = np.linspace(0, dur, int(Fs*dur), endpoint=False)
    x = np.sin(2*np.pi*f*t)
    n = int(Fs*0.005)  # 5 ms fade in/out
    if len(x) >= 2*n and n > 0:
        w = np.linspace(0, 1, n)
        x[:n] *= w; x[-n:] *= w[::-1]
    return (amp*x).astype(np.float32)

# Note (Hz)
C4=261.63; D4=293.66; E4=329.63; F4=349.23; G4=392.00; A4=440.00
q = 0.4  # durata "quarto"

melody = [
    (C4,q),(C4,q),(G4,q),(G4,q),(A4,q),(A4,q),(G4,2*q),
    (F4,q),(F4,q),(E4,q),(E4,q),(D4,q),(D4,q),(C4,2*q),
]

# Costruisci la melodia
gap = 0.02
song = np.concatenate([
    np.concatenate([tone(f, d, amp), np.zeros(int(Fs*gap), dtype=np.float32)])
    for f, d in melody
])

# --- Rumore HF: somma di sinusoidi tra 10 e 18 kHz, fasi casuali ---
t = np.arange(len(song)) / Fs
rng = np.random.default_rng(123)
K = 8  # numero componenti
freqs = rng.uniform(10000, 18000, size=K)
phases = rng.uniform(0, 2*np.pi, size=K)
hf_noise = np.zeros_like(song, dtype=np.float32)
for f, ph in zip(freqs, phases):
    hf_noise += np.sin(2*np.pi*f*t + ph).astype(np.float32)
hf_noise *= (noise_amp / max(1, K/2))  # scala per non clippar eccessivo

# (opzionale) interferenze pure a 10 kHz e 15 kHz
# hf_noise += 0.03*np.sin(2*np.pi*10000*t) + 0.03*np.sin(2*np.pi*15000*t)

# Mix e normalizzazione soft
mix = song + hf_noise
peak = np.max(np.abs(mix))
if peak > 0.99:
    mix = (0.99/peak) * mix

stereo = np.column_stack([mix, mix])  # L=R

sd.default.samplerate = Fs
sd.default.channels = 2
sd.play(stereo, Fs)
sd.wait()
