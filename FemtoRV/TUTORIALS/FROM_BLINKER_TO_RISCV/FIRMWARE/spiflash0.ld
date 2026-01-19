#include "link_memory_info.h"

MEMORY {
   FLASH (RX)  : ORIGIN = VIRT_FLASH_MEM_START, LENGTH = VIRT_FLASH_MEM_LEN
}
SECTIONS {
    everything : {
	. = ALIGN(4);
	start.o (.text)
        *(.*)
    } >FLASH
}
