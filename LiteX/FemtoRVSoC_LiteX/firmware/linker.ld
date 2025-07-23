ENTRY(_start)

MEMORY
{
  rom (rx) : ORIGIN = 0x00000000, LENGTH = 16K
  csr (rw) : ORIGIN = 0x82000000, LENGTH = 64K
}

SECTIONS {
  .text : {
    *(.text*)
    *(.rodata*)
  } > rom

  .data : {
    *(.data*)
    *(.sdata*)
  } > csr

  .bss : {
    *(.bss*)
    *(.sbss*)
    *(COMMON)
  } > csr

  .stack (COPY) : {
    . = ALIGN(8);
    _stack_start = .;
    . = . + 0x100;
    _stack_end = .;
  } > csr
}
