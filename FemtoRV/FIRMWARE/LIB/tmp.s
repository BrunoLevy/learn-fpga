# Clear oled display
.global	oled_clear
.type	oled_clear, @function
oled_clear:
	add sp,sp,-4
        sw ra, 0(sp)	
        OLED2 0x15,0x00,0x7f         # column address
	OLED2 0x75,0x00,0x7f         # row address
	OLED0 0x5c                   # write RAM
	li t0,0
	li s11,128
	li s1,0
cloop_y:li s0,0
cloop_x:sw t0,IO_OLED_DATA(gp)
	call oled_wait 
	sw t0,IO_OLED_DATA(gp)
	call oled_wait 
	add s0,s0,1
	bne s0,s11,cloop_x
	add s1,s1,1
	bne s1,s11,cloop_y
	lw ra, 0(sp)
	add sp,sp,4
	ret

