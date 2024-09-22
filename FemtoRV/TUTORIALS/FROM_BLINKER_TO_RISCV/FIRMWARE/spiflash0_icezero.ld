MEMORY {
   FLASH (RX)  : ORIGIN = 0x00830000, LENGTH = 0x100000  - 0x30000 /* 4 MB in flash */
}
SECTIONS {
    everything : {
	. = ALIGN(4);
	start.o (.text)
        *(.*)
    } >FLASH
}
