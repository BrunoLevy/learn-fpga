# Base address of memory-mapped IO,
# Loaded into gp at startup
.equ IO_BASE, 0x400000  

# IO-reg offsets. To read or write one of them,
# use IO_XXX(gp)
.equ IO_LEDS, 4
.equ IO_UART_DAT, 8
.equ IO_UART_CNTL, 16

.section .text
.globl putchar
.globl print20

putchar:
  sw a0, IO_UART_DAT(gp)
  li t0, 1<<9
.L0:  
  lw t1, IO_UART_CNTL(gp)
  and t1, t1, t0
  bnez t1, .L0
#  li t1, 1024
#.L1:
#  addi t1,t1,-1
#  bnez t1, .L1
  ret

