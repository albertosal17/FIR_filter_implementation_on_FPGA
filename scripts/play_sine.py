import numpy as np
import sounddevice as sd
import time

# Settings
Fs = 44100
f0 = 1000.0
amplitude = 1.0
#amplitude = 0  # if you want only noise
phase_signal = 0.0


# COnfigurazione noise
add_noise = False

noise_mode = "multi"  # "tone10k" oppure "white" oppure "multi"
f_noise10k = 10000.0
noise_freqs = np.array([5500.0, 7500.0, 11000.0, 13000.0, 16000.0], dtype=float)
A_noise = 0.3

rng = np.random.default_rng()
phase_noise = rng.uniform(0, 2*np.pi, size=noise_freqs.size)


def callback(outdata, frames, time_info, status):
    global phase_signal, phase_noise, add_noise, noise_mode
    
    t = np.arange(frames) / Fs
    
    # segnale principale
    sig = amplitude * np.sin(2*np.pi*f0*t + phase_signal)
    phase_signal = (phase_signal + 2*np.pi*f0*frames/Fs) % (2*np.pi)

    # rumore / tono
    if add_noise:
        if noise_mode == "tone10k":
            noise = A_noise * np.sin(2*np.pi*10000.0*t + phase_noise)
            phase_noise = (phase_noise + 2*np.pi*10000.0*frames/Fs) % (2*np.pi)
        elif noise_mode == "white":
            noise = A_noise * rng.standard_normal(frames)
        elif noise_mode == "multi":
            # divide total noise amplitude equally for each tone
            A_per_tone = A_noise / noise_freqs.size

            noise = np.zeros(frames)
            for i, f in enumerate(noise_freqs):
                # genero la sinusoide per la freq f
                tone = np.sin(2*np.pi*f*t + phase_noise[i])
                noise += A_per_tone * tone

                # aggiorno la fase di questo tono per il prossimo blocco
                phase_noise[i] = (phase_noise[i] + 2*np.pi*f*frames/Fs) % (2*np.pi)

        else:
            noise = 0.0
    else:
        noise = 0.0

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
