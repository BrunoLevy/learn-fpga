#!/usr/bin/env python3

# Extended Radiona ULX3S support
# Bruno Levy, January 2022
#
# - ESP32 control and three-state SPI-SDCard
# - Blitter


import os
import argparse
import sys

from migen import *

from litex.build.generic_platform import *
from litex.build.lattice import LatticePlatform
from litex_boards.platforms import ulx3s as ulx3s_platform
from litex_boards.targets   import ulx3s

#--------------------------------------------------------------------------------------------------------

# Add wifi_en pin to ULX3S platform (to activate / deactivate ESP32)
# Quick-and-dirty hack: replace Platform constructor and add the missing pin

def new_platform_init(self, device="LFE5U-45F", revision="2.0", toolchain="trellis", **kwargs):
        assert device in ["LFE5U-12F", "LFE5U-25F", "LFE5U-45F", "LFE5U-85F"]
        assert revision in ["1.7", "2.0"]
        _io = ulx3s_platform._io_common + \
              {"1.7": ulx3s_platform._io_1_7, "2.0": ulx3s_platform._io_2_0}[revision] + \
              [("wifi_en", 0, Pins("F1"), IOStandard("LVCMOS33"), Misc("PULLMODE=UP"), Misc("DRIVE=4"))]
        LatticePlatform.__init__(self, device + "-6BG381C", _io, toolchain=toolchain, **kwargs)
    
ulx3s_platform.Platform.__init__ = new_platform_init

#--------------------------------------------------------------------------------------------------------

# We need to change fifo depth in video framebuffer (a multiple of 640*4, else display is shifted)
# To do that, replace VideoFrameBuffer constructor (just change default value for fifo_depth)

from litex.soc.cores.video import VideoFrameBuffer

old_videoframebuffer_init = VideoFrameBuffer.__init__

def new_videoframebuffer_init( \
      self, dram_port, hres=800, vres=600, base=0x00000000, \
      fifo_depth=25600, clock_domain="sys", clock_faster_than_sys=False, format="rgb888"):
     old_videoframebuffer_init( \
          self, dram_port, hres, vres, base, fifo_depth, \
          clock_domain, clock_faster_than_sys, format \
     )

VideoFrameBuffer.__init__ = new_videoframebuffer_init

#--------------------------------------------------------------------------------------------------------

from litex.build.lattice.trellis import trellis_args, trellis_argdict
from litex.soc.cores.clock import *
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *
from litex.soc.interconnect.csr import *

# ESP32 module, with CSR that controls wifi_en pin ------------------------------------------------------

class ESP32(Module, AutoCSR):
    def __init__(self, platform):
       self._enable = CSRStorage()
       self.comb += platform.request("wifi_en").eq(self._enable.storage)

# Blitter -----------------------------------------------------------------------------------------------
# For now, it just has fast memory fill

class Blitter(Module, AutoCSR):
    def __init__(self,port): # port = self.sdram.crossbar.get_port()
        self._value = CSRStorage(32)
        from litedram.frontend.dma import LiteDRAMDMAWriter
        dma_writer = LiteDRAMDMAWriter(port=port,fifo_depth=16,fifo_buffered=False,with_csr=True)
        self.submodules.dma_writer = dma_writer
        self.comb += dma_writer.sink.data.eq(self._value.storage)
        self.comb += dma_writer.sink.valid.eq(1)

# BaseSoC -----------------------------------------------------------------------------------------------

class BaseSoC(ulx3s.BaseSoC):
    def __init__(self, device="LFE5U-45F", revision="2.0", toolchain="trellis",
        sys_clk_freq=int(50e6), sdram_module_cls="MT48LC16M16", sdram_rate="1:1",
        with_led_chaser=True, with_video_terminal=False, with_video_framebuffer=False,
        with_spi_flash=False, **kwargs):

        ulx3s.BaseSoC.__init__(
            self, device, revision, toolchain, sys_clk_freq, sdram_module_cls, sdram_rate,
            with_led_chaser, with_video_terminal, with_video_framebuffer, with_spi_flash,
            **kwargs)

    def add_blitter(self):        
        self.blitter = Blitter(port=self.sdram.crossbar.get_port())
        self.submodules.blitter = self.blitter
            
    def add_ESP32(self):
       self.esp32 = ESP32(self.platform)
       self.submodules.esp32 = self.esp32
       if hasattr(self,'spisdcard_tristate'):
           self.comb += self.spisdcard_tristate.eq(self.esp32._enable.storage)    
            
# Build -------------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="LiteX SoC on ULX3S")
    parser.add_argument("--build",           action="store_true",   help="Build bitstream.")
    parser.add_argument("--load",            action="store_true",   help="Load bitstream.")
    parser.add_argument("--toolchain",       default="trellis",     help="FPGA toolchain (trellis or diamond).")
    parser.add_argument("--device",          default="LFE5U-45F",   help="FPGA device (LFE5U-12F, LFE5U-25F, LFE5U-45F or LFE5U-85F).")
    parser.add_argument("--revision",        default="2.0",         help="Board revision (2.0 or 1.7).")
    parser.add_argument("--sys-clk-freq",    default=50e6,          help="System clock frequency.")
    parser.add_argument("--sdram-module",    default="MT48LC16M16", help="SDRAM module (MT48LC16M16, AS4C32M16 or AS4C16M16).")
    parser.add_argument("--with-spi-flash",  action="store_true",   help="Enable SPI Flash (MMAPed).")
    parser.add_argument("--with-oled",       action="store_true",   help="Enable SDD1331 OLED support.")
    parser.add_argument("--sdram-rate",      default="1:2",         help="SDRAM Rate (1:1 Full Rate or 1:2 Half Rate).")
    builder_args(parser)
    soc_core_args(parser)
    trellis_args(parser)
    args = parser.parse_args()

    # AS4C32M16 not supported (refresh timings will not be met with framebuffer DMA active), 
    # use AS4C16M16 instead
    assert args.sdram_module != 'AS4C32M16'
    
    soc = BaseSoC(
        device                 = args.device,
        revision               = args.revision,
        toolchain              = args.toolchain,
        sys_clk_freq           = int(float(args.sys_clk_freq)),
        sdram_module_cls       = args.sdram_module,
        sdram_rate             = args.sdram_rate,
        with_video_terminal    = False,
        with_video_framebuffer = True,
        with_spi_flash         = args.with_spi_flash,
        **soc_core_argdict(args))

    soc.add_spi_sdcard(with_tristate=True)
    if args.with_oled:
        soc.add_oled()

    # add my own modules
    soc.add_blitter() # provides fast memory fill
    soc.add_ESP32()   # esp32 on/off + spisdcard tristate control (access SDCard with ftp through wifi !)
    
    builder = Builder(soc, **builder_argdict(args))
    builder_kargs = trellis_argdict(args) if args.toolchain == "trellis" else {}
    builder.build(**builder_kargs, run=args.build)

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(os.path.join(builder.gateware_dir, soc.build_name + ".svf"))

if __name__ == "__main__":
    main()
