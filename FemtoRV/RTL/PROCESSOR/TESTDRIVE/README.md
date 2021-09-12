This directory contains several versions of femtorv32, that I'm using
for testing different features and influence on timings:
- testdrive_RV32IM:      tachyon core (with two execute cycles) with M extension
- testdrive_RV32IM_simF: M extension, F decoder and simulated FPU (works only with Verilator)
- testdrive_RV32IMF:     M and F extensions

I recommend using the other cores instead.
