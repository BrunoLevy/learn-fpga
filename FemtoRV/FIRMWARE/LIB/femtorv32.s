.include "femtorv32.inc"

#################################################################################

# NanoRv support library

.global exit
.type  exit, @function
exit:
   .word 0  # make it crash...
   ret


# multiplication, source in a0 and a1, result in a0	
.global	__mulsi3
.type	__mulsi3, @function

.global	__muldi3
.type	__muldi3, @function

__mulsi3:	
__muldi3:
  mv     a2, a0
  li     a0, 0
.L1:
  andi   a3, a1, 1
  beqz   a3, .L2
  add    a0, a0, a2
.L2:
  srli   a1, a1, 1
  slli   a2, a2, 1
  bnez   a1, .L1
  ret
	
