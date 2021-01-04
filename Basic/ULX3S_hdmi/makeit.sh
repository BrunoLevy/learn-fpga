yosys -p "synth_ecp5 -abc9 -top HDMI_test -json HDMI_test.json" HDMI_test_DDR.v HDMI_clock.v TMDS_encoder.v
nextpnr-ecp5 --json HDMI_test.json --lpf ulx3s.lpf --textcfg HDMI_test_out.config --85k --freq 25 --package CABGA381
ecppack --compress --svf-rowsize 100000 --svf HDMI_test.svf HDMI_test_out.config HDMI_test.bit
ujprog HDMI_test.bit



