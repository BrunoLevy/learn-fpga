#!/bin/bash

PROFILE_ARGS=""
if [ "$1" == "--profile" ] ; then
    shift 1
    mrisc32-elf-readelf -sW out/mc1doom | grep FUNC | awk '{print $2,$8}' > /tmp/symbols.csv
    PROFILE_ARGS="-P /tmp/symbols.csv"
fi

mr32sim -g -ga 0x40000ae0 -gp 0x400006c4 -gd 8 -gw 320 -gh 180 ${PROFILE_ARGS} "$@" out/mc1doom.bin
