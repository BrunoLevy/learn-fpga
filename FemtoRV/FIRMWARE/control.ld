/*
 * linker control script,
 * Ensures that _start defined in LIB/crt0.S is put at address 0
 */
MEMORY
{
   BRAM (RWX) : ORIGIN = 0x0000, LENGTH = 0x1000
}
SECTIONS
{
    .text :
    {
        crt0.o (.text) 
        *(.text)
    }
}