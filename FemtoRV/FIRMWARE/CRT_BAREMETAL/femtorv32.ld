/*
 * linker control script for 'bare metal' executables.
 * Ensures that _start defined in LIB/crt0.S is put at address 0
 */
MEMORY
{
   BRAM (RWX) : ORIGIN = 0x0000, LENGTH = 0x100000000
}
SECTIONS
{
    .text :
    {
        crt0.o (.text) 
        *(.text)
	_end = .;           /* as expected by syscalls.c */
    }
}
