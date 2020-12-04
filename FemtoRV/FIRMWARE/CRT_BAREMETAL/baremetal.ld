/*
 * linker control script,
 * Ensures that _start defined in LIB/crt0.S is put at address 0
 */
MEMORY
{
   BRAM (RWX) : ORIGIN = 0x0000, LENGTH = 0x40000
}
SECTIONS
{
    PROVIDE(__global_pointer$ = 0x400000);
    PROVIDE(_end = 0x0);
    PROVIDE(_edata = 0x0);
    .preinit : 
    {
        precrt0.o (.preinit)
    }
    .text :
    {
/*      crt0.o (.text) */
        *(.text)
    }
}
