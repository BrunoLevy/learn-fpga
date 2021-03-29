yosys -DPVT -p 'synth_ice40 -dsp -top vga -json vga.json' vga.v
nextpnr-ice40 --up5k --package uwg30 --pcf fomu-pvt.pcf --json vga.json --asc vga.asc
icepack vga.asc vga.bit
cp vga.bit vga.dfu
dfu-suffix -v 1209 -p 70b1 -a vga.dfu
dfu-util -D vga.dfu



