LiteX hardware
--------------

This directory contains some experiments, extending the default LiteX SOC for ULX3S.


ESP32
-----
The ULX3S has an on-board ESP32 with a Wifi antenna, connected to the SDCard. It can be
used to directly send files on the SDCard using FTP through wifi (by executing a FTP
server on the ESP32 written in MicroPython). See [this link](https://github.com/emard/esp32ecp5)
for instructions on how to install Micropython on the ESP32 and configure Wifi.

The SDCard connector is shared between the ESP32 and the FPGA (ECP5). Only one of them can access
the SDCard at a time (the other one goes high impedance). To trigger the ESP32 on and off, I have
added a command to LiteOS (`esp32 <on|off>`). It works as follows:

- A pin of the FPGA (`F1`, called `wifi_en`) controls the ESP32. If it is low, then the ESP32 is inactive
(and goes high impedance), then the FPGA can access the SDCard. Then, it is very easy to create a LiteX
module that lets software control the pin through a CSR (Control and Status Register). Note: here we mean
a CSR that controls LiteX hardware (not to be confused with RiscV internal CSRs, this is a completely
different thing):

```
class ESP32(Module, AutoCSR):
    def __init__(self, platform):
       self._enable = CSRStorage()
       self.comb += platform.request("wifi_en").eq(self._enable.storage)
```

It inherits `Module` (hardware component for our SoC) and `AutoCSR` (manages memory mapping
and support libraries for CSRs automagically !).

The module is created by a new function of `BaseSoC`:

```
    def add_ESP32(self):
       self.esp32 = ESP32(self.platform)
       self.submodules.esp32 = self.esp32
```

The LiteX build system automatically creates functions to query, set, reset the new CSR.
Examining the file `build/radiona_ulx3s/software/include/generated/csr.h`, one can find
new functions to query and to set our new CSR:
```
static inline uint32_t esp32_enable_read(void) {
	return csr_read_simple(CSR_BASE + 0x1000L);
}
static inline void esp32_enable_write(uint32_t v) {
	csr_write_simple(v, CSR_BASE + 0x1000L);
}
```

Then we can activate the ESP32 by software, by calling `esp32_enable_write(1)`. But wait a minute,
if we do so, both the ESP32 and FPGA will be connected to the SDCard. We also need to set the FPGA
pins connected to the SDCard to high impedance. LiteX has an option to support high impedance on
the SDCard driver:
```
    soc.add_spi_sdcard(with_tristate=True)
```
This creates a `spisdcard_tristate` signal in the SOC, that puts the pins in high impedance state if
asserted. We need to connect it to the CSR, as follows:
```
    def add_ESP32(self):
       self.esp32 = ESP32(self.platform)
       self.submodules.esp32 = self.esp32
       self.comb += self.spisdcard_tristate.eq(self.esp32._enable.storage)    
```
(of course, if it is written like that, `add_spi_sdcard()` needs to be called before `add_ESP32()`).

Now we just need to add the following command to LiteOS:
```
#ifdef CSR_ESP32_BASE
static void esp32(int nb_args, char** args) {
   if (nb_args == 0) {
       printf("esp32 is %s\n", esp32_enable_read() ? "on" : "off");
       return;
   }
   if(!strcmp(args[0],"on")) {
       esp32_enable_write(1);
   } else if(!strcmp(args[0],"off")) {
       esp32_enable_write(0);
#ifdef CSR_SPISDCARD_BASE
       spisdcard_init();
#endif      
   } else {
       printf("esp32 on|off");
   }
}
define_command(esp32, esp32, "turn ESP32 on/off", 0);
#endif
```
notes:
- in addition to generating the `xxx_write()`,`xxx_read()` functions, LiteX also generates
  a `CSR_XXX_BASE` macro that lets conditionally compile code depending on whether a CSR was generated
  in the hardware.
- the SDCard needs to be re-initialized when ESP32 is switched off (because the ESP32 may have left it in
  a state that is not expected by LiteX BIOS).

Blitter
-------
LiteX has a nice integrated frame buffer, that can display 640x480x24bpp. It uses the LiteDRAM SDRAM controller
and its interface to easily create DMA devices. To set pixels, one directly writes data in the SDRAM (the framebuffer
is mapped at address `0x40c00000`). For instance, the following loop clears the screen:
```
   uint32_t* p = (uint32_t*)0x40x00000;
   for(int i=0; i<640*480; ++i) {
      p[i] = 0;
   }
```

If you have a sophisticated core, like VexRiscV, that has pipelining
and branch prediction, this will not take much more than a couple of
cycles per pixel, but it is another story if you use one a minimalistic
core (such as mine), or even smaller one (like SERV). Then the idea is
to add a small device, that will set pixels for you at maximal speed
(up to two pixels per cycle, since SDRAM can operate at up to 2x
CPU frequency in LiteX). I was completely amazed to see how easy it is
to design such a device in LiteX: there is a `LiteDRAMDMAWriter` that
can do that for you. The `LiteDRAMDMAWriter` can be configured through CSRs:

| CSR      | dir   | description                           |
|----------|-------|---------------------------------------|
| `base`   | (in)  | first address                         |
| `length` | (in)  | number of 32 bit words to write       |
| `enable` | (in)  | guess what !                          |
| `done`   | (out) | goes to 1 when DMA write is completed |
| `loop`   | (in)  | set it to 1 to loop forever           |
| `offset` | (out) | index of current item being written   |

It takes its value through a `sink`, with the following fields:

| field     | dir   | description                                       |
|-----------|-------|---------------------------------------------------|
| `address` | (out) | address currently written                         |
| `data`    | (in)  | data to be written at the address                 |
| `valid`   | (in)  | data is valid, ready to be written                |
| `ready`   | (out) | data was written, we are ready for the next value |

Knowing that, our job is easy: we will create a new `value` CSR, that will store
the 32-bits value to be written. Then we condigure a `LiteDRAMDMAWriter`.
Its `sink.data` will be connected to the `value` CSR, and the flag `sink.valid` is
set to the constant 1. Then our (very crude for now) blitter is not longer than
8 lines of Python !

```
class Blitter(Module, AutoCSR):
    def __init__(self,port): # for instance, port = soc.sdram.crossbar.get_port()
        self._value = CSRStorage(32)
        from litedram.frontend.dma import LiteDRAMDMAWriter
        dma_writer = LiteDRAMDMAWriter(port=port,with_csr=True)
        self.submodules.dma_writer = dma_writer
        self.comb += dma_writer.sink.data.eq(self._value.storage)
        self.comb += dma_writer.sink.valid.eq(1)
```

From the software side, our blitter can be used like that (here to clear the screen,
that is, clearing `FB_WIDTH*FB_HEIGHT` 32-bit words starting from address `fb_base`):
```
void fb_clear(void) {
#ifdef CSR_BLITTER_BASE
    blitter_value_write(0x000000);                         // value to be written in each pixel
    blitter_dma_writer_base_write((uint32_t)(fb_base));    // first address
    blitter_dma_writer_length_write(FB_WIDTH*FB_HEIGHT*4); // number of bytes to be written
    blitter_dma_writer_enable_write(1);                    // start DMA transfer
    while(!blitter_dma_writer_done_read());                // wait for DMA transfer completion
    blitter_dma_writer_enable_write(0);                     
#else
    memset((void*)fb_base, 0, FB_WIDTH*FB_HEIGHT*4);
#endif    
}
```
(and we still keep the conditional compile steered by `CSR_BLITTER_BASE` with equivalent
non-hw-optimized code so that our software reminds compatible with standard LiteX configurations).

Coming next
-----------
  - block image transfer (copy pixels)
  - GPU with scanline hw acceleration
     - Gouraud-shading
     - texture mapping
