
import os
import numpy as np
import matplotlib.pyplot as plt

from utils import load_csv, db
from plot import plot_time, plot_freqz, input_vs_output_time

# CONFIGURATION
CSV_PATH = "../log_simulations/fir_sinusoidal_sim_logs.csv"   # log file from simulation 
signal_type = "sinusoidal"  # for plotting and saving files

WS_frequency = 48820.0                 # sample rate in Hz (sclk_freq/64 with sclk_freq=mclk_freq/4 and mclk_period=80ns)
COEFF = np.array([1,2,2,1], dtype=float) #low-pass FIR filter coefficients


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
    if not {"sample", "in_l_24", "out_l_24"}.issubset(fields):
        raise Exception("[WARN] CSV missing required columns; fields found:", fields)


    in_l  = data["in_l_24"].astype(float) # Left input signal (8-bit)
    out_l = data["out_l_24"].astype(float) # Left output signal (10-bit)


    # Plot the input and output signals in time domain
    plot_time(in_l, "Left input (24-bit)", filename="input_signal.svg", signal_type=signal_type) 
    plot_time(out_l, "Left output (24-bit)", filename="output_signal.svg", signal_type=signal_type)
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





# EXECUTION
data = load_csv(CSV_PATH)

# If the CSV file was loaded successfully, analyze the logged data
# Otherwise, run the demo with synthetic square wave
if data is not None:
    input_vs_output_time(data["in_l_24"], data["out_l_24"], signal_type)
    analyze_logged(data, WS_frequency)
    
else:
    print("ERROR: None data were provided!")
