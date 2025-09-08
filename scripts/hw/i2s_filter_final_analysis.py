#########
# With this script i analize the signals acquired from source i2s_playback_sinusoidal
##################

import os
import numpy as np
import matplotlib.pyplot as plt

from utils_hw import load_csv, db
from plot_hw import plot_time, input_vs_output_time


# LOAD DATA
CSV_PATH = "../../log_from_hardware/20TAPS.csv"   # log file from simulation 
test_type = "square_pulse_20taps_filter" # for naming saved plots

print(f"Loading data from {CSV_PATH}")    
data = load_csv(CSV_PATH)

if data is not None:

    print(data.shape)

    fields = data.dtype.names 
    print(fields)

    # Retrieve output signals for left and right channel
    #if not {"r_data_rx230", "l_data_rx230", "l_data_tx230", "r_data_tx230"}.issubset(fields):
    #    raise Exception("[WARN] CSV missing required columns; fields found:", fields)
    in_signal_left = data["l_in230"][4600:7600] # escludo il primo, che è una parola ('signed')
    #in_signal_right = data["r_data_tx230"][1:] # escludo il primo, che è una parola ('signed')
    out_signal_left = data["l_data_tx230"][4600:7600] # escludo il primo, che è una parola ('signed')
    #out_signal_right = data["r_data_rx230"][1:] # escludo il primo, che è una parola ('signed')

    # Convert str -> int
    #in_signal_right = in_signal_right.astype(np.int32) 
    in_signal_left = in_signal_left.astype(np.int32) 
    #out_signal_right = out_signal_right.astype(np.int32) 
    out_signal_left = out_signal_left.astype(np.int32) 

    plot_time(in_signal_left, "Input (channel L) ", filename="input_L.svg", test_type=test_type)
    plot_time(out_signal_left, "Output order 19 moving average FIR (channel L)", filename="output_L.svg", test_type=test_type, color='red')
    input_vs_output_time(in_signal_left, out_signal_left, test_type=test_type, channel="L", title="Order 19 moving average FIR")
    #plot_time(in_signal_right, "Input channel R (24-bit)", filename="input_R.svg", test_type='filter')
    #plot_time(out_signal_right, "Output from filter, channel R (24-bit)", filename="output_R.svg", test_type='filter')

else:
    print("ERROR: None data were found!")

