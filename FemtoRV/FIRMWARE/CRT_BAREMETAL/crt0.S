.include "femtorv32.inc"

.text
#.section .init, "ax"
.global _start
.type _start, @function

_start:
.option push
.option norelax
     li gp,IO_BASE       #   Base address of memory-mapped IO
.option pop
	
#     la sp,FEMTOSOC_RAM    #   Read RAM size and initialize sp
#     lw sp,0(sp)           # one position past the end of the RAM

     lw sp,IO_RAM(gp)      # Read RAM size in hw config register and
     nop	           #   initialize SP one position past end of RAM
     nop            	   # Do not change size of program !
     call main
     tail exit

# Place holder for configuration word,
# extracted from femtosoc.v by firmware_words
# (in FIRMWARE/TOOLS/FIRMWARE_WORDS/) and
# implanted there when generating firmware.hex	
# Need to start at address 0x0024 (specified in femtosoc.v)

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

