#########
# With this script i analize the signals acquired from source i2s_playback_sinusoidal
##################

import os
import numpy as np
import matplotlib.pyplot as plt

from utils_hw import load_csv, db
from plot_hw import plot_time


# LOAD DATA
CSV_PATH = "../../log_from_hardware/log_i2s_playback_sinusoidal.csv"   # log file from simulation 
data = load_csv(CSV_PATH)

if data is not None:

    print(data.shape)

    fields = data.dtype.names 
    print(fields)

    # Retrieve output signals for left and right channel
    if not {"r_data_rx230", "l_data_rx230"}.issubset(fields):
        raise Exception("[WARN] CSV missing required columns; fields found:", fields)
    out_signal_right = data["r_data_rx230"][1:1000] # escludo il primo, che è una parola ('signed')
    out_signal_left = data["l_data_rx230"][1:1000] # escludo il primo, che è una parola ('signed')

    # Convert str -> int
    out_signal_right = out_signal_right.astype(np.int32) 
    out_signal_left = out_signal_left.astype(np.int32) 

    plot_time(out_signal_right, "Output playback channel R (24-bit)", test_type='playback')
    plot_time(out_signal_left, "Output playback channel L (24-bit)", test_type='playback')

else:
    print("ERROR: None data were found!")

