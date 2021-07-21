#!/usr/bin/env bash
set -o nounset
set -o errexit

yosys -DPVT -p 'synth_ice40 -top top -json blink.json' blink.v
nextpnr-ice40 --up5k --package uwg30 --pcf fomu-pvt.pcf --json blink.json --asc blink.asc
icepack blink.asc blink.bit
cp blink.bit blink.dfu
dfu-suffix -v 1209 -p 70b1 -a blink.dfu
dfu-util -D blink.dfu
