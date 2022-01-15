INCLUDE generated/output_format.ld
ENTRY(_start)

__DYNAMIC = 0;

INCLUDE generated/regions.ld

SECTIONS
{
	.text :
	{
		_ftext = .;
		/* Make sure crt0 files come first, and they, and the isr */
		/* don't get disposed of by greedy optimisation */
		*crt0*(.text)
		KEEP(*crt0*(.text))
		KEEP(*(.text.isr))

		*(.text .stub .text.* .gnu.linkonce.t.*)
		_etext = .;
	} > main_ram

	.rodata :
	{
		. = ALIGN(8);
		_frodata = .;
		*(.rodata .rodata.* .gnu.linkonce.r.*)
		*(.rodata1)
		. = ALIGN(8);
		_erodata = .;
	} > main_ram

        /* 
 	 * This rule and the following one
	 * to be able to reuse BIOS command system 
	 */
        .commands :
        {
	        PROVIDE_HIDDEN (__bios_cmd_start = .);
	        KEEP(*(.bios_cmd))
	        PROVIDE_HIDDEN (__bios_cmd_end = .);
        } > main_ram

	.init :
	{
		PROVIDE_HIDDEN (__bios_init_start = .);
		KEEP(*(.bios_init))
		PROVIDE_HIDDEN (__bios_init_end = .);
	} > main_ram

	.data :
	{
		. = ALIGN(8);
		*(.data .data.* .gnu.linkonce.d.*)
		*(.data1)
		_gp = ALIGN(16);
		*(.sdata .sdata.* .gnu.linkonce.s.*)
		. = ALIGN(8);
	} > main_ram

	.bss :
	{
		. = ALIGN(8);
		_fbss = .;
		*(.dynsbss)
		*(.sbss .sbss.* .gnu.linkonce.sb.*)
		*(.scommon)
		*(.dynbss)
		*(.bss .bss.* .gnu.linkonce.b.*)
		*(COMMON)
		. = ALIGN(8);
		_ebss = .;
		_end = .;
	} > main_ram
}

PROVIDE(_fstack = ORIGIN(main_ram) + LENGTH(main_ram));

/*
 * The CRT copies initialization data from rom to sram, 
 * that is, it copies
 * _fdata_rom ... _edata_rom-1 ----> _fdata ... e_data-1
 * since we put everything in main_ram directly, we 
 * do not need to do that.
 */
PROVIDE(_fdata_rom = 0);
PROVIDE(_edata_rom = 0);
PROVIDE(_fdata = 0);
PROVIDE(_edata = 0);