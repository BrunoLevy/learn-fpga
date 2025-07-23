/* Linker script for programs stored in SPI flash */
/* Inspired from picorv32/picosoc/sections.lds       */
/*                                                */
/* text and rodata sections are sent to flash     */
/* bss sections are sent to BRAM                  */
/* data sections are sent to BRAM and have        */
/*  initialization data in flash.                 */
/* AT keyword specifies LMA (Load Memory Address) */

MEMORY {
    FLASH (rx)  : ORIGIN = 0x00820000, LENGTH = 0x100000    /* 4 MB in flash */
    RAM   (rwx) : ORIGIN = 0x00000000, LENGTH = 0x1800      /* 6 kB in RAM   */ 
}

SECTIONS {

    /* 
     * This is the initialized data and fastcode section
     * The program executes knowing that the data is in the RAM
     * but the loader puts the initial values in the FLASH (inidata).
     * It is one task of the startup (crt0_spiflash.S) to copy the initial values from FLASH to RAM. 
     */
    .data : AT ( _sidata ) {
    
        . = ALIGN(4); 
	
        _sdata = .;        /* create a global symbol at data start; used by startup code in order to initialise the .data section in RAM */
        _ram_start = .;    /* create a global symbol at ram start (e.g., for garbage collector) */
	
	/* Initialized data */
        *(.data*)          
        *(.sdata*)

        . = ALIGN(4);
        _edata = .;        /* define a global symbol at data end; used by startup code in order to initialise the .data section in RAM */
    } > RAM

    /* The (non fastcode) program code and other data goes into FLASH */
    .text : {
        . = ALIGN(4);
        start_spiflash1.o(.text)  /* c runtime initialization (code) */
        *(.text*)                 /* .text* sections (code) */
        . = ALIGN(4);
        *(.rodata*)              /* .rodata* sections (constants, strings, etc.) */
        *(.srodata*)             /* .rodata* sections (constants, strings, etc.) */
        _etext = .;              /* define a global symbol at end of code */
        _sidata = _etext;        /* This is used by the startup in order to initialize the .data section */
    } >FLASH

    /* Uninitialized data section */
    .bss : {
        . = ALIGN(4);
        _sbss = .;         /* define a global symbol at bss start; used by startup code */
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;         /* define a global symbol at bss end; used by startup code */
    } >RAM
}
