cp ../FIRMWARE/firmware.hex FIRMWARE/
rm -f bench
iverilog bench.v -o bench
vvp bench
