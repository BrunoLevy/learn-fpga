/*
 * same as generated/regions.ld, except that main_ram
 * main_ram starts 256KB later (we keep the first 256KB
 * for the OS).
 */
MEMORY {
	rom : ORIGIN = 0x00000000, LENGTH = 0x00020000
	sram : ORIGIN = 0x01000000, LENGTH = 0x00002000
	main_ram : ORIGIN = 0x40040000, LENGTH = 0x01FC0000
	csr : ORIGIN = 0x82000000, LENGTH = 0x00010000
}
