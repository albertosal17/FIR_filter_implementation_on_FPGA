import numpy as np
import matplotlib.pyplot as plt
from utils_hw import load_csv, db

def db(x):
    """
    Converte amplitude segnali FFT in dB (scala log). eps evita log(0).
    """
    eps = 1e-12
    return 20*np.log10(np.maximum(np.abs(x),  eps))

    
def freq_response_filters(Fs, coeff_moving_avg, coeff_1221, coeff_big):
    # Plot risposte in frequenza dei filtri
    # Se fai la FFT dei coefficienti, ottieni la risposta in frequenza del filtro.
    # ( i coefficienti dei due filtri FIR sono le risposte impulsive)
    H1 = np.fft.rfft(coeff_moving_avg,  n=4096) # n sono i punti di FFT da calcolare
    H2 = np.fft.rfft(coeff_1221, n=4096)
    H3 = np.fft.rfft(coeff_big, n=4096)
    fH = np.fft.rfftfreq(4096, d=1/Fs)

    H1dB = db(H1)
    H2dB = db(H2)
    H3dB = db(H3)

    plt.figure()
    plt.plot(fH, H1dB, label="MA [1,1,1,1]/4", color="navy", alpha=0.4)
    plt.plot(fH, H2dB, label="[1,2,2,1]/6", color="red", alpha=0.4)
    plt.plot(fH, H3dB, label="[-10,120,-127,20]/207", color="purple", alpha=0.4)
    plt.title(f"Frequency responce of the filters to 1kHz sin + {noise_mode} noise")
    plt.xlabel("Frequency [Hz]"); plt.ylabel("Amplitude [dB]")
    plt.grid(True); plt.legend()
    plt.savefig('plot/freq_responce.svg', format='svg')
    plt.show()


def run_simulation(Fs,N,f_sig,A_sig, noise_mode, f_noise10k,A_noise, coeff_moving_avg, coeff_1221):


    # Genrazione del segnale totale (con noise)
    t = np.arange(N) / Fs # istanti di campionamento
    x_sig = A_sig * np.sin(2*np.pi*f_sig*t) # segnale

    if noise_mode == "tone10k":
        x_noise = A_noise * np.sin(2*np.pi*f_noise10k*t)

    else:
        rng = np.random.default_rng(0)
        x_noise = A_noise * rng.standard_normal(N)

    x = x_sig + x_noise

    # Genero segnale filtrato filtro  FIR al segnale (linear convolution) 
    y_moving_avg   = np.convolve(x, coeff_moving_avg,  mode='same')
    y_1221  = np.convolve(x, coeff_1221, mode='same')


    ### Calcolo spettri (la composizione in frequenze) dei segnali: intensità vs frequenze
    ### Nota: uso una finestra di Hann per ridurre il "leakage".
    # Passo al dominio delle frequenze con FFT
    w = np.hanning(N)
    X  = np.fft.rfft(x * w)
    Y1 = np.fft.rfft(y_moving_avg * w)
    Y2 = np.fft.rfft(y_1221 * w)
    # Determino le frequenze da rappresentare nei plot degli spettri, data la frequenza di campionamento
    f  = np.fft.rfftfreq(N, d=1/Fs)

    # retrieve the amplitude for each frequecy
    magX  = np.abs(X)
    magY1 = np.abs(Y1)
    magY2 = np.abs(Y2)

    # retrieve the peak of input signal
    peak = np.max(magX)   # uso picco dell'input come riferimento comune 
    
    # normalize wrt the input peak (it will be equal to 0 dB, and all'other amplitudes will be negative)
    XdB = db(magX / peak)
    Y1dB = db(magY1 / peak)
    Y2dB = db(magY2 / peak)

    # Spettri: input vs output
    plt.figure()
    plt.semilogx(f+1e-6, XdB,  label="Input", alpha=0.5, color="green")        # +1e-6 evita log(0) sull'asse
    plt.semilogx(f+1e-6, Y1dB, label="Output MA4", alpha=0.5, color="navy")
    plt.semilogx(f+1e-6, Y2dB, label="Output [1,2,2,1]", alpha=0.5, color="red")
    plt.title("SIMULATION - Input vs filtered spectra")
    plt.xlabel("Frequency [Hz]"); plt.ylabel("Amplitude [dB]")
    plt.grid(True, which='both'); plt.legend()
    plt.savefig('plot/spectra.svg', format='svg')
    plt.show()

    # Zoom 100 Hz – 20 kHz 
    mask = (f >= 100) & (f <= 20000)
    plt.figure()
    plt.plot(f[mask], XdB[mask],  label="Input", alpha=0.5, color="green")
    plt.plot(f[mask], Y1dB[mask], label="MA4", alpha=0.5,  color="navy")
    plt.plot(f[mask], Y2dB[mask], label="[1,2,2,1]", alpha=0.5, color="red")
    plt.title("SIMULATION - Input vs filtered spectra [Zoom 0.1-20 kHz]")
    plt.xlabel("Frequency [Hz]"); plt.ylabel("Amplitude [dB]")
    plt.grid(True); plt.legend()
    plt.savefig('plot/spectra_zoom100_20k.svg', format='svg')
    plt.show()

    return

