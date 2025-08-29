import numpy as np

def db(x):
    """
    Convert a signal to decibels (dB).
    """

    eps = 1e-12 # needed to avoid log(0)

    return 20*np.log10(np.maximum(np.abs(x), eps))


def load_csv(path):
    '''
    This function attempts to load the data contained in the CSV file containing the input and output signals to the FIR filter, simulated on Vivado.
    '''
    try:
        data = np.genfromtxt(path, delimiter=',', names=True, dtype=None, encoding='utf-8')

        return data
    
    # If the loading fails
    except Exception as e:
        print(f"[WARN] Could not load '{path}': {e}")

        return None