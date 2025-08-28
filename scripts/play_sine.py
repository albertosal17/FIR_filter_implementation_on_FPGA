import numpy as np
import sounddevice as sd

Fs = 44100
f0 = 1000.0
amplitude = 0.8

t = np.arange(Fs) / Fs         # 1 second of audio
x = amplitude * np.sin(2*np.pi*f0*t)
stereo = np.column_stack([x, x])  # L=R

print(f"Playing {f0} Hz sine... Ctrl+C to stop")

try:
    # just play in an infinite loop
    sd.play(stereo, samplerate=Fs, loop=True)
    sd.wait()   # wait forever until Ctrl+C
except KeyboardInterrupt:
    sd.stop()
    print("\nStopped.")
