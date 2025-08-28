import numpy as np
import sounddevice as sd

Fs = 44100
amp = 0.2  # volume (abbassa se serve)

def tone(f, dur, amp=0.2):
    t = np.linspace(0, dur, int(Fs*dur), endpoint=False)
    x = np.sin(2*np.pi*f*t)
    # fade-in/out 5 ms per evitare click
    n = int(Fs*0.005)
    if len(x) >= 2*n and n > 0:
        w = np.linspace(0, 1, n)
        x[:n] *= w
        x[-n:] *= w[::-1]
    return (amp*x).astype(np.float32)

# Note (Hz)
C4=261.63; D4=293.66; E4=329.63; F4=349.23; G4=392.00; A4=440.00
q = 0.4  # durata "quarto" in secondi

# Twinkle Twinkle (in C)
melody = [
    (C4,q),(C4,q),(G4,q),(G4,q),(A4,q),(A4,q),(G4,2*q),
    (F4,q),(F4,q),(E4,q),(E4,q),(D4,q),(D4,q),(C4,2*q),
]

gap = 0.02  # pausa tra note
song = np.concatenate([
    np.concatenate([tone(f, d, amp), np.zeros(int(Fs*gap), dtype=np.float32)])
    for f, d in melody
])

stereo = np.column_stack([song, song])  # L=R

sd.default.samplerate = Fs
sd.default.channels = 2
sd.play(stereo, Fs)
sd.wait()
