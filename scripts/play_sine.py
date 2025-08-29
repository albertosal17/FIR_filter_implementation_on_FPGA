import numpy as np
import sounddevice as sd
import time

# Settings
Fs = 44100
f0 = 1000.0
amplitude = 0.8

f_noise = 10000.0
amplitude_noise = 0.1

# variabile di controllo
add_noise = False  

# fase continua (per evitare click)
phase_signal = 0.0
phase_noise = 0.0

def callback(outdata, frames, time_info, status):
    global phase_signal, phase_noise, add_noise
    t = np.arange(frames) / Fs
    
    # segnale principale
    sig = amplitude * np.sin(2*np.pi*f0*t + phase_signal)

    # aggiorna la fase
    phase_signal += 2*np.pi*f0*frames/Fs
    phase_signal = np.mod(phase_signal, 2*np.pi)

    if add_noise:
        noise = amplitude_noise * np.sin(2*np.pi*f_noise*t + phase_noise)
    else:
        noise = 0.0

    phase_noise += 2*np.pi*f_noise*frames/Fs
    phase_noise = np.mod(phase_noise, 2*np.pi)

    stereo = np.column_stack([sig+noise, sig+noise])
    outdata[:] = stereo.astype(np.float32)

# avvia lo stream
with sd.OutputStream(channels=2, samplerate=Fs, callback=callback):
    print("Riproduzione... premi n per toggle rumore, Ctrl+C per uscire")
    try:
        while True:
            cmd = input()
            if cmd.strip().lower() == "n":
                add_noise = not add_noise
                print(f"Noise {'ON' if add_noise else 'OFF'}")
    except KeyboardInterrupt:
        print("Interrotto.")
