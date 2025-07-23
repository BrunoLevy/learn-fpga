.include "femtorv32.inc"
.include "ssd1351_1331.inc"
	
##############################################################

# Oled window a0=x1 a1=y1 a2=x2 a3=y2
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
.ifdef SSD1351	
	li a0, 0x5c
	call oled0
.endif	
	lw ra, 0(sp)
	add sp,sp,4
	ret
	
#############################################################
	
# Oled display command, 0 argument, command in a0
.global	oled0
.type	oled0, @function
oled0:	add sp,sp,-4
        sw ra, 0(sp)
	sw a0, IO_SSD1351_CMD(gp)
	lw ra, 0(sp)
	add sp,sp,4
	ret

#################### Commands for SSD1351 #########################
	
.ifndef SSD1331

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
.endif

#################### Commands for SSD1331 #########################

.ifdef SSD1331

# Note: unlike SSD1351, command args are sent to CMD, not DAT !
	
# Oled display command, 1 argument, command in a0, arg in a1	
.global	oled1
.type	oled1, @function
oled1:	add sp,sp,-4
        sw ra, 0(sp)
	sw a0, IO_SSD1351_CMD(gp)
	sw a1, IO_SSD1351_CMD(gp) 
	lw ra, 0(sp)
	add sp,sp,4
	ret

# Oled display command, 2 arguments, command in a0, args in a1,a2
.global	oled2
.type	oled2, @function
oled2:	add sp,sp,-4
        sw ra, 0(sp)
	sw a0, IO_SSD1351_CMD(gp)
	sw a1, IO_SSD1351_CMD(gp)
	sw a2, IO_SSD1351_CMD(gp)
	lw ra, 0(sp)	
        add sp,sp,4
	ret

# Oled display command, 3 arguments, command in a0, args in a1,a2,a3
.global	oled3
.type	oled3, @function
oled3:	add sp,sp,-4
        sw ra, 0(sp)
	sw a0, IO_SSD1351_CMD(gp)
	sw a1, IO_SSD1351_CMD(gp)
	sw a2, IO_SSD1351_CMD(gp)
	sw a3, IO_SSD1351_CMD(gp)
	lw ra, 0(sp)
	add sp,sp,4
	ret
.endif
	
