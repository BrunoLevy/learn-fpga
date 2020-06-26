.include "femtorv32.inc"

.text
.global _start
.type _start, @function

_start:
     li gp,IO_BASE       # base address of memory-mapped IO
     la sp,FEMTOSOC_RAM  
     lw sp,0(sp)
     call main
     tail exit

# Place holder for configuration word,
# extracted from femtosoc.v by firmware_words
# (in FIRMWARE/TOOLS/FIRMWARE_WORDS/) and
# implanted there when generating firmware.hex	
	
.global FEMTORV32_PROC_CONFIG
.global FEMTORV32_FREQ
.global FEMTOSOC_RAM
.global FEMTOSOC_DEVICES	
	
FEMTORV32_PROC_CONFIG: .word 0x00000000
FEMTORV32_FREQ:        .word 0x00000000
FEMTOSOC_RAM:          .word 0x00000000
FEMTOSOC_DEVICES:      .word 0x00000000	

.global CONFIGWORDS
CONFIGWORDS: .word FEMTORV32_PROC_CONFIG	
