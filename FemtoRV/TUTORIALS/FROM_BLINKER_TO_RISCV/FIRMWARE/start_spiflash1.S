.equ IO_BASE, 0x400000  

.text
.global _start
.type _start, @function

_start:
.option push
.option norelax
     li  gp,IO_BASE
.option pop

     li   sp,0x1800

# zero-init bss section:
# clears from _sbss to _ebss
# _sbss and _ebss are defined by linker script (spiflash.ld)
     la a0, _sbss
     la a1, _ebss
     bge a0, a1, end_init_bss
loop_init_bss:
     sw zero, 0(a0)
     addi a0, a0, 4
     blt a0, a1, loop_init_bss
end_init_bss:

# copy data section from SPI Flash to BRAM:
# copies from _sidata (in flash) to _sdata ... _edata (in BRAM)
# _sidata, _sdata and _edata are defined by linker script (spiflash.ld)
     la a0, _sidata
     la a1, _sdata
     la a2, _edata
     bge a1, a2, end_init_data
loop_init_data:
     lw a3, 0(a0)
     sw a3, 0(a1)
     addi a0, a0, 4
     addi a1, a1, 4
     blt a1, a2, loop_init_data
end_init_data:

     call main
     ebreak
