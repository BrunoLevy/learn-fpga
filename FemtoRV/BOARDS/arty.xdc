# Clock pin
set_property PACKAGE_PIN E3 [get_ports {pclk}]
set_property IOSTANDARD LVCMOS33 [get_ports {pclk}]

# LEDs
set_property PACKAGE_PIN H5  [get_ports {D1}]
set_property PACKAGE_PIN J5  [get_ports {D2}]
set_property PACKAGE_PIN T9  [get_ports {D3}]
set_property PACKAGE_PIN T10 [get_ports {D4}]
set_property IOSTANDARD LVCMOS33 [get_ports {D1}]
set_property IOSTANDARD LVCMOS33 [get_ports {D2}]
set_property IOSTANDARD LVCMOS33 [get_ports {D3}]
set_property IOSTANDARD LVCMOS33 [get_ports {D4}]

# Clock constraints
create_clock -period 10.0 [get_ports {pclk}]

# Pmod Header JA
set_property -dict { PACKAGE_PIN G13   IOSTANDARD LVCMOS33 } [get_ports { oled_RST   }]; #IO_0_15 Sch=ja[1]
set_property -dict { PACKAGE_PIN B11   IOSTANDARD LVCMOS33 } [get_ports { ledmtx_CLK }]; #IO_L4P_T0_15 Sch=ja[2]
set_property -dict { PACKAGE_PIN A11   IOSTANDARD LVCMOS33 } [get_ports { ledmtx_CS  }]; #IO_L4N_T0_15 Sch=ja[3]
set_property -dict { PACKAGE_PIN D12   IOSTANDARD LVCMOS33 } [get_ports { ledmtx_DIN }]; #IO_L6P_T0_15 Sch=ja[4]
set_property -dict { PACKAGE_PIN D13   IOSTANDARD LVCMOS33 } [get_ports { oled_DC    }]; #IO_L6N_T0_VREF_15 Sch=ja[7]
set_property -dict { PACKAGE_PIN B18   IOSTANDARD LVCMOS33 } [get_ports { oled_CS    }]; #IO_L10P_T1_AD11P_15 Sch=ja[8]
set_property -dict { PACKAGE_PIN A18   IOSTANDARD LVCMOS33 } [get_ports { oled_CLK   }]; #IO_L10N_T1_AD11N_15 Sch=ja[9]
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { oled_DIN   }]; #IO_25_15 Sch=ja[10]

# UART
set_property LOC D10 [get_ports TXD]
set_property IOSTANDARD LVCMOS33 [get_ports TXD]
set_property LOC A9 [get_ports RXD]
set_property IOSTANDARD LVCMOS33 [get_ports RXD]

# reset button
set_property LOC C2 [get_ports RESET]
set_property IOSTANDARD LVCMOS33 [get_ports RESET]

# SPI flash
set_property LOC L13 [get_ports spi_cs_n]
set_property IOSTANDARD LVCMOS33 [get_ports spi_cs_n]
set_property LOC K17 [get_ports spi_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports spi_mosi]
set_property LOC K18 [get_ports spi_miso]
set_property IOSTANDARD LVCMOS33 [get_ports spi_miso]
set_property LOC L16 [get_ports spi_clk]
set_property IOSTANDARD LVCMOS33 [get_ports spi_clk]




