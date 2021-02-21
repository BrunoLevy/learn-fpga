.include "femtorv32.inc"
.include "ssd1351_1331.inc"
	
################################################################################
	
# initialize oled display
.global	oled_init
.type	oled_init, @function
oled_init:
	add sp,sp,-4
        sw ra, 0(sp)

.ifdef SSD1351	
	# Initialization sequence / RESET
	li a0,5
	sw a0,IO_LEDS(gp)
        li a0,1                      # reset low during 0.25 s
	sw a0,IO_SSD1351_CNTL(gp)
	li a0,250
	call milliwait
	li a0,10
	sw a0,IO_LEDS(gp)
        li a0,3                      # reset high during 0.25 s
	sw a0,IO_SSD1351_CNTL(gp)
	li a0,250
	call milliwait
	li a0,15
	sw a0,IO_LEDS(gp)
        li a0,0                      # normal operation
	sw a0,4(gp)
	# Initialization sequence / configuration
	OLED1 0xfd, 0x12             # unlock driver
	OLED1 0xfd, 0xb1             # unlock commands
	OLED0 0xae                   # display off
	OLED0 0xa4                   # display mode off
	OLED2 0x15,0x00,0x7f         # column address
	OLED2 0x75,0x00,0x7f         # row address
	OLED1 0xb3,0xf1              # front clock divider (see section 8.5 of manual)
	OLED1 0xca, 0x7f             # multiplex
	OLED1 0xa0, 0x74             # remap, data format, increment
	OLED1 0xa1, 0x00             # display start line
	OLED1 0xa2, 0x00             # display offset
	OLED1 0xab, 0x01             # VDD regulator ON
	OLED3 0xb4, 0xa0, 0xb5, 0x55 # segment voltage ref pins
	OLED3 0xc1, 0xc8, 0x80, 0xc0 # contrast current for colors A,B,C
	OLED1 0xc7, 0x0f             # master contrast current
	OLED1 0xb1, 0x32             # length of segments 1 and 2 waveforms
	OLED3 0xb2, 0xa4, 0x00, 0x00 # display enhancement
	OLED1 0xbb, 0x17             # first pre-charge voltage phase 2
	OLED1 0xb6, 0x01             # second pre-charge period (see table 9-1 of manual)
	OLED1 0xbe, 0x05             # Vcomh voltage
	OLED0 0xa6                   # display on
	OLED0 0xaf                   # display mode on
.endif

.ifdef SSD1331
	OLED0 0xae       # display off
	OLED1 0x81, 0x91 # contrast A
	OLED1 0x82, 0x50 # contrast B
	OLED1 0x83, 0x7d # contrast C
	OLED1 0x87, 0x06 # master current control
	OLED1 0x8a, 0x64 # prechargeA
	OLED1 0x8b, 0x78 # prechargeB
	OLED1 0x8c, 0x64 # prechargeC
	OLED1 0xa0, 0x60 # RGB mode and remap
	OLED1 0xa1, 0x00 # startline
	OLED1 0xa2, 0x00 # display offset
	OLED0 0xa4       # normal display	
	OLED1 0xa8, 0x3f # set multiplex
	OLED1 0xad, 0x8e # set master
	OLED1 0xb0, 0x00 # powersave mode 
        OLED1 0xb1, 0x31 # phase period adjustment
	OLED1 0xb3, 0xf0 # clock div
	OLED1 0xbb, 0x3a # prechargelevel
	OLED1 0xbe, 0x3e # vcomh
	OLED0 0x2e       # disable scrolling
	OLED0 0xaf       # display on
.endif
	lw ra, 0(sp)
	add sp,sp,4
	ret

##############################################################
