import numpy as np
import sounddevice as sd

Fs = 44100        # samplitudele rate per compatibilità con LRCK 44.1 kHz
f0 = 1000.0       # frequency in Hz
amplitude = 0.8      # 20% full scale (parti basso per evitare clipping)

t = np.arange(int(Fs*1.0))/Fs  # 1 secondo di buffer
x = amplitude*np.sin(2*np.pi*f0*t) #sine signal
stereo = np.column_stack([x, x])  # L=R


sd.default.samplerate = Fs
sd.default.channels = 2

print(f"Playing {f0} Hz sine... Ctrl+C to stop")
try:
    # stream in loop
    with sd.OutputStream():
        while True:
            sd.play(stereo, Fs, blocking=True)
except KeyboardInterrupt:
    print("\nStopped.")