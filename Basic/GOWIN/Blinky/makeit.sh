FPGA_ROOT=/usr/bin
$FPGA_ROOT/yosys -D LEDS_NR=6 -DINV_BTN=0 -p "read_verilog blinky.v; synth_gowin -json blinky.json"
$FPGA_ROOT/nextpnr-gowin --json blinky.json --write pnrblinky.json --device GW1NR-LV9QN88PC6/I5 --family GW1N-9C --cst tangnano9k.cst
$FPGA_ROOT/gowin_pack -d GW1N-9C -o pack.fs pnrblinky.json
$FPGA_ROOT/openFPGALoader -b tangnano9k pack.fs
