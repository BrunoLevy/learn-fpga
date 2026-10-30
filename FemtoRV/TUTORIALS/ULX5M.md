ULX5M Tutorial
==============

This tutorial is WIP
- [x] dirtyJtag on Rpi pico
- [x] connect pico to JTAG pins on carrier board
- [x] install GateMate toolchain
- [x] first blinky
- [ ] FemtoRV
- [ ] add a tty (through a FTDI rs232-USB adapter)

Material
--------
- a ULX5M of course
- a carrier board for ULX5M (any carrier board for Raspberry CM5 will do)
- a raspberry pico (to be configured as a JTAG programmer using DirtyJTAG), chose one with pre-soldered headers (if you are lazy like me!)
- five female-female Dupont wires

DirtyJTag
---------

```
sudo apt install cmake python3 build-essential gcc-arm-none-eabi libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib
git clone --recurse-submodules https://github.com/raspberrypi/pico-sdk
git clone https://github.com/phdussud/pico-dirtyJtag.git
cd pico-dirtyJtag
export PICO_SDK_PATH=xxx/yyy/pico-sdk
```
edit CMakeLists.txt:
 - uncomment line with PICO_SDK_PATH
 - if you have a rpi 2350, change line set(PICO_BOARD pico2)

```
mkdir build
cd build
cmake ../ -DPICO_BOARD=pico2
cmake ../ -DPICO_BOARD=pico2
```
If everything goes well, this will generate:
- dirtyJtag.uf2
- _deps/picotool/picotool

Now program the pico (can be done also with picotool but it seems that my picotool is not compiled with USB support):
- plug the pico, a new drive will appear. If not the case, unplug it, press bootsel, plug it while keeping bootsel pressed, release bootsel
- drag-drop dirtyJtag.uf2 to the drive

The pico should reboot. To see whether it works:

```
lsusb | grep c0ca
```

Now test whether openFPGALoader can detect it:
```
openFPGALoader -c dirtyJtag --detect
```
(it will detect the dirtyJtag on the RPi then complain there is nothing on the other side).

Connect pico to carrier board
-----------------------------

You will need 5 female-female Dupont wires, to connect TDI, TDO, TCK, TMS and GND.

- [ULX5M pins](https://github.com/intergalaktik/ulx4m-documentation/tree/main/ulx4m-ld#pinout) (same as ULX4M)
- dirtyJtag pins: check dirtyJtagConfig.h

My setup:

![](Images/ULX5M_RPI.png)

(mind the order of the pins! TDI,GND,TDO,TCK,TMS on one side, TDI,TDO,GND,TCK,TMS on the other side, GND and TDO are swapped !!)


Plug both the RPi and the carrier board on USB ports.
Now test whether openFPGALoader can detect the FPGA:
```
openFPGALoader -c dirtyJtag --detect
```

It should detect the CologneChip GateMate FPGA now.


Install CologneChip GateMate toolchain
--------------------------------------

- get the archive [here](https://github.com/YosysHQ/oss-cad-suite-build/releases/) that corresponds to your OS
- unpack it (for instance in $HOME/CologneChip/oss-cad-suite)


First blinky
------------

Blinky source: `blinky.v`
```
module blinky (
    input  wire clk,
    output wire[7:0] led
);

    reg [27:0] counter = 0;
    always @(posedge clk) begin
        counter <= counter + 1;
    end
    assign led = counter[27:20];

endmodule
```

Constraints file: `blinky.ccf`
```
Pin_in  "clk" Loc="IO_SB_A8";
Pin_out "led[0]" Loc="IO_SB_A0";
Pin_out "led[1]" Loc="IO_SB_B0";
Pin_out "led[2]" Loc="IO_SB_A1";
Pin_out "led[3]" Loc="IO_SB_B1";
Pin_out "led[4]" Loc="IO_SB_B2";
Pin_out "led[5]" Loc="IO_SB_A2";
Pin_out "led[6]" Loc="IO_SB_B3";
Pin_out "led[7]" Loc="IO_SB_A3";
```

Where to find the information:
- [link1](https://github.com/pu-cc/tinydfu-bootloader/blob/master/boards/ulx5m/ulx5m.ccf)
- [link2](https://github.com/YosysHQ/prjpeppercorn-test-cases/tree/ulx5m)

Synthesize:
```
yosys -p "read_verilog blinky.v; synth_gatemate -top blinky -luttree -nomx8; write_json blinky.json"
```

Place and route:
```
$TOOLS/nextpnr-himbaechel --device CCGM1A1 --json blinky.json \
    --vopt ccf=blinky.ccf --vopt out=blinky.txt --router router2
```

Pack bistream
```
gmpack --reset blinky.txt blinky.bit
```

Load (volatile, lost on power cycle)
```
openFPGALoader -r -c dirtyJtag blinky.bit
```

... Writing to SPI flash is supposed to be (but did not work for me, maybe switches need to be configured)
```
openFPGALoader -r -c dirtyJtag -f blinky.bit
```


Notes, links
------------

- [GateMate A1 documentation](https://colognechip.com/programmable-logic/gatemate/?gad_source=1&gad_campaignid=21400780723&gclid=CjwKCAjwgJHXBhBGEiwAHohJq7Hxv7C5G4sIMu_CT4O8WPEIEyhWe3f2_8iCeonPacCD_2wlHulpAhoCKI0QAvD_BwE#tab-313422)


USB <-> DirtyJTAG:
- https://deepbluembedded.com/openfpgaloader-dirtyjtag-pi-pico-jtag-tutorial-windows/


https://github.com/phdussud/pico-dirtyJtag


1. Install [CologneChip's version of Yosys and NextPNR](https://github.com/YosysHQ/oss-cad-suite-build/releases/).
