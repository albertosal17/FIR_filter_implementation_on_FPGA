
import os
import numpy as np
import matplotlib.pyplot as plt

from utils import load_csv, db
from plot import plot_time, plot_freqz

# CONFIGURATION
CSV_PATH = "../log_simulations/fir_squarewave_sim_logs.csv"   # log file from simulation 

WS_frequency = 48820                  # sample rate in Hz (sclk_freq/64 with sclk_freq=mclk_freq/4 and mclk_period=80ns)
COEFF = np.array([1,2,2,1], dtype=float) #low-pass FIR filter coefficients

signal_type = "squarewave"  # for plotting and saving files

def analyze_logged(data, fs):
    """
    Analyze the logged data from the CSV file. 
    First, it plots the input and output signals in time domain, 
    then it computes and plots their frequency response.

    Note: We assume the data contains only the signals from left channel

    Args:
    data: numpy structured array containing the logged data.
    fs: Sampling frequency in Hz. It coincides with word select clock frequency.
    """

    # load the names of the variables in the CSV file (from the header)
    fields = data.dtype.names 
    if not {"sample","in_l_8","out_l_10"}.issubset(fields):
        raise Exception("[WARN] CSV missing required columns; fields found:", fields)


    in_l  = data["in_l_8"].astype(float) # Left input signal (8-bit)
    out_l = data["out_l_10"].astype(float) # Left output signal (10-bit)


    # Plot the input and output signals in time domain
    plot_time(in_l, "Left input (8-bit)", filename="input_signal.svg", signal_type=signal_type) 
    plot_time(out_l, "Left output (10-bit)", filename="output_signal.svg", signal_type=signal_type)
    plot_freqz(COEFF, fs, filename="fir_freq_response.svg", signal_type=signal_type)


    # Fast Fourier Transform (FFT) of the input and output signals
    # To plot the frequency responce
    N = min(len(out_l), 4096) # 4096 è tipica lunghezza, prendi il minimo tra la lunghezza del segnale di output e 4096
    
    IN = np.fft.rfft(in_l[:N]) 
    OUT = np.fft.rfft(out_l[:N])
    f = np.fft.rfftfreq(N, d=1/fs) # frequency bins corresponding to the FFT points


    plt.figure()

    plt.semilogx(f+1e-9, db(IN), label="Input", alpha=0.5)
    plt.semilogx(f+1e-9, db(OUT), label="Output", alpha=0.5)

    plt.title("Input vs Output spectrum (Left)")

    plt.xlabel("Frequency [Hz] (log)")
    plt.ylabel("Magnitude [dB]")
    plt.grid(True, which='both')
    plt.legend()
    plt.savefig("../plots_"+ signal_type + "_sim/"+"input_output_spectrum.svg", format='svg')
    plt.show()


def demo_square(coeff, fs):

    # Generate square wave signal
    f0 = 1000.0 # Frequency of the square wave in Hz 
    
    N = 5000 # Number of samples to generate
    t = np.arange(N)/fs # corresponding time vector

    sq = np.sign(np.sin(2*np.pi*f0*t)) # square wave    
    sq8 = (127*sq).astype(float) # 8-bit representation (scaled to [-127, 127])
    
    # Apply the FIR filter to the square wave signal
    y = np.convolve(sq8, coeff, mode='full')[:N]

    # Plot the input and output signals in time domain
    plot_time(sq8, "DEMO input: 1 kHz square (8-bit)", signal_type)
    plot_time(y,    "DEMO output: filtered [1,2,2,1]", signal_type)
    # Plot the frequency response of the FIR filter
    plot_freqz(coeff, fs, signal_type)



# EXECUTION
data = load_csv(CSV_PATH)

# If the CSV file was loaded successfully, analyze the logged data
# Otherwise, run the demo with synthetic square wave
if data is not None:
    analyze_logged(data, WS_frequency)
else:
    print("[INFO] Running demo with synthetic square wave...")
    demo_square(COEFF, WS_frequency)
