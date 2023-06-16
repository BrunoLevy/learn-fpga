# Clock pin
set_property PACKAGE_PIN E3 [get_ports CLK]
set_property IOSTANDARD LVCMOS33 [get_ports CLK]

# LEDs
set_property PACKAGE_PIN H5  [get_ports LEDS[0]]
set_property PACKAGE_PIN J5  [get_ports LEDS[1]]
set_property PACKAGE_PIN T9  [get_ports LEDS[2]]
set_property PACKAGE_PIN T10 [get_ports LEDS[3]]
set_property IOSTANDARD LVCMOS33 [get_ports LEDS[0]]
set_property IOSTANDARD LVCMOS33 [get_ports LEDS[1]]
set_property IOSTANDARD LVCMOS33 [get_ports LEDS[2]]
set_property IOSTANDARD LVCMOS33 [get_ports LEDS[3]]

# Clock constraints
create_clock -period 10.0 [get_ports CLK]

# UART
set_property LOC D10 [get_ports TXD]
set_property LOC A9 [get_ports RXD]
set_property IOSTANDARD LVCMOS33 [get_ports RXD]
set_property IOSTANDARD LVCMOS33 [get_ports TXD]

# reset button
set_property LOC C2 [get_ports RESET]
set_property IOSTANDARD LVCMOS33 [get_ports RESET]

