/*
 * linker control script for 'bare metal' executables.
 * Ensures that _start defined in LIB/crt0.S is put at address 0
 * Uses the first 64 kB of BRAM. It can be used for instance by
 * an OS. Standard ELF executables are implanted at address 0x10000,
 * so this ensures they won't collide.
 */
MEMORY
{
   BRAM (RWX) : ORIGIN = 0x0000, LENGTH = 0x10000
}
SECTIONS
{
    .text :
    {
        crt0_baremetal.o (.text) 
        *(.text)
	_end = .;           /* as expected by syscalls.c */
    }
}
