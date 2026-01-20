#!/usr/bin/env bash
set -o nounset
set -o errexit

# Based on https://github.com/im-tomu/fomu-workshop/blob/master/hdl/board.mk
PCF_PATH="../../../FemtoRV/BOARDS"
test -v FOMU_REV || { echo 'error Unrecognized FOMU_REV value. must be "evt1", "evt2", "evt3", "pvt", or "hacker"'; exit 1; }
case "$FOMU_REV" in
  evt1)
    YOSYSFLAGS="-D EVT=1 -D EVT1=1 -D HAVE_PMOD=1"
    PNRFLAGS="--up5k --package sg48"
    PCF="$PCF_PATH/fomu-evt2.pcf"
    ;;
  evt2)
    YOSYSFLAGS="-D EVT=1 -D EVT2=1 -D HAVE_PMOD=1"
    PNRFLAGS="--up5k --package sg48"
    PCF="$PCF_PATH/fomu-evt2.pcf"
    ;;
  evt3)
    YOSYSFLAGS="-D EVT=1 -D EVT3=1 -D HAVE_PMOD=1"
    PNRFLAGS="--up5k --package sg48"
    PCF="$PCF_PATH/fomu-evt3.pcf"
    ;;
  hacker)
    YOSYSFLAGS="-D HACKER=1"
    PNRFLAGS="--up5k --package uwg30"
    PCF="$PCF_PATH/fomu-hacker.pcf"
    ;;
  pvt)
    YOSYSFLAGS="-D PVT=1"
    PNRFLAGS="--up5k --package uwg30"
    PCF="$PCF_PATH/fomu-pvt.pcf"
    ;;
  *)
    echo 'error Unrecognized FOMU_REV value. must be "evt1", "evt2", "evt3", "pvt", or "hacker"'
    exit 1
    ;;
esac

# shellcheck disable=SC2086   # Double quote to prevent globbing and word splitting.
yosys $YOSYSFLAGS -p 'synth_ice40 -top top -json blink.json' blink.v
# shellcheck disable=SC2086   # Double quote to prevent globbing and word splitting.
nextpnr-ice40 $PNRFLAGS --pcf "$PCF" --json blink.json --asc blink.asc
icepack blink.asc blink.bit
cp blink.bit blink.dfu
dfu-suffix -v 1209 -p 70b1 -a blink.dfu
dfu-util -D blink.dfu
