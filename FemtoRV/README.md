FEMTORV32 / FEMTOSOC: a minimalistic RISC-V CPU, and companion SOC, that fit on the IceStick (< 1280 LUTs)

1) FEATURES
    - Implements the RV32I instruction set (minus FENCE and SYSTEM).
    - Synthesis using the freeware tools (Yosys and nextpnr).    
    - Main goal: to be used for teaching, easy to read, fitting on the ICEstick, 
      fun demos (graphics), equip students for approx. $40.
    - Disclaimer: I'm no FPGA expert, please feel free to comment, to
      give me some advice !
    - Runs at 60MHz. 4Kb - 6kb RAM, optional memory-mapped IOs (UART,
      LEDs, OLed screen). Can probably run faster on the ECP5 (100 - 150
      MHz). 
    - Firmware can be generated with gnu RISC-V toolsuite (script included), in C or in assembly.
    - SOC memory-mapped device drivers and hardware for UART, built-in LEDs, OLed display, led matrix.
    - femtolibC, femtoGL (everything fits in 4kb / 6kb).
    - "femtOS" virtual output support: redirects printf() to UART, OLED screen (or led matrix, WIP).
    - many RISC-V assembly and C demo programs, including graphics for the OLED display.

2) FEMTOSOC/FEMTORV32 configuration
    - edit femtosoc.v and select the target board, amount of RAM and on-board devices:
    - target board: supports ICEstick and ECP5 evaluation board
    - devices: 
       - on-board ICEstick LEDS
       - on-board ICEstick UART
       - oled display SSD1351 128x128x65K colors (WaveShare)
       - led matrix MAX 2719
       - reset button (active low, you'll need to wire it on the ICEstick)
    - quantity of RAM
    - two-stage shifter (like in picorv32): makes shifts faster (but eats up around 60 luts)
    - (TODO: more detailed wiring explanations and details on
       femtosoc.pcf / femtosoc.lpf, with photos for each device)
    
On the ICEStick, do not activate everything simultaneously, it will not fit!
Start by activating what you need with the minimum amount of RAM (4K),
then add one thing at a time. Depending on YOSYS and NextPNR version,
it may use a different number of LUTs (and fit or not). Sometimes,
activating something uses a *smaller* number of LUTs (!), for instance,
if you activate the RESET button, you can have both the UART and TWO_STAGE_SHIFTER,
but without the RESET button you'll need to deactivate TWO_STAGE_SHIFTER to have
the UART (try it).

On the ICEStick, to wire the reset button, connect the pin (47 by default, can be changed in femtosoc.pcf)
to +3.3V through a 1KOhm resistor, and to GND through a push button.

3) FIRMWARE
   - asm RISC-V and C example programs are included in FIRMWARE/EXAMPLES and FIRMWARE/C_EXAMPLES
   - IMPORTANT: make sure you specify the quantity of RAM in FIRMWARE/LIB/crt0.s,
     it needs to match what was configured in femtosoc.v !
   - to compile a sample program:
        cd FIRMWARE
	./make_firmware.sh EXAMPLE/xxxxx.s   or ./make_firmware.sh C_EXAMPLE/xxxxx.c 
     This will generate FIRMWARE/firmware.hex using the RISC-V GNU
     toolchain and the bundled FIRMWARE/TOOLS/FIRMWARE_WORDS utility
     (that reorganizes hex file in words rather than bytes, as
      expected by $readmemh with my memory layout).
     You may need to edit the name of the RISC-V GNU tools in
     make_firmware.sh and LIB/makeit.sh depending on your installation. 
     I'm using the Linux Debian packages.
   - (TODO: include a Windows pre-compiled FIRMWARE_WORDS).

4) SYNTHESIS:
    use ./makeit_icestick.sh or ./makeit_ecp5_evn.sh depending on your board.
    This will also send the bitstream to the device.
    
5) UART:
    use ./start.sh to communicate with the board through a terminal.
    You can use any terminal emulator (at 115200 bauds).
    
