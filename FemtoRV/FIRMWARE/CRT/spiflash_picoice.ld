/* Linker script for programs stored in SPI flash */
/* Inspired from picorv32/picosoc/sections.lds       */
/*                                                */
/* text and rodata sections are sent to flash     */
/* bss sections are sent to BRAM                  */
/* data sections are sent to BRAM and have        */
/*  initialization data in flash.                 */
/* AT keyword specifies LMA (Load Memory Address) */

MEMORY {
    BITSTREAM (r): ORIGIN = 0x00800000, LENGTH = 0x20000    /* 128 KB FPGA configuration region */
    FLASH (rx)  : ORIGIN = 0x00820000, LENGTH = 0x3E0000    /* 3.8 MiB in flash */
    RAM   (rwx) : ORIGIN = 0x00000000, LENGTH = 0x1800      /* 6 kB in RAM   */
}

/* Set TARGET, and read the fpga bitstream */
TARGET(binary)
INPUT("../../femtosoc.bin")
/* Reset target format to previous value */
TARGET(elf32-littleriscv)

SECTIONS {

    /*
     * The PICOICE programmer only supports loading complete
     * binary files via DFU mode. Therefore, we will include
     * the FPGA bitstream binary directly into the output
     * elf file. Note the use of the AT keyword- we need this
     * approach because the linker will complain if we try to
     * link the bitstream directly to 0x0, as this overlaps with RAM.
     */
    .bitstream : {
        ../../femtosoc.bin
    } > BITSTREAM

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

	/* Initialized data */
        *(.data)
        *(.data*)
        *(.sdata)
        *(.sdata*)

	/* functions with attribute((section(".fastcode"))) */
	/* (e.g., some functions in femtoGL)                */
	*(.fastcode*)

	/* integer mul and div */
	*/libgcc.a:muldi3.o(.text)
	*/libgcc.a:div.o(.text)

        /* low-level graphics functions */
	*/libfemtorv32.a:ssd1351_1331.o(.text)

        /* timing */
	wait_cycles.o(.text)

        . = ALIGN(4);
        _edata = .;        /* define a global symbol at data end; used by startup code in order to initialise the .data section in RAM */
    } > RAM

    /* The (non fastcode) program code and other data goes into FLASH */
    .text : {
        . = ALIGN(4);
        crt0_spiflash.o(.text)  /* c runtime initialization (code) */


        /*
	 * I do not understand why, but if I do not put that here, I got
	 * an overlapping sections error with some programs (for instance pi.c
	 * or C++ programs)
	 */
        *(.eh_frame)
        *(.eh_frame_hdr)
        *(.init_array)
        *(.gcc_except_table*)

        *(.text)                /* .text sections (code) */
        *(.text*)               /* .text* sections (code) */
        . = ALIGN(4);
        *(.rodata)              /* .rodata sections (constants, strings, etc.) */
        *(.rodata*)             /* .rodata* sections (constants, strings, etc.) */
        *(.srodata)             /* .rodata sections (constants, strings, etc.) */
        *(.srodata*)            /* .rodata* sections (constants, strings, etc.) */
        _etext = .;             /* define a global symbol at end of code */
        _sidata = _etext;       /* This is used by the startup in order to initialize the .data section */
    } >FLASH

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
