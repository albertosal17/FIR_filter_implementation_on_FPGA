import numpy as np
import sounddevice as sd


# Parameters
fs = 44100            # sampling rate (Hz)
duration =  600      # seconds:  1 ms → ~9 ripetizioni in 90 ms ILA
noise_std = 0.05

# Build rectangular pulse input signal
N = int(fs * duration) #number of samples in the signal

x = np.random.normal(0.0, noise_std, size=N)


print("CTRL+C to stop...") 
try: 
    while True: 
        sd.play(x, fs, blocking=True) # blocking=True aspetta la fine prima di ricominciare 
except KeyboardInterrupt: 
        print("\nInterrupted.")






