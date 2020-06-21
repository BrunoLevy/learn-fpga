femtorv32 / femtosoc:
a minimalistic RISC-V CPU, and companion SOC, that fit on the IceStick (< 1280 LUTs)
    - Implements the RV32I instruction set (minus FENCE and SYSTEM). 
    - Runs at 60MHz. 4Kb - 6kb RAM, optional memory-mapped IOs (UART, LEDs, OLed screen).
    - Synthesis using the freeware tools (Yosys and nextpnr).
    - Firmware can be generated with gnu RISC-V toolsuite (script included), in C or in assembly.
    - SOC memory-mapped device drivers and hardware for UART, built-in LEDs, OLed display, led matrix.
    - femtolibC, femtoGL (everything fits in 4kb / 6kb).
    - "femtOS" virtual output support: redirects printf() to UART, OLED screen (or led matrix, WIP).
    - many RISC-V assembly and C demo programs, including graphics for the OLED display.

1) FEMTOSOC/FEMTORV32 configuration
    - edit femtosoc.v and select the target board amount of RAM and on-board devices:
    - target board: supports ICEstick and ECP5 evaluation board
    - devices: 
       . on-board ICEstick LEDS
       . ICEstick UART
       . oled display SSD1351
       . led matrix MAX 2719
       . reset button
    - quantity of RAM
    - two-stage shifter (like in picorv32): makes shifts faster (but eats up around 60 luts)
    
On the ICEStick, do not activate everything simultaneously, it will not fit!
Start by activating what you need with the minimum amount of RAM (4K),
then add one thing at a time. Depending on YOSYS and NextPNR version,
it may use a different number of LUTs (and fit or not). Sometimes,
activating something uses a *smaller* number of LUTs (!). 

2) FIRMWARE
   - asm RISC-V and C example programs are included in FIRMWARE/EXAMPLES and FIRMWARE/C_EXAMPLES
   - IMPORTANT: make sure you specify the quantity of RAM in FIRMWARE/LIB/crt0.s,
     it needs to match what was configured in femtosoc.v !
   - to compile a sample program:
        cd FIRMWARE
	./make_firmware.sh EXAMPLE/xxxxx.s   or ./make_firmware.sh C_EXAMPLE/xxxxx.c 
     This will generate FIRMWARE/firmware.hex using the RISC-V GNU toolchain.
     You may need to edit the name of the RISC-V GNU tools in
     make_firmware.sh and LIB/makeit.sh depending on your installation. 
     I'm using the Linux Debian packages.

3) SYNTHESIS
    use ./makeit_icestick.sh or ./makeit_ecp5_evn.sh depending on your board.
    This will also send the bitstream to the device.
    
4) UART
    use ./start.sh to communicate with the board through a terminal.
    You can use any terminal emulator (at 115200 bauds).
    