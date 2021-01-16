
MEMORY
{
   rom(RX)   : ORIGIN = 0x00800000, LENGTH = 0x400000
   ram(RWX)  : ORIGIN = 0x00000000, LENGTH = 0x400000
}

SECTIONS
{
  .text   : {
      crt0.o (.text) 
      *(.text*)    
   } > rom
  .rodata  : { *(.rodata*)   } > rom   
  .srodata : { *(.srodata*)  } > rom  
  .data    : { *(.data*)     } > rom  
  .sdata   : { *(.sdata*)    } > rom
  .sbss    : { *(.sbss*)     } > ram    
  .bss     : { *(.bss*)      } > ram  
}

/*
 * We got a problem with sdata: needs to be initialized (in rom) and
 * needs to be writable (in ram) at the same time. For now put it in 
 * rom, else init data and memory map makes executable image span the
 * complete address space...
 */