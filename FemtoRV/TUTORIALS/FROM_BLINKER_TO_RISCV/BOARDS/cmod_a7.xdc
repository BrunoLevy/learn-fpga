# Clock pin
set_property PACKAGE_PIN L17 [get_ports CLK]
set_property IOSTANDARD LVCMOS33 [get_ports CLK]

# LEDs
set_property PACKAGE_PIN A17 [get_ports LEDS[0]]
set_property PACKAGE_PIN C16 [get_ports LEDS[1]]
set_property PACKAGE_PIN B17 [get_ports LEDS[2]]
set_property PACKAGE_PIN B16 [get_ports LEDS[3]]
set_property PACKAGE_PIN C17 [get_ports LEDS[4]]
set_property IOSTANDARD LVCMOS33 [get_ports LEDS[0]]
set_property IOSTANDARD LVCMOS33 [get_ports LEDS[1]]
set_property IOSTANDARD LVCMOS33 [get_ports LEDS[2]]
set_property IOSTANDARD LVCMOS33 [get_ports LEDS[3]]
set_property IOSTANDARD LVCMOS33 [get_ports LEDS[4]]

# Clock constraints
create_clock -period 83.33 [get_ports CLK]

# UART
set_property LOC G17 [get_ports TXD]
set_property LOC G19 [get_ports RXD]
set_property IOSTANDARD LVCMOS33 [get_ports RXD]
set_property IOSTANDARD LVCMOS33 [get_ports TXD]

# reset button
set_property LOC A18 [get_ports RESET]
set_property IOSTANDARD LVCMOS33 [get_ports RESET]

