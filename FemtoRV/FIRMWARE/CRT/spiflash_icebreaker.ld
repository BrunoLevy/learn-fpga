/* Linker script for programs stored in SPI flash */
/* Inspired from picorv32/picosoc/sections.lds    */
/*                                                */
/* text sections are sent to BRAM                 */
/* rodata sections are sent to flash              */
/* bss sections are sent to BRAM                  */
/* data sections are sent to BRAM and have        */
/*  initialization data in flash.                 */
/* AT keyword specifies LMA (Load Memory Address) */
/*                                                */
/* If you got a lot of code that does not fit in  */
/* RAM, you may keep text sections in flash using */
/*   spiflash_icebreaker_run_from_flash.ld        */


MEMORY {
    FLASH (rx)  : ORIGIN = 0x00820000, LENGTH = 0x100000    /* 4 MB in flash */
    RAM   (rwx) : ORIGIN = 0x00000000, LENGTH = 0x20000     /* 128 kB in RAM */
}

SECTIONS {

    /*
     * I do not understand why, but if I do not put this section, I got
     * an overlapping sections error with some programs (for instance pi.c
     * or C++ programs)
     */
    .misc : {
        . = ALIGN(4);
        *(.eh_frame)
        *(.eh_frame_hdr)
        *(.init_array)
        *(.gcc_except_table*)	
    } >FLASH

    /* C runtime initialization code and readonly data goes to the FLASH */
    .text : {
        . = ALIGN(4);
        crt0_spiflash.o(.text)  /* c runtime initialization (code) */
        . = ALIGN(4);
        *(.rodata)              /* .rodata sections (constants, strings, etc.) */
        *(.rodata*)             /* .rodata* sections (constants, strings, etc.) */
        *(.srodata)             /* .rodata sections (constants, strings, etc.) */
        *(.srodata*)            /* .rodata* sections (constants, strings, etc.) */
        _etext = .;             /* define a global symbol at end of code */
        _sidata = _etext;       /* This is used by the startup in order to initialize the .data section */
    } >FLASH


    /* 
     * This is the initialized data and fastcode section
     * The program executes knowing that the data is in the RAM
     * but the loader puts the initial values in the FLASH (inidata).
     * It is one task of the startup (crt0_spiflash.S) to copy the initial values from FLASH to RAM. 
     */
    .data_and_fastcode : AT ( _sidata ) {
        . = ALIGN(4);
        _sdata = .;        /* create a global symbol at data start; used by startup code in order to initialise the .data section in RAM */
        _ram_start = .;    /* create a global symbol at ram start (e.g., for garbage collector) */

	/* functions with attribute((section(".fastcode"))) */	
	/* (e.g., some functions in femtoGL)                */
	*(.fastcode*)      

        *(.text)                /* .text sections (code) */
        *(.text*)               /* .text* sections (code) */
        . = ALIGN(4);

	/* Initialized data */
        *(.data)                     
        *(.data*)          
        *(.sdata)          
        *(.sdata*)

        . = ALIGN(4);
        _edata = .;        /* define a global symbol at data end; used by startup code in order to initialise the .data section in RAM */
    } > RAM

    /* Uninitialized data section */
    .bss : {
        . = ALIGN(4);
        _sbss = .;         /* define a global symbol at bss start; used by startup code */
        *(.bss)
        *(.bss*)
        *(.sbss)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;         /* define a global symbol at bss end; used by startup code */
    } >RAM

    /* this is to define the start of the heap, and make sure we have a minimum size */
    .heap : {
        . = ALIGN(4);
        _heap_start = .;    /* define a global symbol at heap start */
	_end = .;           /* as expected by syscalls.c            */
    } >RAM
    

}
