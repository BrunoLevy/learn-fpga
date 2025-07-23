from litex.build.generic_platform import *
from litex.build.lattice.platform import LatticePlatform
from litex.build.lattice.programmer import IceStormProgrammer

_io = [
    ("clk12", 0, Pins("20"), IOStandard("LVCMOS33")),

    ("serial", 0,
        Subsignal("tx", Pins("14")),
        Subsignal("rx", Pins("15")),
        IOStandard("LVCMOS33")
    ),

    ("led_red",   0, Pins("39"), IOStandard("LVCMOS33")),
    ("led_green", 0, Pins("40"), IOStandard("LVCMOS33")),
    ("led_blue",  0, Pins("41"), IOStandard("LVCMOS33")),
]

class Platform(LatticePlatform):
    default_clk_name   = "clk12"
    default_clk_period = 1e9 / 12e6

    # ✅ Class variables for LiteX parser
    device    = "ice40-up5k-sg48"
    toolchain = "icestorm"

    @classmethod
    def toolchains(cls, device):
        return ["icestorm"]  # ✅ THIS LINE FIXES EVERYTHING

    def __init__(self):
        super().__init__(self.device, _io, toolchain=self.toolchain)

    def create_programmer(self):
        return IceStormProgrammer()
