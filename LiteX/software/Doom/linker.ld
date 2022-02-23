INCLUDE generated/output_format.ld
ENTRY(_start)

__DYNAMIC = 0;

/* 
 * We include our own 'regions.ld', with main_ram that starts 256 KB
 * later (the first 256 KBs are kept fo the OS).
 */
INCLUDE regions.ld

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
	

	/* Put colormap in BRAM, for faster indexed-to-colormapped conversion */
	.fastdata :
	{
	   . = ALIGN(8);
	   *(.fastdata*)
	   . = ALIGN(8);
	} > sram
	
	.fastcode :
	{
	   . = ALIGN(8);
	   *(.fastcode*)
	   . = ALIGN(8);
	} > sram



}