# COnfigurazione segnale sinusoidale
Fs = 44100.0          # Frequenza di campionamento segnale
N  = 2048            # campioni per FFT/plot (aumentalo per aumentare la risoluzione in frequenza)
print("Scegli N")
f_sig = 1000.0        # seno 1 kHz
A_sig = 1.0

# COnfigurazione noise
noise_mode = "white"  # "tone10k" oppure "white"
f_noise10k = 10000.0
A_noise = 0.3


# FIR FILTERS (normalizzati a guadagno 1)
coeff_moving_avg   = np.array([1,1,1,1], dtype=float) / 4.0
coeff_1221  = np.array([1,2,2,1], dtype=float) / 6.0
coeff_big  = np.array([-10,120,127,-20], dtype=float) / 207.0

freq_response_filters(Fs, coeff_moving_avg, coeff_1221, coeff_big)
#run_simulation(Fs,N,f_sig,A_sig, noise_mode, f_noise10k,A_noise, coeff_moving_avg, coeff_1221)




####################################################################################
# REAL DATA ANALYSIS - 
####################################################################################




def fpga_signal_analysis(filter_type):
    """
    filter_type: eiter  "1221" or "MA" or "big"
    """
    CSV_PATH = f"../../log_from_hardware/filter_{filter_type}.csv"   # log file from simulation 


    # LOAD DATA
    print(f"Loading data from {CSV_PATH}")  

    data = load_csv(CSV_PATH)
    if data is not None:

        print(data.shape)

        fields = data.dtype.names 
        print(fields)

        # Retrieve output signals for left and right channel

        input_L = data["l_in230"][1:] # escludo il primo, che è una parola ('signed')
        output_L = data["l_data_tx230"][1:] # escludo il primo, che è una parola ('signed')


    else:
        raise Exception("ERROR: None data were found!")

    input_L = input_L.astype(np.float64) / (2**23 - 1) # converto al range [-1,1]
    output_L = output_L.astype(np.float64) / (2**23 - 1) # converto al range [-1,1]

    w = np.hanning(len(input_L))

    X = np.fft.rfft(input_L * w, n=N)
    Y = np.fft.rfft(output_L * w, n=N)

    f = np.fft.rfftfreq(N, d=1/Fs)

    # retrieve the amplitude for each frequecy (it is the real abs value of the fft output )
    magX  = np.abs(X)
    magY = np.abs(Y)
    # retrieve the peak of input signal
    peak = np.max(magX) 

    # normalize wrt the input peak (it will be equal to 0 dB, and all'other amplitudes will be negative)
    XdB = db(magX/peak)
    YdB = db(magY/peak)

    if filter_type=="MA": color_filtered_signal = "navy"
    elif filter_type=="1221": color_filtered_signal = "red"
    elif filter_type=="big": 
        color_filtered_signal = "purple"
        filter_type="[-10,110,127,-20]" #for naming labels

    plt.figure()
    plt.semilogx(f+1e-6, XdB, label="Input", alpha=0.5, color="green")
    plt.semilogx(f+1e-6, YdB, label=f"Output {filter_type}", alpha=0.5, color=color_filtered_signal)
    plt.title("FPGA - Input vs Output spectra")
    plt.xlabel("Frequency [Hz]")
    plt.ylabel("Amplitude [dB]")
    plt.grid(True, which='both')
    plt.legend()
    plt.savefig(f'plot/hw_{filter_type}_spectra.svg', format='svg')
    plt.show()

    # zoom audio band
    mask = (f >= 100) & (f <= 20000)
    plt.figure()
    plt.plot(f[mask], XdB[mask], label="Input", alpha=0.5, color="green")
    plt.plot(f[mask], YdB[mask], label=f"Output {filter_type}", alpha=0.5, color=color_filtered_signal)
    plt.title("FPGA - Input vs Output spectra [Zoom 0.1-20 kHz]")
    plt.xlabel("Frequency [Hz]")
    plt.ylabel("Amplitude [dB]")
    plt.grid(True)
    plt.legend()
    plt.savefig(f'plot/hw_{filter_type}_spectra_zoom100_20k.svg', format='svg')
    plt.show()

    return


#fpga_signal_analysis(filter_type="MA")
#fpga_signal_analysis(filter_type="1221")
#fpga_signal_analysis(filter_type="big")

