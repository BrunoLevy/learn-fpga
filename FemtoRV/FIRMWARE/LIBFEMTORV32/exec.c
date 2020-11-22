#include <femtorv32.h>

/*
 * My stupid loader: since I am not able yet to load library functions in RAM and
 * share them between different programs (do not know how to link for that), my
 * loader operates as follows:
 * 1) load the program into the top memory (using an alloca-ed buffer !!)
 * 2) copy the program to address zero
 * 3) transfer execution to address zero
 * Note that the function that copies and transfers execution needs to be also
 * at a high memory address, else it will be overwritten ! To do that, it is 
 * stored in a local array of exec(). The asm code of the exec_memcpy() function
 * is below:
 * Takes as argument: to_addr, from_addr, length, upper_limit
 * It copies length bytes from from_addr to to_addr, then fills the
 *  rest with zeros until upper-limit is reached.

exec_memcpy.s:
exec_memcpy:
	li   t0, 0
.L1:	beq  t0, a2, .L2
	lbu  t1,0(a1)
	sb   t1,0(a0)
	addi a0,a0,1
	addi a1,a1,1
	addi t0,t0,1
        j    .L1
.L2:    beq  a0,a3, .L3
	sb   x0,0(a0)
	addi a0,a0,1
	j    .L2
.L3:    jalr x0, x0, 0	

  riscv64-linux-gnu-as -march=rv32i -mabi=ilp32 -o exec_memcpy.o exec_memcpy.s
  riscv64-linux-gnu-objcopy -O verilog exec_memcpy.o exec_memcpy.objcopy.hex
*/

#define make_word(a,b,c,d) 0x##d##c##b##a

typedef void (*exec_memcpy_func)(void*, void*, size_t, void*);

int exec(const char* filename) {

    uint32_t exec_memcpy[] = {
	make_word(93,02,00,00),
	make_word(63,8E,C2,00),
	make_word(03,C3,05,00),
	make_word(23,00,65,00),
	make_word(13,05,15,00),
	make_word(93,85,15,00),
	make_word(93,82,12,00),
	make_word(6F,F0,9F,FE),
	make_word(63,08,D5,00),
	make_word(23,00,05,00),
	make_word(13,05,15,00),
	make_word(6F,F0,5F,FF),
	make_word(67,00,00,00)
    };

    if(sd_init()) {
	printf("Could not initialize SDCard\n");
	return -1;
    }
    printf("SDCard OK\n");
    fl_init();
    if(fl_attach_media(
	   (fn_diskio_read)sd_readsector,
	   (fn_diskio_write)sd_writesector) != FAT_INIT_OK
    ) {
	printf("ERROR: Failed to init file system\n");
	return -1;
    }
    printf("FileSystem OK\n");

    FILE* f = fopen(filename,"r");
    if(!f) {
	printf("Could not open %s\n", filename);
	return -1;
    }
    fseek(f, 0, SEEK_END);
    int size = ftell(f);
    printf("File size = %d\n", size);
    fseek(f, 0, SEEK_SET);

    void* buff = alloca(size);
    if(fread(buff, 1, size, f) != size) {
	printf("Could not read file\n");
    } else {
	printf("File ready in RAM\n");
    }

    ((exec_memcpy_func)(exec_memcpy))(0, buff, size, exec_memcpy - 100);
    
    return 0;
}
