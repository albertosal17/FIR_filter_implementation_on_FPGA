import numpy as np
import matplotlib.pyplot as plt
import sounddevice as sd

PLAY = False
#PLAY = True

# Parameters
fs = 44100            # sampling rate (Hz)
duration =  0.06       # seconds:  1 ms → ~9 ripetizioni in 90 ms ILA
pulse_start = duration/3    # seconds
pulse_end = duration-pulse_start   # seconds
amplitude = 1.0

add_noise = True
noise_std = 0.05      # standard deviation of Gaussian noise

N_repetitions = 50


# Build rectangular pulse input signal
N = int(fs * duration) #number of samples in the signal

x = np.zeros(N, dtype=float)
x[int(pulse_start*fs):int(pulse_end*fs)] = amplitude



# Add random noise
if add_noise:
    x = x + np.random.normal(0.0, noise_std, size=N)

# RIpeti il segnale più volte per poterlo vedere in ILA
x_tot = np.tile(x, N_repetitions)

# Build time axis
N_tot = len(x)
t = np.arange(N_tot) / fs


if PLAY:


    sd.play(x_tot, fs)  # blocking=True aspetta la fine prima di ricominciare
    sd.wait()


else: #plot simulation results

    # 4-tap moving-average FIR 
    M = 4 #order of the filter
    h = np.ones(M) / float(M)
    y = np.convolve(x, h, mode='full')
    print(y.shape)
    y = y[:N] #for plot reason discard the last few output samples


    # ==== Plot input ====
    plt.figure(figsize=(10,4))
    plt.plot(np.arange(N), x, label='Input', linewidth=1.5, color='navy', alpha=0.7)
    plt.title(f'Square impulse input w random noise')
    plt.xlabel('Samples')
    plt.ylabel('Amplitude')
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.savefig("sim_square_in.svg", format='svg')
    plt.show()

    # ==== Plot output ====
    plt.figure(figsize=(10,4))
    plt.plot(np.arange(N), y, label='Output', linewidth=1.5, color='darkred', alpha=0.7)
    plt.title(f'Output from order {M} Moving Average FIR')
    plt.xlabel('Samples')
    plt.ylabel('Amplitude')
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.savefig("sim_square_out.svg", format='svg')
    plt.show()


