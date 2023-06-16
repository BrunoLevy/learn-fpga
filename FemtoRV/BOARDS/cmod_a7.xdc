# Clock pin
set_property PACKAGE_PIN L17 [get_ports pclk]
set_property IOSTANDARD LVCMOS33 [get_ports pclk]

# LEDs
set_property PACKAGE_PIN A17  [get_ports D1]
set_property PACKAGE_PIN C16  [get_ports D2]
set_property PACKAGE_PIN B17  [get_ports D3]
set_property PACKAGE_PIN B16 [get_ports D4]
set_property IOSTANDARD LVCMOS33 [get_ports D1]
set_property IOSTANDARD LVCMOS33 [get_ports D2]
set_property IOSTANDARD LVCMOS33 [get_ports D3]
set_property IOSTANDARD LVCMOS33 [get_ports D4]

# Clock constraints
create_clock -period 83.33 [get_ports pclk]

# Pmod Header JA
#     oled screen
set_property PACKAGE_PIN G17   [get_ports  oled_RST   ]
set_property PACKAGE_PIN G19   [get_ports  oled_DC    ] 
set_property PACKAGE_PIN N18   [get_ports  oled_CS    ] 
set_property PACKAGE_PIN L18   [get_ports  oled_CLK   ] 
set_property PACKAGE_PIN H17   [get_ports  oled_DIN   ] 
set_property IOSTANDARD LVCMOS33 [get_ports  oled_RST   ] 
set_property IOSTANDARD LVCMOS33 [get_ports  oled_DC    ] 
set_property IOSTANDARD LVCMOS33 [get_ports  oled_CS    ] 
set_property IOSTANDARD LVCMOS33 [get_ports  oled_CLK   ] 
set_property IOSTANDARD LVCMOS33 [get_ports  oled_DIN   ] 
#     led matrix
#set_property PACKAGE_PIN B11   [get_ports  ledmtx_CLK ] 
#set_property PACKAGE_PIN A11   [get_ports  ledmtx_CS  ] 
#set_property PACKAGE_PIN D12   [get_ports  ledmtx_DIN ] 
#set_property IOSTANDARD LVCMOS33 [get_ports  ledmtx_CLK ] 
#set_property IOSTANDARD LVCMOS33 [get_ports  ledmtx_CS  ] 
#set_property IOSTANDARD LVCMOS33 [get_ports  ledmtx_DIN ] 



# UART
#set_property LOC D10 [get_ports TXD]
#set_property LOC A9 [get_ports RXD]
#set_property IOSTANDARD LVCMOS33 [get_ports RXD]
#set_property IOSTANDARD LVCMOS33 [get_ports TXD]

# reset button
set_property LOC A18 [get_ports RESET]
set_property IOSTANDARD LVCMOS33 [get_ports RESET]

# SPI flash
#set_property LOC L13 [get_ports spi_cs_n]
#set_property LOC K17 [get_ports spi_mosi]
#set_property LOC K18 [get_ports spi_miso]
#set_property LOC L16 [get_ports spi_clk]
#set_property IOSTANDARD LVCMOS33 [get_ports spi_cs_n]
#set_property IOSTANDARD LVCMOS33 [get_ports spi_mosi]
#set_property IOSTANDARD LVCMOS33 [get_ports spi_miso]
#set_property IOSTANDARD LVCMOS33 [get_ports spi_clk]
