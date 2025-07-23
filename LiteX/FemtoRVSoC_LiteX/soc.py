#!/usr/bin/env python3

from migen import *
from litex.gen import *

from platforms import vsd_mini_fpga
from litex.soc.integration.soc_core import SoCMini
from litex.soc.integration.builder import Builder
from litex.soc.cores.gpio import GPIOOut
from litex.soc.cores.timer import Timer

# Clock Reset Generator
class CRG(Module):
    def __init__(self, clk):
        self.clock_domains.cd_sys = ClockDomain()
        self.comb += self.cd_sys.clk.eq(clk)

# Minimal SoC with FemtoRV32, UART, Timer, and LEDs
class MinimalSoC(SoCMini):
    def __init__(self):
        platform = vsd_mini_fpga.Platform()
        clk_freq = int(12e6)

        clk = platform.request("clk12")
        platform.add_period_constraint(clk, 1e9 / clk_freq)
        self.submodules.crg = CRG(clk)

        SoCMini.__init__(self, platform, clk_freq,
            cpu_type="femtorv",
            cpu_variant="quark",
            cpu_reset_address=0x00000000,
            integrated_rom_init="firmware/firmware.hex",  #  load your hex here
            integrated_rom_size=0x4000,  # 16 KB ROM
            integrated_main_ram_size=0x2000  # 8 KB RAM
        )

        # UART
        self.add_uart(name="serial")

        # GPIO LEDs
        led_pads = [
            platform.request("led_red"),
            platform.request("led_green"),
            platform.request("led_blue")
        ]
        self.submodules.leds = GPIOOut(Cat(*led_pads))
        self.add_csr("leds")

        # Timer
        self.submodules.timer0 = Timer()
        self.add_csr("timer0")

# Build
def main():
    soc = MinimalSoC()
    builder = Builder(soc, output_dir="build", csr_csv="build/csr.csv", compile_software=False)
    builder.build(run=True)

if __name__ == "__main__":
    main()
