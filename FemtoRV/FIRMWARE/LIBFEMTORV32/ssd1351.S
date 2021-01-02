.include "femtorv32.inc"

###############################################################################
# NanoRv OLED display support
###############################################################################

# Macros to send commands to the OLED driver (wrappers around OLEDx functions)
	
.macro OLED0 cmd
	li a0,\cmd
	call oled0
.endm

.macro OLED1 cmd,arg1
	li a0,\cmd
	li a1,\arg1
	call oled1
.endm

.macro OLED2 cmd,arg1,arg2
	li a0,\cmd
	li a1,\arg1
	li a2,\arg2
	call oled2
.endm

.macro OLED3 cmd,arg1,arg2,arg3
	li a0,\cmd
	li a1,\arg1
	li a2,\arg2
	li a3,\arg3	
	call oled3
.endm

################################################################################
	
# initialize oled display
.global	GL_init
.type	GL_init, @function
GL_init:
	add sp,sp,-4
        sw ra, 0(sp)	
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
	# Note: takes a lot of space, could be stored in an array of bytes
	# if ROM space gets crowded
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
	lw ra, 0(sp)
	add sp,sp,4
	ret

# Oled window a0=x1 a1=y1 a2=x1 a3=y2
.global	oled_write_window
.type	oled_write_window, @function
oled_write_window:
	add sp,sp,-4
        sw ra, 0(sp)
	mv t0, a0
	mv t1, a2
	mv t2, a1
	mv t3, a3
	li a0, 0x15
	mv a1, t0
	mv a2, t1
	call oled2
	li a0, 0x75
	mv a1, t2
	mv a2, t3
	call oled2
	li a0, 0x5c
	call oled0
	lw ra, 0(sp)
	add sp,sp,4
	ret
	
# Oled display command, 0 argument, command in a0
.global	oled0
.type	oled0, @function
oled0:	add sp,sp,-4
        sw ra, 0(sp)
	sw a0, IO_SSD1351_CMD(gp)
	lw ra, 0(sp)
	add sp,sp,4
	ret

# Oled display command, 1 argument, command in a0, arg in a1	
.global	oled1
.type	oled1, @function
oled1:	add sp,sp,-4
        sw ra, 0(sp)
	sw a0, IO_SSD1351_CMD(gp)
	sw a1, IO_SSD1351_DAT(gp)
	lw ra, 0(sp)
	add sp,sp,4
	ret

# Oled display command, 2 arguments, command in a0, args in a1,a2
.global	oled2
.type	oled2, @function
oled2:	add sp,sp,-4
        sw ra, 0(sp)
	sw a0, IO_SSD1351_CMD(gp)
	sw a1, IO_SSD1351_DAT(gp)
	sw a2, IO_SSD1351_DAT(gp)
	lw ra, 0(sp)	
        add sp,sp,4
	ret

# Oled display command, 3 arguments, command in a0, args in a1,a2,a3
.global	oled3
.type	oled3, @function
oled3:	add sp,sp,-4
        sw ra, 0(sp)
	sw a0, IO_SSD1351_CMD(gp)
	sw a1, IO_SSD1351_DAT(gp)
	sw a2, IO_SSD1351_DAT(gp)
	sw a3, IO_SSD1351_DAT(gp)
	lw ra, 0(sp)
	add sp,sp,4
	ret

