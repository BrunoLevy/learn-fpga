.include "femtorv32.inc"

.section .preinit, "ax"
.global _prestart
.type _prestart, @function

_prestart:
     la sp,FEMTOSOC_RAM  #   Read RAM size and initialize sp
     lw sp,0(sp)         # one position past the end of the RAM
     add s0, sp, zero
     j _start
     nop                 # We need 6x4 = 24 bits.
     nop

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

