
import os
import numpy as np
import matplotlib.pyplot as plt

# === CONFIG ===
CSV_PATH = "fir_squarewave_sim_logs.csv"   # put your exported VHDL log here (same folder as this script)
FS = 48000                  # sample rate in Hz (adjust to your setup)
COEFF = np.array([1,2,2,1], dtype=float)

def load_csv(path):
    try:
        data = np.genfromtxt(path, delimiter=',', names=True, dtype=None, encoding='utf-8')
        return data
    except Exception as e:
        print(f"[WARN] Could not load '{path}': {e}")
        return None

def plot_time(sig, title, ylabel="Amplitude"):
    plt.figure()
    plt.plot(sig)
    plt.title(title)
    plt.xlabel("Samples")
    plt.ylabel(ylabel)
    plt.grid(True)
    plt.show()

def db(x):
    eps = 1e-12
    return 20*np.log10(np.maximum(np.abs(x), eps))

def plot_freqz(coeff, fs):
    nfft = 4096
    H = np.fft.rfft(coeff, n=nfft)
    f = np.fft.rfftfreq(nfft, d=1/fs)
    plt.figure()
    plt.plot(f, db(H))
    plt.title("FIR |H(f)| dB (coeff = [1,2,2,1])")
    plt.xlabel("Frequency [Hz]")
    plt.ylabel("Magnitude [dB]")
    plt.grid(True)
    plt.show()

def analyze_logged(data, fs):
    fields = data.dtype.names
    if not {"sample","in_l_8","out_l_10"}.issubset(fields):
        print("[WARN] CSV missing required columns; fields found:", fields)
        return
    s_idx = data["sample"]
    in_l  = data["in_l_8"].astype(float)
    out_l = data["out_l_10"].astype(float)

    plot_time(in_l, "Left input (8-bit)")
    plot_time(out_l, "Left output (10-bit)")
    plot_freqz(COEFF, fs)

    N = min(len(out_l), 4096)
    win = np.hanning(N)
    IN = np.fft.rfft(in_l[:N]*win)
    OUT = np.fft.rfft(out_l[:N]*win)
    f = np.fft.rfftfreq(N, d=1/fs)

    plt.figure()
    plt.semilogx(f+1e-9, db(IN), label="Input")
    plt.semilogx(f+1e-9, db(OUT), label="Output")
    plt.title("Input vs Output spectrum (Left)")
    plt.xlabel("Frequency [Hz] (log)")
    plt.ylabel("Magnitude [dB]")
    plt.grid(True, which='both')
    plt.legend()
    plt.show()

    if {"in_r_8","out_r_10"}.issubset(fields):
        in_r  = data["in_r_8"].astype(float)
        out_r = data["out_r_10"].astype(float)
        plot_time(in_r, "Right input (8-bit)")
        plot_time(out_r, "Right output (10-bit)")

def demo_square(coeff, fs):
    f0 = 1000.0
    N = 5000
    t = np.arange(N)/fs
    sq = np.sign(np.sin(2*np.pi*f0*t))
    sq8 = (127*sq).astype(float)
    y = np.convolve(sq8, coeff, mode='full')[:N]

    plot_time(sq8, "DEMO input: 1 kHz square (8-bit)")
    plot_time(y,    "DEMO output: filtered [1,2,2,1]")
    plot_freqz(coeff, fs)



# execution
data = load_csv(CSV_PATH)
if data is not None:
    analyze_logged(data, FS)
else:
    print("[INFO] Running demo with synthetic square wave...")
    demo_square(COEFF, FS)
