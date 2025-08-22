import matplotlib.pyplot as plt
import numpy as np
from utils import db

def plot_time(sig, title, signal_type, ylabel="Amplitude", filename=None):
    """
    Plot the signal in time domain (time on x axis, amplitude on y axis).

    signal_type: either "squarewave" or "sinusoidal".
    """
    plt.figure()

    plt.plot(sig)

    plt.title(title)
    plt.xlabel("Samples")
    plt.ylabel(ylabel)
    plt.grid(True)

    plt.savefig("../plots_"+ signal_type +"_sim/"+filename) if filename else None
    plt.show()


def plot_freqz(coeff, fs, signal_type, filename=None):
    """
    Plot the signal in frequency domain.
    coeff: FIR filter coefficients.
    fs: Sampling frequency in Hz. It coincides with word select clock frequency.
    """
    nfft = 4096 # Number of points for FFT. Must be a power of 2 for performance.

    H = np.fft.rfft(coeff, n=nfft) #rfft: real fast-Fourier transform. Evita di calcolare la FFT completa, che sarebbe simmetrica (ridontante). 
    # H è il guadagno in frequenza della risposta del filtro FIR: ti dice quanto amplifica (H>0) o attenua (H<0) il segnale in ciascuna frequenza.
    f = np.fft.rfftfreq(nfft, d=1/fs) # Calcola i valori di frequenza (in Hz) corrispondenti a ciascun punto dell’FFT. 1/fs è il periodo di campionamento (word select).

    plt.figure()

    plt.plot(f, db(H)) # Plot the magnitude response in dB

    plt.title("FIR |H(f)| dB (coeff = [1,2,2,1])")
    plt.xlabel("Frequency [Hz]")
    plt.ylabel("Magnitude [dB]")
    plt.grid(True)

    plt.savefig("../plots_"+signal_type+"_sim/"+filename) if filename else None
    plt.show()

def input_vs_output_time(in_signal, out_signal, signal_type):
    """
    Plot the input and output signals in time domain.
    in_signal: Input signal (numpy array).
    out_signal: Output signal (numpy array).
    signal_type: either "squarewave" or "sinusoidal".
    """
    plt.figure()
    plt.plot(in_signal, label="Input", color="blue", alpha=0.5)
    plt.plot(out_signal, label="Output", color="red", alpha=0.5)
    plt.title("Input vs Output signals")
    plt.xlabel("Samples")
    plt.ylabel("Amplitude")
    plt.grid(True)
    plt.legend()
    plt.savefig("../plots_"+signal_type+"_sim/input_output_time.svg", format='svg')
    plt.show()
